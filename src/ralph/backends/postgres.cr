require "db"
require "pg"
require "uri"
require "../statement_cache"

module Ralph
  module Database
    # PostgreSQL database backend implementation
    #
    # Provides PostgreSQL-specific database operations for Ralph ORM.
    # Uses the crystal-pg shard for database connectivity.
    #
    # ## Example
    #
    # ```
    # # Standard connection
    # backend = Ralph::Database::PostgresBackend.new("postgres://user:pass@localhost:5432/mydb")
    #
    # # Unix socket connection
    # backend = Ralph::Database::PostgresBackend.new("postgres://user@localhost/mydb?host=/var/run/postgresql")
    # ```
    #
    # ## Connection String Format
    #
    # PostgreSQL connection strings follow the format:
    # `postgres://user:password@host:port/database?options`
    #
    # Common options:
    # - `host=/path/to/socket` - Unix socket path
    # - `sslmode=require` - Require SSL connection
    #
    # ## Connection Pooling
    #
    # Connection pooling is configured automatically from `Ralph.settings`:
    #
    # ```
    # Ralph.configure do |config|
    #   config.initial_pool_size = 5
    #   config.max_pool_size = 25
    #   config.max_idle_pool_size = 10
    #   config.checkout_timeout = 5.0
    #   config.retry_attempts = 3
    #   config.retry_delay = 0.2
    # end
    # ```
    #
    # ## Prepared Statement Caching
    #
    # This backend supports prepared statement caching for improved query
    # performance. Enable and configure via Ralph.settings:
    #
    # ```
    # Ralph.configure do |config|
    #   config.enable_prepared_statements = true
    #   config.prepared_statement_cache_size = 100
    # end
    # ```
    #
    # ## Placeholder Conversion
    #
    # This backend automatically converts `?` placeholders to PostgreSQL's
    # `$1, $2, ...` format, so you can write queries the same way as SQLite.
    #
    # ## INSERT Behavior
    #
    # PostgreSQL uses `INSERT ... RETURNING id` to get the last inserted ID,
    # which is handled automatically by the `insert` method.
    class PostgresBackend < Backend
      @db : ::DB::Database
      @closed : Bool = false
      @connection_string : String
      @statement_cache : Ralph::StatementCache(::DB::PoolPreparedStatement)?

      # Creates a new PostgreSQL backend with the given connection string
      #
      # ## Parameters
      #
      # - `connection_string`: PostgreSQL connection URI
      # - `apply_pool_settings`: Whether to apply pool settings from Ralph.settings (default: true)
      #
      # ## Example
      #
      # ```
      # # Basic usage
      # backend = Ralph::Database::PostgresBackend.new("postgres://localhost/mydb")
      #
      # # Skip pool settings (useful for CLI tools)
      # backend = Ralph::Database::PostgresBackend.new("postgres://localhost/mydb", apply_pool_settings: false)
      # ```
      def initialize(connection_string : String, apply_pool_settings : Bool = true)
        @connection_string = connection_string

        # Build connection string with pool parameters
        final_connection_string = if apply_pool_settings
                                    build_pooled_connection_string(connection_string)
                                  else
                                    connection_string
                                  end

        @db = DB.open(final_connection_string)

        # Initialize prepared statement cache from settings
        settings = Ralph.settings
        @statement_cache = Ralph::StatementCache(::DB::PoolPreparedStatement).new(
          max_size: settings.prepared_statement_cache_size,
          enabled: settings.enable_prepared_statements
        )
      end

      # Build connection string with pool parameters from Ralph.settings
      private def build_pooled_connection_string(base_url : String) : String
        settings = Ralph.settings
        uri = URI.parse(base_url)

        # Parse existing query params and merge with pool settings
        existing_params = HTTP::Params.parse(uri.query || "")
        settings.pool_params.each do |key, value|
          # Don't override existing params (user-specified takes precedence)
          existing_params[key] = value unless existing_params.has_key?(key)
        end

        uri.query = existing_params.to_s
        uri.to_s
      end

      # Execute a write query (INSERT, UPDATE, DELETE, DDL)
      # Uses prepared statement cache when enabled
      def execute(query : String, args : Array(DB::Any) = [] of DB::Any)
        converted_query = convert_placeholders(query)
        execute_with_cache(converted_query, args) do |stmt, params|
          stmt.exec(args: params)
        end
      end

      # Insert a record and return the inserted ID
      # Uses RETURNING clause for PostgreSQL
      def insert(query : String, args : Array(DB::Any) = [] of DB::Any) : Int64
        modified_query = append_returning_id(convert_placeholders(query))
        # For inserts with RETURNING, use direct query_one to ensure we get the ID
        result = @db.query_one(modified_query, args: args, as: Int64)
        result
      end

      # Query for a single row, returns nil if no results
      # Uses prepared statement cache when enabled
      def query_one(query : String, args : Array(DB::Any) = [] of DB::Any) : ::DB::ResultSet?
        converted_query = convert_placeholders(query)
        rs = query_with_cache(converted_query, args)
        if rs.move_next
          rs
        else
          rs.close
          nil
        end
      end

      # Query for multiple rows
      # Uses prepared statement cache when enabled
      def query_all(query : String, args : Array(DB::Any) = [] of DB::Any) : ::DB::ResultSet
        converted_query = convert_placeholders(query)
        query_with_cache(converted_query, args)
      end

      # Run a scalar query and return a single value
      # Uses prepared statement cache when enabled
      def scalar(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::Any?
        converted_query = convert_placeholders(query)
        result = scalar_with_cache(converted_query, args)
        case result
        when Bool, Float32, Float64, Int32, Int64, Slice(UInt8), String, Time, Nil
          result
        when Int16
          result.to_i32
        when UInt32
          result.to_i64
        when UInt64
          result.to_i64
        when PG::Numeric
          result.to_f64
        else
          result.to_s
        end
      end

      def transaction(&block : ::DB::Transaction ->)
        @db.transaction do |tx|
          block.call(tx)
        end
      end

      def close
        # Clear statement cache before closing
        clear_statement_cache
        @db.close
        @closed = true
      end

      def closed? : Bool
        @closed
      end

      def raw_connection : ::DB::Database
        @db
      end

      def begin_transaction_sql : String
        "BEGIN"
      end

      def commit_sql : String
        "COMMIT"
      end

      def rollback_sql : String
        "ROLLBACK"
      end

      def savepoint_sql(name : String) : String
        "SAVEPOINT #{name}"
      end

      def release_savepoint_sql(name : String) : String
        "RELEASE SAVEPOINT #{name}"
      end

      def rollback_to_savepoint_sql(name : String) : String
        "ROLLBACK TO SAVEPOINT #{name}"
      end

      def dialect : Symbol
        :postgres
      end

      # Get the original connection string (without pool params)
      def connection_string : String
        @connection_string
      end

      # ========================================
      # Schema Introspection Implementation
      # ========================================

      # Get all user table names (excluding system tables)
      def table_names : Array(String)
        sql = <<-SQL
          SELECT table_name
          FROM information_schema.tables
          WHERE table_schema = 'public'
          AND table_type = 'BASE TABLE'
          AND table_name != 'schema_migrations'
          ORDER BY table_name
        SQL

        names = [] of String
        rs = @db.query(sql)
        begin
          while rs.move_next
            names << rs.read(String)
          end
        ensure
          rs.close
        end
        names
      end

      # Get column information for a specific table
      def introspect_columns(table : String) : Array(Schema::DatabaseColumn)
        columns = [] of Schema::DatabaseColumn

        # Query column information from information_schema
        # Also detect primary keys and serial/identity columns
        sql = <<-SQL
          SELECT
            c.column_name,
            c.data_type,
            c.udt_name,
            c.is_nullable,
            c.column_default,
            c.character_maximum_length,
            c.numeric_precision,
            COALESCE(
              (SELECT true
               FROM information_schema.table_constraints tc
               JOIN information_schema.key_column_usage kcu
                 ON tc.constraint_name = kcu.constraint_name
                 AND tc.table_schema = kcu.table_schema
               WHERE tc.table_name = c.table_name
                 AND tc.table_schema = c.table_schema
                 AND kcu.column_name = c.column_name
                 AND tc.constraint_type = 'PRIMARY KEY'
               LIMIT 1),
              false
            ) AS is_primary_key
          FROM information_schema.columns c
          WHERE c.table_name = $1
          AND c.table_schema = 'public'
          ORDER BY c.ordinal_position
        SQL

        rs = @db.query(sql, args: [table] of DB::Any)
        begin
          while rs.move_next
            column_name = rs.read(String)
            data_type = rs.read(String)
            udt_name = rs.read(String)
            is_nullable = rs.read(String) == "YES"
            column_default = rs.read(String | Nil)
            char_max_length = rs.read(Int32 | Int64 | Nil)
            numeric_precision = rs.read(Int32 | Int64 | Nil)
            is_primary_key = rs.read(Bool)

            # Build the type string
            col_type = build_postgres_type_string(data_type, udt_name, char_max_length, numeric_precision)

            # Detect auto-increment from column default
            # Serial columns have default like: nextval('tablename_id_seq'::regclass)
            # Identity columns have default like: generated by default as identity
            auto_increment = column_default.try(&.includes?("nextval")) ||
                             column_default.try(&.includes?("identity")) ||
                             false

            columns << Schema::DatabaseColumn.new(
              name: column_name,
              type: col_type,
              nullable: is_nullable,
              default: column_default,
              primary_key: is_primary_key,
              auto_increment: auto_increment
            )
          end
        ensure
          rs.close
        end

        columns
      end

      # Get index information for a specific table
      def introspect_indexes(table : String) : Array(Schema::DatabaseIndex)
        indexes = [] of Schema::DatabaseIndex

        # Query indexes using pg_indexes and pg_class
        sql = <<-SQL
          SELECT
            i.relname AS index_name,
            a.attname AS column_name,
            ix.indisunique AS is_unique,
            am.amname AS index_type,
            pg_get_expr(ix.indpred, ix.indrelid) AS condition
          FROM pg_class t
          JOIN pg_index ix ON t.oid = ix.indrelid
          JOIN pg_class i ON i.oid = ix.indexrelid
          JOIN pg_am am ON i.relam = am.oid
          JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey)
          WHERE t.relname = $1
          AND t.relkind = 'r'
          AND t.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
          ORDER BY i.relname, array_position(ix.indkey, a.attnum)
        SQL

        # Group by index name to collect columns
        index_data = Hash(String, NamedTuple(columns: Array(String), unique: Bool, type: String, condition: String?)).new

        rs = @db.query(sql, args: [table] of DB::Any)
        begin
          while rs.move_next
            index_name = rs.read(String)
            column_name = rs.read(String)
            is_unique = rs.read(Bool)
            index_type = rs.read(String)
            condition = rs.read(String | Nil)

            if existing = index_data[index_name]?
              # Add column to existing index
              existing[:columns] << column_name
            else
              # Create new index entry
              index_data[index_name] = {
                columns:   [column_name],
                unique:    is_unique,
                type:      index_type,
                condition: condition,
              }
            end
          end
        ensure
          rs.close
        end

        # Convert to DatabaseIndex records
        index_data.each do |name, info|
          indexes << Schema::DatabaseIndex.new(
            name: name,
            table: table,
            columns: info[:columns],
            unique: info[:unique],
            type: parse_index_type(info[:type]),
            condition: info[:condition]
          )
        end

        indexes
      end

      # Get foreign key constraints FROM a table (outgoing FKs)
      def introspect_foreign_keys(table : String) : Array(Schema::DatabaseForeignKey)
        foreign_keys = [] of Schema::DatabaseForeignKey

        sql = <<-SQL
          SELECT
            tc.constraint_name,
            kcu.column_name,
            ccu.table_name AS foreign_table_name,
            ccu.column_name AS foreign_column_name,
            rc.update_rule,
            rc.delete_rule
          FROM information_schema.table_constraints AS tc
          JOIN information_schema.key_column_usage AS kcu
            ON tc.constraint_name = kcu.constraint_name
            AND tc.table_schema = kcu.table_schema
          JOIN information_schema.constraint_column_usage AS ccu
            ON ccu.constraint_name = tc.constraint_name
            AND ccu.table_schema = tc.table_schema
          JOIN information_schema.referential_constraints AS rc
            ON rc.constraint_name = tc.constraint_name
            AND rc.constraint_schema = tc.table_schema
          WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_name = $1
          AND tc.table_schema = 'public'
        SQL

        rs = @db.query(sql, args: [table] of DB::Any)
        begin
          while rs.move_next
            constraint_name = rs.read(String)
            from_column = rs.read(String)
            to_table = rs.read(String)
            to_column = rs.read(String)
            update_rule = rs.read(String)
            delete_rule = rs.read(String)

            foreign_keys << Schema::DatabaseForeignKey.new(
              name: constraint_name,
              from_table: table,
              from_column: from_column,
              to_table: to_table,
              to_column: to_column,
              on_delete: Schema.parse_referential_action(delete_rule),
              on_update: Schema.parse_referential_action(update_rule)
            )
          end
        ensure
          rs.close
        end

        foreign_keys
      end

      # Get foreign key constraints TO a table (incoming FKs)
      def introspect_foreign_keys_referencing(table : String) : Array(Schema::DatabaseForeignKey)
        foreign_keys = [] of Schema::DatabaseForeignKey

        sql = <<-SQL
          SELECT
            tc.constraint_name,
            tc.table_name AS from_table,
            kcu.column_name AS from_column,
            ccu.column_name AS to_column,
            rc.update_rule,
            rc.delete_rule
          FROM information_schema.table_constraints AS tc
          JOIN information_schema.key_column_usage AS kcu
            ON tc.constraint_name = kcu.constraint_name
            AND tc.table_schema = kcu.table_schema
          JOIN information_schema.constraint_column_usage AS ccu
            ON ccu.constraint_name = tc.constraint_name
            AND ccu.table_schema = tc.table_schema
          JOIN information_schema.referential_constraints AS rc
            ON rc.constraint_name = tc.constraint_name
            AND rc.constraint_schema = tc.table_schema
          WHERE tc.constraint_type = 'FOREIGN KEY'
          AND ccu.table_name = $1
          AND tc.table_schema = 'public'
        SQL

        rs = @db.query(sql, args: [table] of DB::Any)
        begin
          while rs.move_next
            constraint_name = rs.read(String)
            from_table = rs.read(String)
            from_column = rs.read(String)
            to_column = rs.read(String)
            update_rule = rs.read(String)
            delete_rule = rs.read(String)

            foreign_keys << Schema::DatabaseForeignKey.new(
              name: constraint_name,
              from_table: from_table,
              from_column: from_column,
              to_table: table,
              to_column: to_column,
              on_delete: Schema.parse_referential_action(delete_rule),
              on_update: Schema.parse_referential_action(update_rule)
            )
          end
        ensure
          rs.close
        end

        foreign_keys
      end

      # Build a PostgreSQL type string from metadata
      private def build_postgres_type_string(data_type : String, udt_name : String, char_max_length : Int32 | Int64 | Nil, numeric_precision : Int32 | Int64 | Nil) : String
        case data_type.downcase
        when "character varying"
          char_max_length ? "varchar(#{char_max_length})" : "varchar"
        when "character"
          char_max_length ? "char(#{char_max_length})" : "char"
        when "numeric", "decimal"
          numeric_precision ? "numeric(#{numeric_precision})" : "numeric"
        when "array"
          # Array types have udt_name like "_int4", "_text", etc.
          element_type = udt_name.lchop("_")
          "#{element_type}[]"
        when "user-defined"
          # Enum types, etc.
          udt_name
        else
          data_type
        end
      end

      # Parse PostgreSQL index type to symbol
      private def parse_index_type(type_name : String) : Symbol?
        case type_name.downcase
        when "btree"  then :btree
        when "hash"   then :hash
        when "gist"   then :gist
        when "gin"    then :gin
        when "spgist" then :spgist
        when "brin"   then :brin
        else               nil
        end
      end

      # ========================================
      # PostgreSQL-Specific Methods
      # ========================================

      # Get all available text search configurations
      #
      # Returns a list of available text search configuration names that can be
      # used with full-text search functions like to_tsvector() and to_tsquery().
      #
      # ## Example
      #
      # ```
      # backend = Ralph::Database::PostgresBackend.new(url)
      # configs = backend.available_text_search_configs
      # # => ["arabic", "danish", "dutch", "english", "finnish", "french", "german", ...]
      # ```
      #
      # ## Common Configurations
      #
      # - **simple**: No stemming, just lowercasing and removing stop words
      # - **english**: English language with stemming and stop words
      # - **french**: French language configuration
      # - **german**: German language configuration
      # - **spanish**: Spanish language configuration
      # - **russian**: Russian language configuration
      # - And many more...
      def available_text_search_configs : Array(String)
        result = @db.query("SELECT cfgname FROM pg_ts_config ORDER BY cfgname")
        configs = [] of String
        result.each do
          configs << result.read(String)
        end
        configs
      ensure
        result.try(&.close)
      end

      # Get text search configuration details
      #
      # Returns information about a specific text search configuration.
      #
      # ## Example
      #
      # ```
      # backend.text_search_config_info("english")
      # # => {name: "english", parser: "default", dictionaries: [...]}
      # ```
      def text_search_config_info(config_name : String) : Hash(String, String)
        result = @db.query_one(<<-SQL, args: [config_name] of DB::Any)
          SELECT c.cfgname, p.prsname as parser_name, c.cfgnamespace::regnamespace::text as schema
          FROM pg_ts_config c
          JOIN pg_ts_parser p ON c.cfgparser = p.oid
          WHERE c.cfgname = $1
        SQL

        info = Hash(String, String).new
        if result
          info["name"] = result.read(String)
          info["parser"] = result.read(String)
          info["schema"] = result.read(String)
        end
        info
      ensure
        result.try(&.close) if result.is_a?(DB::ResultSet)
      end

      # Check if a text search configuration exists
      def text_search_config_exists?(config_name : String) : Bool
        result = @db.scalar("SELECT COUNT(*) FROM pg_ts_config WHERE cfgname = $1", args: [config_name] of DB::Any)
        case result
        when Int64
          result > 0
        else
          false
        end
      end

      # Create a custom text search configuration
      #
      # Creates a new text search configuration by copying from an existing one.
      #
      # ## Example
      #
      # ```
      # # Create a custom config based on English
      # backend.create_text_search_config("my_english", copy_from: "english")
      # ```
      def create_text_search_config(name : String, copy_from : String = "english")
        @db.exec("CREATE TEXT SEARCH CONFIGURATION \"#{name}\" (COPY = \"#{copy_from}\")")
      end

      # Drop a custom text search configuration
      #
      # ## Example
      #
      # ```
      # backend.drop_text_search_config("my_english")
      # ```
      def drop_text_search_config(name : String, if_exists : Bool = true)
        if_exists_sql = if_exists ? "IF EXISTS " : ""
        @db.exec("DROP TEXT SEARCH CONFIGURATION #{if_exists_sql}\"#{name}\"")
      end

      # Get PostgreSQL version
      #
      # Returns the PostgreSQL server version as a string.
      #
      # ## Example
      #
      # ```
      # backend.postgres_version
      # # => "15.4"
      # ```
      def postgres_version : String
        result = @db.scalar("SELECT version()")
        case result
        when String
          # Extract version number from "PostgreSQL 15.4 on ..."
          if match = result.match(/PostgreSQL (\d+\.\d+)/)
            match[1]
          else
            result
          end
        else
          "unknown"
        end
      end

      # Check if a PostgreSQL extension is available
      #
      # ## Example
      #
      # ```
      # backend.extension_available?("pg_trgm") # => true
      # backend.extension_available?("postgis") # => false (if not installed)
      # ```
      def extension_available?(name : String) : Bool
        result = @db.scalar(<<-SQL, args: [name] of DB::Any)
          SELECT COUNT(*) FROM pg_available_extensions WHERE name = $1
        SQL
        case result
        when Int64
          result > 0
        else
          false
        end
      end

      # Check if a PostgreSQL extension is installed
      def extension_installed?(name : String) : Bool
        result = @db.scalar(<<-SQL, args: [name] of DB::Any)
          SELECT COUNT(*) FROM pg_extension WHERE extname = $1
        SQL
        case result
        when Int64
          result > 0
        else
          false
        end
      end

      # Install a PostgreSQL extension
      #
      # ## Example
      #
      # ```
      # backend.create_extension("pg_trgm")
      # ```
      def create_extension(name : String, if_not_exists : Bool = true)
        if_not_exists_sql = if_not_exists ? "IF NOT EXISTS " : ""
        @db.exec("CREATE EXTENSION #{if_not_exists_sql}\"#{name}\"")
      end

      # Uninstall a PostgreSQL extension
      def drop_extension(name : String, if_exists : Bool = true, cascade : Bool = false)
        if_exists_sql = if_exists ? "IF EXISTS " : ""
        cascade_sql = cascade ? " CASCADE" : ""
        @db.exec("DROP EXTENSION #{if_exists_sql}\"#{name}\"#{cascade_sql}")
      end

      # ========================================
      # Prepared Statement Cache Implementation
      # ========================================

      # Clear all cached prepared statements
      def clear_statement_cache
        if cache = @statement_cache
          cache.clear
          # Note: DB::PoolPreparedStatement is managed by the pool,
          # garbage collection will clean up the statements
        end
      end

      # Get statement cache statistics
      def statement_cache_stats : NamedTuple(size: Int32, max_size: Int32, enabled: Bool)
        if cache = @statement_cache
          cache.stats
        else
          {size: 0, max_size: 0, enabled: false}
        end
      end

      # Enable or disable statement caching at runtime
      def enable_statement_cache=(enabled : Bool)
        if cache = @statement_cache
          cache.enabled = enabled
        end
      end

      # Check if statement caching is enabled
      def statement_cache_enabled? : Bool
        if cache = @statement_cache
          cache.enabled?
        else
          false
        end
      end

      private def convert_placeholders(query : String) : String
        return query unless query.includes?('?')

        index = 0
        query.gsub("?") do
          index += 1
          "$#{index}"
        end
      end

      private def append_returning_id(query : String) : String
        trimmed = query.rstrip
        trimmed = trimmed.rstrip(';')

        if trimmed.downcase.includes?("returning")
          trimmed
        else
          "#{trimmed} RETURNING id"
        end
      end

      # Get or create a prepared statement from cache
      private def get_or_prepare_statement(query : String) : ::DB::PoolPreparedStatement
        cache = @statement_cache

        # If cache is disabled or unavailable, create a new statement
        if cache.nil? || !cache.enabled?
          return @db.build(query).as(::DB::PoolPreparedStatement)
        end

        # Try to get from cache
        if stmt = cache.get(query)
          return stmt
        end

        # Create new prepared statement
        stmt = @db.build(query).as(::DB::PoolPreparedStatement)

        # Cache it (may evict old statements)
        # Note: evicted statements are managed by the pool, no explicit close needed
        cache.set(query, stmt)

        stmt
      end

      # Execute a query using cached prepared statement
      private def execute_with_cache(query : String, args : Array(DB::Any), &)
        stmt = get_or_prepare_statement(query)
        yield stmt, args
      rescue ex : DB::Error
        # If statement is invalid (e.g., schema changed), remove from cache and retry
        if cache = @statement_cache
          cache.delete(query)
        end
        # Retry with fresh statement
        stmt = @db.build(query).as(::DB::PoolPreparedStatement)
        yield stmt, args
      end

      # Query using cached prepared statement
      private def query_with_cache(query : String, args : Array(DB::Any)) : ::DB::ResultSet
        stmt = get_or_prepare_statement(query)
        stmt.query(args: args)
      rescue ex : DB::Error
        # If statement is invalid, remove from cache and retry
        if cache = @statement_cache
          cache.delete(query)
        end
        # Retry with fresh statement
        @db.query(query, args: args)
      end

      # Scalar query using cached prepared statement
      private def scalar_with_cache(query : String, args : Array(DB::Any))
        stmt = get_or_prepare_statement(query)
        stmt.scalar(args: args)
      rescue ex : DB::Error
        # If statement is invalid, remove from cache and retry
        if cache = @statement_cache
          cache.delete(query)
        end
        # Retry with fresh statement
        @db.scalar(query, args: args)
      end
    end
  end
end

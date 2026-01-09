require "db"
require "sqlite3"
require "uri"
require "../statement_cache"

module Ralph
  module Database
    # SQLite database backend implementation
    #
    # Provides SQLite-specific database operations for Ralph ORM.
    # Uses the crystal-sqlite3 shard for database connectivity.
    #
    # ## Example
    #
    # ```
    # # File-based database
    # backend = Ralph::Database::SqliteBackend.new("sqlite3://./db/development.sqlite3")
    #
    # # In-memory database (useful for testing)
    # backend = Ralph::Database::SqliteBackend.new("sqlite3::memory:")
    #
    # # Enable WAL mode for better concurrency in production
    # backend = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3", wal_mode: true)
    # ```
    #
    # ## Connection String Format
    #
    # SQLite connection strings follow the format: `sqlite3://path/to/database.db`
    #
    # Special values:
    # - `sqlite3::memory:` - Creates an in-memory database
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
    # ## Concurrency
    #
    # SQLite only supports one writer at a time. This backend provides two modes:
    #
    # 1. **Default mode (wal_mode: false)**: Uses a mutex to serialize all write
    #    operations from this application. This prevents "database is locked"
    #    errors but limits write throughput to one operation at a time.
    #
    # 2. **WAL mode (wal_mode: true)**: Enables SQLite's Write-Ahead Logging,
    #    which allows concurrent reads during writes. Writes are still serialized
    #    by SQLite but don't block readers. Recommended for production use with
    #    concurrent requests.
    #
    # Note: WAL mode creates additional files (.sqlite3-wal, .sqlite3-shm) and
    # is not supported for in-memory databases.
    class SqliteBackend < Backend
      @db : ::DB::Database
      @closed : Bool = false
      @wal_mode : Bool
      @write_mutex : Mutex
      @connection_string : String
      @statement_cache : Ralph::StatementCache(::DB::PoolPreparedStatement)?

      # Creates a new SQLite backend with the given connection string
      #
      # ## Parameters
      #
      # - `connection_string`: SQLite connection URI
      # - `wal_mode`: Enable WAL mode for better concurrency (default: false)
      # - `busy_timeout`: Milliseconds to wait for locks (default: 5000)
      # - `apply_pool_settings`: Whether to apply pool settings from Ralph.settings (default: true)
      #
      # ## Example
      #
      # ```
      # # Basic usage
      # backend = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
      #
      # # Production usage with WAL mode
      # backend = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3", wal_mode: true)
      #
      # # Skip pool settings (useful for CLI tools)
      # backend = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3", apply_pool_settings: false)
      # ```
      def initialize(connection_string : String, wal_mode : Bool = false, busy_timeout : Int32 = 5000, apply_pool_settings : Bool = true)
        @connection_string = connection_string
        @write_mutex = Mutex.new(:reentrant)
        @wal_mode = wal_mode

        # Build connection string with pool parameters
        final_connection_string = if apply_pool_settings
                                    build_pooled_connection_string(connection_string)
                                  else
                                    connection_string
                                  end

        @db = DB.open(final_connection_string)

        # Set a busy timeout to wait for locks instead of failing immediately
        @db.using_connection do |conn|
          conn.exec("PRAGMA busy_timeout=#{busy_timeout}")
        end

        # Enable WAL mode if requested (skip for in-memory databases)
        if wal_mode && !connection_string.includes?(":memory:")
          @db.using_connection do |conn|
            conn.exec("PRAGMA journal_mode=WAL")
          end
        end

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

        # Handle special SQLite URI formats
        # sqlite3::memory: -> special in-memory format
        # sqlite3://path -> standard URI format
        if base_url.starts_with?("sqlite3::memory:")
          # In-memory databases use a special format
          # Append pool params as query string
          params = HTTP::Params.build do |p|
            settings.pool_params.each do |key, value|
              p.add(key, value)
            end
          end
          "#{base_url}?#{params}"
        else
          # Standard URI format
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
      end

      # Execute a write query (INSERT, UPDATE, DELETE, DDL)
      # Serialized through mutex when not in WAL mode
      # Uses prepared statement cache when enabled
      def execute(query : String, args : Array(DB::Any) = [] of DB::Any)
        with_write_lock do
          execute_with_cache(query, args) do |stmt, params|
            stmt.exec(args: params)
          end
        end
      end

      # Insert a record and return the last inserted row ID
      # Uses the same connection for both operations to ensure correctness
      def insert(query : String, args : Array(DB::Any) = [] of DB::Any) : Int64
        with_write_lock do
          @db.using_connection do |conn|
            # For inserts, we need to use the same connection to get last_insert_rowid
            # so we use direct execution instead of cached statements
            conn.exec(query, args: args)
            conn.scalar("SELECT last_insert_rowid()").as(Int64)
          end
        end
      end

      # Query for a single row, returns nil if no results
      # Uses prepared statement cache when enabled
      def query_one(query : String, args : Array(DB::Any) = [] of DB::Any) : ::DB::ResultSet?
        rs = query_with_cache(query, args)
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
        query_with_cache(query, args)
      end

      # Execute a scalar query and return a single value
      # Uses prepared statement cache when enabled
      def scalar(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::Any?
        result = scalar_with_cache(query, args)
        case result
        when Bool, Float32, Float64, Int32, Int64, Slice(UInt8), String, Time, Nil
          result
        when Int16
          result.to_i32
        when UInt32
          result.to_i64
        when UInt64
          result.to_i64
        else
          result.to_s
        end
      end

      # Execute a block within a database transaction
      # The entire transaction is protected by the write lock
      def transaction(&block : ::DB::Transaction ->)
        with_write_lock do
          @db.transaction do |tx|
            block.call(tx)
          end
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
        :sqlite
      end

      # ========================================
      # Schema Introspection Implementation
      # ========================================

      # Get all user table names (excluding system tables)
      def table_names : Array(String)
        sql = <<-SQL
          SELECT name FROM sqlite_master
          WHERE type = 'table'
          AND name NOT LIKE 'sqlite_%'
          AND name != 'schema_migrations'
          ORDER BY name
        SQL

        names = [] of String
        rs = query_all(sql)
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

        # PRAGMA table_info returns: cid, name, type, notnull, dflt_value, pk
        rs = query_all("PRAGMA table_info(\"#{escape_identifier(table)}\")")
        begin
          while rs.move_next
            _cid = rs.read(Int32 | Int64)
            name = rs.read(String)
            col_type = rs.read(String)
            not_null = rs.read(Int32 | Int64) == 1
            default_value = rs.read(String | Nil)
            is_pk = rs.read(Int32 | Int64) != 0

            # Detect autoincrement - need to check if it's INTEGER PRIMARY KEY
            # SQLite only auto-increments INTEGER PRIMARY KEY (rowid alias)
            auto_increment = is_pk && col_type.upcase == "INTEGER"

            columns << Schema::DatabaseColumn.new(
              name: name,
              type: col_type,
              nullable: !not_null,
              default: default_value,
              primary_key: is_pk,
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

        # PRAGMA index_list returns: seq, name, unique, origin, partial
        rs = query_all("PRAGMA index_list(\"#{escape_identifier(table)}\")")
        index_info = [] of NamedTuple(name: String, unique: Bool, origin: String)
        begin
          while rs.move_next
            _seq = rs.read(Int32 | Int64)
            name = rs.read(String)
            unique = rs.read(Int32 | Int64) == 1
            origin = rs.read(String)
            _partial = rs.read(Int32 | Int64)

            index_info << {name: name, unique: unique, origin: origin}
          end
        ensure
          rs.close
        end

        # Get columns for each index
        index_info.each do |info|
          columns = [] of String

          # PRAGMA index_info returns: seqno, cid, name
          col_rs = query_all("PRAGMA index_info(\"#{escape_identifier(info[:name])}\")")
          begin
            while col_rs.move_next
              _seqno = col_rs.read(Int32 | Int64)
              _cid = col_rs.read(Int32 | Int64)
              col_name = col_rs.read(String | Nil)
              columns << col_name if col_name
            end
          ensure
            col_rs.close
          end

          indexes << Schema::DatabaseIndex.new(
            name: info[:name],
            table: table,
            columns: columns,
            unique: info[:unique],
            type: nil # SQLite doesn't have index types like PostgreSQL
          )
        end

        indexes
      end

      # Get foreign key constraints FROM a table (outgoing FKs)
      def introspect_foreign_keys(table : String) : Array(Schema::DatabaseForeignKey)
        foreign_keys = [] of Schema::DatabaseForeignKey

        # PRAGMA foreign_key_list returns: id, seq, table, from, to, on_update, on_delete, match
        rs = query_all("PRAGMA foreign_key_list(\"#{escape_identifier(table)}\")")
        begin
          while rs.move_next
            _id = rs.read(Int32 | Int64)
            _seq = rs.read(Int32 | Int64)
            to_table = rs.read(String)
            from_column = rs.read(String)
            to_column = rs.read(String)
            on_update = rs.read(String)
            on_delete = rs.read(String)
            _match = rs.read(String)

            foreign_keys << Schema::DatabaseForeignKey.new(
              name: nil, # SQLite doesn't name FK constraints
              from_table: table,
              from_column: from_column,
              to_table: to_table,
              to_column: to_column,
              on_delete: Schema.parse_referential_action(on_delete),
              on_update: Schema.parse_referential_action(on_update)
            )
          end
        ensure
          rs.close
        end

        foreign_keys
      end

      # Get foreign key constraints TO a table (incoming FKs)
      #
      # This requires scanning all tables since SQLite doesn't have a
      # reverse lookup for foreign keys.
      def introspect_foreign_keys_referencing(table : String) : Array(Schema::DatabaseForeignKey)
        incoming_fks = [] of Schema::DatabaseForeignKey

        # Check each table's foreign keys to see if they reference this table
        table_names.each do |other_table|
          next if other_table == table

          foreign_keys = introspect_foreign_keys(other_table)
          foreign_keys.each do |fk|
            if fk.to_table == table
              incoming_fks << fk
            end
          end
        end

        incoming_fks
      end

      # Escape an identifier for safe use in SQL
      private def escape_identifier(name : String) : String
        # Double up any double quotes in the name
        name.gsub("\"", "\"\"")
      end

      # Whether WAL mode is enabled
      def wal_mode? : Bool
        @wal_mode
      end

      # Get the original connection string (without pool params)
      def connection_string : String
        @connection_string
      end

      # Serialize write operations through a mutex when not in WAL mode.
      # In WAL mode, SQLite handles concurrency internally.
      private def with_write_lock(&)
        if @wal_mode
          yield
        else
          @write_mutex.synchronize { yield }
        end
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

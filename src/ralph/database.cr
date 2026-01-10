module Ralph
  # Abstract database backend interface
  #
  # All database backends must implement this interface to provide
  # a common API for database operations.
  #
  # ## Backend Loading
  #
  # Backends are NOT loaded automatically. Users must explicitly require
  # the backend they want to use:
  #
  # ```
  # require "ralph/backends/sqlite"   # For SQLite
  # require "ralph/backends/postgres" # For PostgreSQL
  # ```
  #
  # This allows backends to be truly optional - you only need the
  # database driver shard for the backend you're actually using.
  module Database
    # Connection pool statistics
    #
    # Provides insight into the current state of the connection pool.
    # Useful for monitoring, debugging, and capacity planning.
    #
    # ## Example
    #
    # ```
    # stats = Ralph.pool_stats
    # if stats
    #   puts "Open: #{stats.open_connections}"
    #   puts "Idle: #{stats.idle_connections}"
    #   puts "In-flight: #{stats.in_flight_connections}"
    # end
    # ```
    record PoolStats,
      # Total number of open connections (idle + in-flight)
      open_connections : Int32,
      # Number of connections currently idle in the pool
      idle_connections : Int32,
      # Number of connections currently checked out and in use
      in_flight_connections : Int32,
      # Maximum connections allowed (0 = unlimited)
      max_connections : Int32

    abstract class Backend
      # Execute a query and return the raw result
      abstract def execute(query : String, args : Array(DB::Any) = [] of DB::Any)

      # Execute a query and return the last inserted ID
      #
      # Implementation note: Different backends handle this differently:
      # - SQLite: Uses `SELECT last_insert_rowid()` after INSERT
      # - PostgreSQL: Uses `INSERT ... RETURNING id`
      abstract def insert(query : String, args : Array(DB::Any) = [] of DB::Any) : Int64

      # Query a single row and map it to a result
      abstract def query_one(query : String, args : Array(DB::Any) = [] of DB::Any) : ::DB::ResultSet?

      # Query multiple rows
      abstract def query_all(query : String, args : Array(DB::Any) = [] of DB::Any) : ::DB::ResultSet

      # Execute a query and return a single scalar value (first column of first row)
      abstract def scalar(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::Any?

      # Begin a transaction
      abstract def transaction(&block : ::DB::Transaction ->)

      # Close the database connection
      abstract def close

      # Check if the connection is open
      abstract def closed? : Bool

      # Transaction SQL generation methods
      # These allow backends to customize transaction SQL for their dialect

      # SQL to begin a transaction
      abstract def begin_transaction_sql : String

      # SQL to commit a transaction
      abstract def commit_sql : String

      # SQL to rollback a transaction
      abstract def rollback_sql : String

      # SQL to create a savepoint
      abstract def savepoint_sql(name : String) : String

      # SQL to release a savepoint
      abstract def release_savepoint_sql(name : String) : String

      # SQL to rollback to a savepoint
      abstract def rollback_to_savepoint_sql(name : String) : String

      # Returns the dialect identifier for this backend
      # Used by migrations and schema generation
      abstract def dialect : Symbol

      # Schema Introspection Methods
      # ============================
      #
      # These methods allow introspecting the actual database schema.
      # Used by `db:pull` (generate models from schema) and `db:generate`
      # (compare models against schema for diff-based migrations).
      #
      # Introspection is implemented at the backend level so that:
      # - Each backend uses its native introspection mechanisms
      # - Third-party backends can provide introspection out of the box
      # - CLI commands work uniformly across all backends

      # Get list of all user tables (excluding system tables)
      #
      # Should exclude:
      # - SQLite: sqlite_* tables, schema_migrations
      # - PostgreSQL: pg_* tables, information_schema tables, schema_migrations
      #
      # Returns table names in alphabetical order.
      abstract def table_names : Array(String)

      # Get column information for a specific table
      #
      # Returns all columns with their types, nullability, defaults, etc.
      abstract def introspect_columns(table : String) : Array(Schema::DatabaseColumn)

      # Get index information for a specific table
      #
      # Returns all indexes including primary key index.
      abstract def introspect_indexes(table : String) : Array(Schema::DatabaseIndex)

      # Get foreign key constraints FROM a table (outgoing FKs)
      #
      # These are FKs defined on this table that reference other tables.
      # Used for inferring `belongs_to` associations.
      abstract def introspect_foreign_keys(table : String) : Array(Schema::DatabaseForeignKey)

      # Get foreign key constraints TO a table (incoming FKs)
      #
      # These are FKs from OTHER tables that reference this table.
      # Used for inferring `has_many` and `has_one` associations.
      abstract def introspect_foreign_keys_referencing(table : String) : Array(Schema::DatabaseForeignKey)

      # Introspect a single table completely
      #
      # Returns a DatabaseTable with all columns, indexes, and foreign keys.
      def introspect_table(name : String) : Schema::DatabaseTable
        columns = introspect_columns(name)
        indexes = introspect_indexes(name)
        foreign_keys = introspect_foreign_keys(name)
        primary_key_columns = columns.select(&.primary_key).map(&.name)

        Schema::DatabaseTable.new(
          name: name,
          columns: columns,
          indexes: indexes,
          foreign_keys: foreign_keys,
          primary_key_columns: primary_key_columns
        )
      end

      # Introspect the entire database schema
      #
      # Returns a DatabaseSchema containing all tables with their
      # columns, indexes, and foreign keys.
      def introspect_schema : Schema::DatabaseSchema
        tables = {} of String => Schema::DatabaseTable

        table_names.each do |name|
          tables[name] = introspect_table(name)
        end

        Schema::DatabaseSchema.new(tables)
      end

      # Introspect specific tables only
      #
      # More efficient than full schema introspection when you only
      # need a subset of tables.
      def introspect_tables(names : Array(String)) : Schema::DatabaseSchema
        tables = {} of String => Schema::DatabaseTable

        names.each do |name|
          if table_names.includes?(name)
            tables[name] = introspect_table(name)
          end
        end

        Schema::DatabaseSchema.new(tables)
      end

      # Connection Pool Methods
      # =======================

      # Get the underlying DB::Database connection for advanced operations
      abstract def raw_connection : ::DB::Database

      # Get current connection pool statistics
      #
      # Returns a PoolStats record with information about the pool state.
      # Useful for monitoring and debugging connection issues.
      #
      # ## Example
      #
      # ```
      # stats = backend.pool_stats
      # puts "Connections: #{stats.open_connections}/#{stats.max_connections}"
      # ```
      def pool_stats : PoolStats
        db = raw_connection
        # Access the internal pool stats via DB::Database#pool
        stats = db.pool.stats
        PoolStats.new(
          open_connections: stats.open_connections,
          idle_connections: stats.idle_connections,
          in_flight_connections: stats.in_flight_connections,
          max_connections: stats.max_connections
        )
      end

      # Check if the connection pool is healthy
      #
      # Performs a simple query to verify database connectivity.
      # Returns true if the database is reachable and responsive.
      #
      # ## Example
      #
      # ```
      # if backend.pool_healthy?
      #   puts "Database connection OK"
      # else
      #   puts "Database connection FAILED"
      # end
      # ```
      def pool_healthy? : Bool
        # Try to execute a simple query
        scalar(health_check_query)
        true
      rescue ex
        false
      end

      # SQL query used for health checks
      #
      # Override in backends if needed for dialect-specific syntax.
      protected def health_check_query : String
        "SELECT 1"
      end

      # Prepared Statement Cache Methods
      # =================================

      # Clear the prepared statement cache
      #
      # This invalidates all cached statements, forcing them to be reparsed
      # on next use. Call this after schema changes or when you want to
      # release memory.
      #
      # ## Example
      #
      # ```
      # Ralph.database.clear_statement_cache
      # ```
      def clear_statement_cache
        # Default implementation does nothing
        # Backends override this if they support statement caching
      end

      # Get statistics about the prepared statement cache
      #
      # Returns a NamedTuple with cache size, max size, and enabled status.
      #
      # ## Example
      #
      # ```
      # stats = Ralph.database.statement_cache_stats
      # puts "Cached: #{stats[:size]}/#{stats[:max_size]}"
      # ```
      def statement_cache_stats : NamedTuple(size: Int32, max_size: Int32, enabled: Bool)
        # Default implementation returns empty stats
        {size: 0, max_size: 0, enabled: false}
      end

      # Enable or disable prepared statement caching at runtime
      #
      # ## Example
      #
      # ```
      # # Disable caching temporarily
      # Ralph.database.enable_statement_cache = false
      #
      # # Run some one-off queries...
      #
      # # Re-enable caching
      # Ralph.database.enable_statement_cache = true
      # ```
      def enable_statement_cache=(enabled : Bool)
        # Default implementation does nothing
      end

      # Check if prepared statement caching is enabled
      def statement_cache_enabled? : Bool
        false
      end

      # Convenience Methods for DBValue Arrays
      # =======================================
      #
      # These methods accept Array(Query::DBValue) which includes UUID,
      # and automatically convert to Array(DB::Any) for database execution.
      # This provides seamless UUID support throughout the ORM.

      # Execute with DBValue args (converts UUIDs to strings)
      def execute(query : String, args : Array(Query::DBValue))
        execute(query, args: Query.to_db_args(args))
      end

      # Insert with DBValue args (converts UUIDs to strings)
      def insert(query : String, args : Array(Query::DBValue)) : Int64
        insert(query, args: Query.to_db_args(args))
      end

      # Query one with DBValue args (converts UUIDs to strings)
      def query_one(query : String, args : Array(Query::DBValue)) : ::DB::ResultSet?
        query_one(query, args: Query.to_db_args(args))
      end

      # Query all with DBValue args (converts UUIDs to strings)
      def query_all(query : String, args : Array(Query::DBValue)) : ::DB::ResultSet
        query_all(query, args: Query.to_db_args(args))
      end

      # Scalar with DBValue args (converts UUIDs to strings)
      def scalar(query : String, args : Array(Query::DBValue)) : DB::Any?
        scalar(query, args: Query.to_db_args(args))
      end
    end
  end
end

# NOTE: Backends are NOT auto-loaded. Users must require them explicitly:
#   require "ralph/backends/sqlite"
#   require "ralph/backends/postgres"

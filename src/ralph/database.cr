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
    end
  end
end

# NOTE: Backends are NOT auto-loaded. Users must require them explicitly:
#   require "ralph/backends/sqlite"
#   require "ralph/backends/postgres"

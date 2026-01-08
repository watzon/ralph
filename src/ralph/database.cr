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
    end
  end
end

# NOTE: Backends are NOT auto-loaded. Users must require them explicitly:
#   require "ralph/backends/sqlite"
#   require "ralph/backends/postgres"

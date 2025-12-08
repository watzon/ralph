module Ralph
  # Abstract database backend interface
  #
  # All database backends must implement this interface to provide
  # a common API for database operations.
  module Database
    abstract class Backend
      # Execute a query and return the raw result
      abstract def execute(query : String, args : Array(DB::Any) = [] of DB::Any)

      # Execute a query and return the last inserted ID
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
    end
  end
end

require "./backends/*"

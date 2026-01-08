require "db"
require "pg"

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

      # Creates a new PostgreSQL backend with the given connection string
      #
      # ## Example
      #
      # ```
      # backend = Ralph::Database::PostgresBackend.new("postgres://localhost/mydb")
      # ```
      def initialize(@connection_string : String)
        @db = DB.open(connection_string)
      end

      def execute(query : String, args : Array(DB::Any) = [] of DB::Any)
        @db.exec(convert_placeholders(query), args: args)
      end

      def insert(query : String, args : Array(DB::Any) = [] of DB::Any) : Int64
        modified_query = append_returning_id(convert_placeholders(query))
        result = @db.query_one(modified_query, args: args, as: Int64)
        result
      end

      def query_one(query : String, args : Array(DB::Any) = [] of DB::Any) : ::DB::ResultSet?
        rs = @db.query(convert_placeholders(query), args: args)
        rs.move_next ? rs : nil
      end

      def query_all(query : String, args : Array(DB::Any) = [] of DB::Any) : ::DB::ResultSet
        @db.query(convert_placeholders(query), args: args)
      end

      def scalar(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::Any?
        result = @db.scalar(convert_placeholders(query), args: args)
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
    end
  end
end

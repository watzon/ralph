require "db"
require "sqlite3"

module Ralph
  module Database
    # SQLite backend implementation
    class SqliteBackend < Backend
      @db : ::DB::Database
      @closed : Bool = false

      # Create a new SQLite backend with a connection string
      #
      # Example:
      # ```
      # Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
      # ```
      def initialize(@connection_string : String)
        @db = DB.open(connection_string)
      end

      def execute(query : String, args : Array(DB::Any) = [] of DB::Any)
        @db.exec(query, args: args)
      end

      def insert(query : String, args : Array(DB::Any) = [] of DB::Any) : Int64
        @db.exec(query, args: args)
        @db.scalar("SELECT last_insert_rowid()").as(Int64)
      end

      def query_one(query : String, args : Array(DB::Any) = [] of DB::Any) : ::DB::ResultSet?
        rs = @db.query(query, args: args)
        rs.move_next ? rs : nil
      end

      def query_all(query : String, args : Array(DB::Any) = [] of DB::Any) : ::DB::ResultSet
        @db.query(query, args: args)
      end

      def scalar(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::Any?
        @db.scalar(query, args: args)
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

      # Get the underlying DB connection for direct access when needed
      def raw_connection : ::DB::Database
        @db
      end
    end
  end
end

require "db"
require "sqlite3"
require "uri"

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
        @write_mutex = Mutex.new
        @wal_mode = wal_mode

        # Build connection string with pool parameters
        final_connection_string = if apply_pool_settings
                                    build_pooled_connection_string(connection_string)
                                  else
                                    connection_string
                                  end

        @db = DB.open(final_connection_string)

        # Set a busy timeout to wait for locks instead of failing immediately
        @db.exec("PRAGMA busy_timeout=#{busy_timeout}")

        # Enable WAL mode if requested (skip for in-memory databases)
        if wal_mode && !connection_string.includes?(":memory:")
          @db.exec("PRAGMA journal_mode=WAL")
        end
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
      def execute(query : String, args : Array(DB::Any) = [] of DB::Any)
        with_write_lock do
          @db.exec(query, args: args)
        end
      end

      # Insert a record and return the last inserted row ID
      # Uses the same connection for both operations to ensure correctness
      def insert(query : String, args : Array(DB::Any) = [] of DB::Any) : Int64
        with_write_lock do
          @db.using_connection do |conn|
            conn.exec(query, args: args)
            conn.scalar("SELECT last_insert_rowid()").as(Int64)
          end
        end
      end

      # Query for a single row, returns nil if no results
      def query_one(query : String, args : Array(DB::Any) = [] of DB::Any) : ::DB::ResultSet?
        rs = @db.query(query, args: args)
        rs.move_next ? rs : nil
      end

      # Query for multiple rows
      def query_all(query : String, args : Array(DB::Any) = [] of DB::Any) : ::DB::ResultSet
        @db.query(query, args: args)
      end

      # Execute a scalar query and return a single value
      def scalar(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::Any?
        result = @db.scalar(query, args: args)
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
    end
  end
end

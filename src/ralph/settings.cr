module Ralph
  # Global settings for the ORM
  #
  # Settings can be configured via `Ralph.configure`:
  #
  # ```
  # Ralph.configure do |config|
  #   config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
  #
  #   # Connection pool settings
  #   config.initial_pool_size = 5
  #   config.max_pool_size = 25
  #   config.max_idle_pool_size = 10
  #   config.checkout_timeout = 5.0
  #   config.retry_attempts = 3
  #   config.retry_delay = 0.2
  # end
  # ```
  class Settings
    # The primary database backend to use
    property database : Database::Backend?

    # Check if a database is configured
    def database? : Bool
      !@database.nil?
    end

    # Hash of named database backends
    # Allows connecting to multiple databases
    property databases : Hash(String, Database::Backend) = Hash(String, Database::Backend).new

    # Connection Pool Configuration
    # =============================
    #
    # These settings control how the connection pool manages database connections.
    # Crystal's DB shard provides automatic connection pooling; these settings
    # configure that behavior.

    # Initial number of connections created when the pool is established.
    #
    # Higher values mean faster initial queries but more upfront resource usage.
    #
    # **Note for SQLite**: Should be kept at 1 since SQLite only supports one
    # writer at a time and Ralph's transaction management assumes single-connection.
    #
    # Recommended: 1 for SQLite, 5-10 for PostgreSQL in production.
    property initial_pool_size : Int32 = 1

    # Maximum number of connections the pool can hold (idle + in-use).
    #
    # Set to 0 for unlimited connections (not recommended for production).
    # When reached, new requests wait until a connection becomes available.
    # Recommended: 10-25 for low traffic, 50-100 for high traffic.
    property max_pool_size : Int32 = 0

    # Maximum number of idle connections to keep in the pool.
    #
    # When a connection is released and idle count exceeds this, it's closed.
    # Higher values = faster checkout but more memory usage.
    #
    # **Note for SQLite**: Should be kept at 1 to match initial_pool_size.
    #
    # Recommended: 1 for SQLite, 10-25 for PostgreSQL in production.
    property max_idle_pool_size : Int32 = 1

    # Seconds to wait for an available connection before raising PoolTimeout.
    #
    # Should be set slightly higher than your slowest expected query.
    # Recommended: 5.0 for development, 10.0-30.0 for production.
    property checkout_timeout : Float64 = 5.0

    # Number of times to retry establishing a connection on failure.
    #
    # Useful for handling temporary network issues or database restarts.
    # Set higher for production resilience.
    # Recommended: 1-3 for development, 3-5 for production.
    property retry_attempts : Int32 = 3

    # Seconds to wait between connection retry attempts.
    #
    # Should be long enough for transient issues to resolve.
    # Recommended: 0.2-0.5 for development, 0.5-2.0 for production.
    property retry_delay : Float64 = 0.2

    # Prepared Statement Cache Configuration
    # ======================================
    #
    # These settings control prepared statement caching, which can improve
    # query performance by avoiding repeated SQL parsing and planning.

    # Whether to enable prepared statement caching.
    #
    # When enabled, SQL queries are compiled once and reused with different
    # parameters. This reduces database overhead for frequently executed queries.
    #
    # **Note**: Enable only if your application executes the same queries
    # repeatedly with different parameters.
    #
    # Default: true
    property enable_prepared_statements : Bool = true

    # Maximum number of prepared statements to cache per database connection.
    #
    # Higher values use more memory but can improve performance for applications
    # with many distinct queries. When the cache is full, least recently used
    # statements are evicted.
    #
    # Recommended: 50-100 for most applications, 200+ for query-heavy apps.
    # Default: 100
    property prepared_statement_cache_size : Int32 = 100

    # Query Cache Configuration
    # =========================
    #
    # These settings control the query result cache, which stores query results
    # in memory to avoid repeated database queries for identical SQL.

    # Whether to enable query result caching.
    #
    # When enabled, queries marked with `.cache` will store their results
    # and return cached data on subsequent executions with the same SQL/params.
    #
    # **Note for tests**: This is typically disabled during testing to ensure
    # predictable behavior. Set to false or use `Ralph::Query.configure_cache(enabled: false)`.
    #
    # Default: true (but consider disabling in test environment)
    property query_cache_enabled : Bool = true

    # Maximum number of query results to cache.
    #
    # When the cache is full, least recently used entries are evicted.
    # Higher values use more memory but can improve hit rates.
    #
    # Recommended: 500-1000 for most applications.
    # Default: 1000
    property query_cache_max_size : Int32 = 1000

    # Default time-to-live for cached query results.
    #
    # Cached results expire after this duration and will be re-fetched
    # from the database. Shorter TTLs ensure fresher data but reduce
    # cache effectiveness.
    #
    # Recommended: 1-5 minutes for most applications.
    # Default: 5 minutes
    property query_cache_ttl : Time::Span = 5.minutes

    # Whether to automatically invalidate cache on model writes.
    #
    # When enabled, saving, updating, or destroying a model will automatically
    # invalidate cached queries that reference the model's table.
    #
    # Default: true
    property query_cache_auto_invalidate : Bool = true

    def initialize
    end

    # Apply query cache settings to the global cache
    #
    # Call this after modifying cache settings to apply them.
    def apply_query_cache_settings : Nil
      Ralph::Query.configure_cache(
        max_size: @query_cache_max_size,
        default_ttl: @query_cache_ttl,
        enabled: @query_cache_enabled
      )
    end

    # Register a named database backend
    #
    # ## Parameters
    #
    # - `name`: The name for this database connection
    # - `backend`: The Database::Backend instance
    #
    # ## Example
    #
    # ```
    # Ralph.configure do |config|
    #   config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
    #
    #   # Add analytics database
    #   analytics = Ralph::Database::PostgresBackend.new("postgres://localhost/analytics")
    #   config.register_database("analytics", analytics)
    # end
    # ```
    def register_database(name : String, backend : Database::Backend)
      @databases[name] = backend
    end

    # Get a named database backend
    #
    # ## Parameters
    #
    # - `name`: The name of the database
    #
    # ## Returns
    #
    # The Database::Backend instance for the named database
    #
    # ## Raises
    #
    # If named database is not registered
    def get_database(name : String) : Database::Backend
      if name == "default"
        database || raise "Default database not configured. Call Ralph.configure first."
      else
        @databases[name]? || raise "Database '#{name}' not registered."
      end
    end

    # Build query string parameters for pool configuration.
    #
    # Returns a hash that can be merged into connection URI query params.
    def pool_params : Hash(String, String)
      {
        "initial_pool_size"  => @initial_pool_size.to_s,
        "max_pool_size"      => @max_pool_size.to_s,
        "max_idle_pool_size" => @max_idle_pool_size.to_s,
        "checkout_timeout"   => @checkout_timeout.to_s,
        "retry_attempts"     => @retry_attempts.to_s,
        "retry_delay"        => @retry_delay.to_s,
      }
    end

    # Validate pool settings and return any warnings.
    #
    # Returns an array of warning messages (empty if all settings are valid).
    def validate_pool_settings : Array(String)
      warnings = [] of String

      if @initial_pool_size < 0
        warnings << "initial_pool_size cannot be negative (got #{@initial_pool_size})"
      end

      if @max_pool_size < 0
        warnings << "max_pool_size cannot be negative (got #{@max_pool_size})"
      end

      if @max_pool_size > 0 && @initial_pool_size > @max_pool_size
        warnings << "initial_pool_size (#{@initial_pool_size}) exceeds max_pool_size (#{@max_pool_size})"
      end

      if @max_idle_pool_size < 0
        warnings << "max_idle_pool_size cannot be negative (got #{@max_idle_pool_size})"
      end

      if @max_pool_size > 0 && @max_idle_pool_size > @max_pool_size
        warnings << "max_idle_pool_size (#{@max_idle_pool_size}) exceeds max_pool_size (#{@max_pool_size})"
      end

      if @checkout_timeout <= 0
        warnings << "checkout_timeout must be positive (got #{@checkout_timeout})"
      end

      if @retry_attempts < 0
        warnings << "retry_attempts cannot be negative (got #{@retry_attempts})"
      end

      if @retry_delay < 0
        warnings << "retry_delay cannot be negative (got #{@retry_delay})"
      end

      warnings
    end
  end

  @@settings = Settings.new

  def self.settings : Settings
    @@settings
  end

  def self.settings=(value : Settings)
    @@settings = value
  end
end

require "./database"

# Ralph - An ORM for Crystal
#
# Ralph is an Active Record-style ORM for Crystal with a focus on:
# - Developer experience
# - Type safety
# - Explicit over implicit behavior
# - Pluggable database backends
#
# Basic usage:
#
# ```
# Ralph.configure do |config|
#   config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
# end
#
# class User < Ralph::Model
#   table :users
#
#   column id : Int64, primary: true
#   column name : String
#   column email : String
#   column created_at : Time?
# end
#
# # Create
# user = User.new(name: "Alice", email: "alice@example.com")
# user.save
#
# # Read
# user = User.find(1)
# users = User.query { |q| q.where("name = ?", "Alice") }.to_a
#
# # Update
# user.name = "Bob"
# user.save
#
# # Delete
# user.destroy
# ```
module Ralph
  VERSION = "1.0.0-beta.3"

  # Configure the ORM with a block
  def self.configure(&)
    yield settings
  end

  # Get the current database connection
  def self.database
    settings.database || raise "Database not configured. Call Ralph.configure first."
  end

  # Connection Pool Methods
  # =======================

  # Get current connection pool statistics
  #
  # Returns pool statistics if a database is configured, nil otherwise.
  # Useful for monitoring connection pool health in production.
  #
  # ## Example
  #
  # ```
  # if stats = Ralph.pool_stats
  #   puts "Open connections: #{stats.open_connections}"
  #   puts "Idle connections: #{stats.idle_connections}"
  #   puts "In-flight connections: #{stats.in_flight_connections}"
  #   puts "Max connections: #{stats.max_connections}"
  # end
  # ```
  #
  # ## Monitoring
  #
  # Use this method to:
  # - Monitor connection usage in production
  # - Detect connection pool exhaustion
  # - Tune pool configuration parameters
  def self.pool_stats : Database::PoolStats?
    if db = settings.database
      db.pool_stats
    end
  end

  # Check if the database connection pool is healthy
  #
  # Performs a simple health check query to verify database connectivity.
  # Returns true if the database is reachable and responsive, false otherwise.
  #
  # ## Example
  #
  # ```
  # if Ralph.pool_healthy?
  #   puts "Database connection: OK"
  # else
  #   puts "Database connection: FAILED"
  # end
  # ```
  #
  # ## Health Checks
  #
  # Use this method for:
  # - Kubernetes/Docker health check endpoints
  # - Load balancer health probes
  # - Application startup verification
  # - Periodic monitoring
  def self.pool_healthy? : Bool
    if db = settings.database
      db.pool_healthy?
    else
      false
    end
  end

  # Get detailed pool information including configuration
  #
  # Returns a hash with current pool statistics and configuration settings.
  # Useful for debugging and monitoring dashboards.
  #
  # ## Example
  #
  # ```
  # info = Ralph.pool_info
  # puts "Pool status:"
  # info.each do |key, value|
  #   puts "  #{key}: #{value}"
  # end
  # ```
  def self.pool_info : Hash(String, String | Int32 | Float64 | Bool)
    info = {} of String => String | Int32 | Float64 | Bool

    # Configuration settings
    info["initial_pool_size"] = settings.initial_pool_size
    info["max_pool_size"] = settings.max_pool_size
    info["max_idle_pool_size"] = settings.max_idle_pool_size
    info["checkout_timeout"] = settings.checkout_timeout
    info["retry_attempts"] = settings.retry_attempts
    info["retry_delay"] = settings.retry_delay

    # Runtime statistics
    if stats = pool_stats
      info["open_connections"] = stats.open_connections
      info["idle_connections"] = stats.idle_connections
      info["in_flight_connections"] = stats.in_flight_connections
      info["max_connections"] = stats.max_connections
    end

    # Health status
    info["healthy"] = pool_healthy?

    # Backend info
    if db = settings.database
      info["dialect"] = db.dialect.to_s
      info["closed"] = db.closed?
    end

    info
  end

  # Validate pool configuration and return any warnings
  #
  # Returns an array of warning messages about potential pool configuration issues.
  # Empty array means all settings are valid.
  #
  # ## Example
  #
  # ```
  # warnings = Ralph.validate_pool_config
  # if warnings.empty?
  #   puts "Pool configuration: OK"
  # else
  #   warnings.each do |warning|
  #     puts "WARNING: #{warning}"
  #   end
  # end
  # ```
  def self.validate_pool_config : Array(String)
    settings.validate_pool_settings
  end

  # Query Cache Methods
  # ===================

  # Get query cache statistics
  #
  # Returns statistics about cache hits, misses, size, evictions, etc.
  #
  # ## Example
  #
  # ```
  # stats = Ralph.cache_stats
  # puts "Hits: #{stats.hits}"
  # puts "Misses: #{stats.misses}"
  # puts "Hit rate: #{(stats.hit_rate * 100).round(1)}%"
  # puts "Size: #{stats.size}"
  # puts "Evictions: #{stats.evictions}"
  # ```
  def self.cache_stats : Query::QueryCache::Stats
    Query.cache_stats
  end

  # Clear the query cache
  #
  # Removes all cached query results. This is useful when you need
  # to ensure fresh data is loaded from the database.
  #
  # ## Example
  #
  # ```
  # Ralph.clear_cache
  # ```
  def self.clear_cache : Nil
    Query.clear_cache
  end

  # Check if query caching is enabled
  def self.cache_enabled? : Bool
    Query.query_cache.enabled?
  end

  # Disable query caching (clears all cached entries)
  #
  # Useful for testing or when you need to ensure fresh data.
  def self.disable_cache : Nil
    Query.query_cache.disable
  end

  # Enable query caching
  def self.enable_cache : Nil
    Query.query_cache.enable
  end

  # Invalidate cache entries for a specific table
  #
  # This is called automatically on model save/update/destroy when
  # `query_cache_auto_invalidate` is enabled (default).
  #
  # ## Parameters
  #
  # - `table`: The table name to invalidate
  #
  # ## Returns
  #
  # The number of cache entries that were invalidated.
  def self.invalidate_table_cache(table : String) : Int32
    Query.invalidate_table_cache(table)
  end
end

# External dependencies
require "cadmium_inflector"

# Core library requires
require "./ralph/errors"
require "./ralph/settings"
require "./ralph/schema/*"
require "./ralph/database"
require "./ralph/types/types"
require "./ralph/validations"
require "./ralph/callbacks"
require "./ralph/associations"
require "./ralph/transactions"
require "./ralph/eager_loading"
require "./ralph/timestamps"
require "./ralph/acts_as_paranoid"
require "./ralph/bulk_operations"
require "./ralph/identity_map"
require "./ralph/model"
require "./ralph/query/*"
require "./ralph/migrations/*"
require "./ralph/cli/*"
require "./ralph/cli/generators"

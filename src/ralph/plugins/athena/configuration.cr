# Athena Framework integration - Configuration module
#
# Provides helpers for configuring Ralph within an Athena application.
# Automatically detects database backend from DATABASE_URL environment variable.
#
# ## Example
#
# ```
# require "ralph/plugins/athena"
#
# # Auto-configure from DATABASE_URL
# Ralph::Athena.configure
#
# # Or with custom settings
# Ralph::Athena.configure do |config|
#   config.max_pool_size = 25
#   config.query_cache_enabled = true
# end
# ```
module Ralph::Athena
  # Configuration options for the Athena integration
  class Configuration
    # Whether to automatically run pending migrations on application startup.
    # Default: false
    property auto_migrate : Bool = false

    # Whether to log migration activity to STDOUT.
    # Default: true
    property log_migrations : Bool = true

    # The database URL to use. If not set, reads from DATABASE_URL environment variable.
    property database_url : String?

    def initialize
    end
  end

  # Global configuration instance
  class_property config : Configuration = Configuration.new

  # Configure Ralph for use with Athena Framework.
  #
  # This method:
  # 1. Reads DATABASE_URL from environment (or uses provided URL)
  # 2. Auto-detects the appropriate backend (SQLite or PostgreSQL)
  # 3. Configures Ralph with sensible defaults
  # 4. Optionally runs pending migrations
  #
  # ## Parameters
  #
  # - `database_url`: Optional database URL. If not provided, reads from DATABASE_URL env var.
  # - `auto_migrate`: Whether to run pending migrations on startup. Default: false.
  #
  # ## Example
  #
  # ```
  # # Simple setup - reads DATABASE_URL from environment
  # Ralph::Athena.configure
  #
  # # With auto-migrations
  # Ralph::Athena.configure(auto_migrate: true)
  #
  # # With custom URL
  # Ralph::Athena.configure(database_url: "sqlite3://./dev.db")
  #
  # # With block for additional Ralph settings
  # Ralph::Athena.configure(auto_migrate: true) do |config|
  #   config.max_pool_size = 50
  #   config.query_cache_ttl = 10.minutes
  # end
  # ```
  #
  # ## Backend Detection
  #
  # The backend is auto-detected from the URL scheme:
  # - `sqlite3://` or `sqlite://` → Requires `ralph/backends/sqlite` to be required
  # - `postgres://` or `postgresql://` → Requires `ralph/backends/postgres` to be required
  #
  # Make sure to require the appropriate backend BEFORE calling configure:
  #
  # ```
  # require "ralph/backends/sqlite"
  # require "ralph/plugins/athena"
  #
  # Ralph::Athena.configure(database_url: "sqlite3://./dev.db")
  # ```
  def self.configure(
    database_url : String? = nil,
    auto_migrate : Bool = false,
    log_migrations : Bool = true,
    &
  ) : Nil
    # Store Athena-specific config
    @@config.database_url = database_url
    @@config.auto_migrate = auto_migrate
    @@config.log_migrations = log_migrations

    # Configure Ralph
    Ralph.configure do |ralph_config|
      # Set database backend
      url = database_url || ENV["DATABASE_URL"]?
      raise ConfigurationError.new("DATABASE_URL environment variable not set and no database_url provided") unless url

      ralph_config.database = backend_from_url(url)

      # Allow user to customize Ralph settings
      yield ralph_config
    end

    # Run migrations if requested (not using listener, just on configure)
    # Note: The AutoMigrationListener handles this on first request instead
    # This is here for cases where you want migrations before the server starts
  end

  # Overload without block
  def self.configure(
    database_url : String? = nil,
    auto_migrate : Bool = false,
    log_migrations : Bool = true,
  ) : Nil
    configure(database_url: database_url, auto_migrate: auto_migrate, log_migrations: log_migrations) { }
  end

  # Run any pending migrations.
  #
  # This is called automatically if `auto_migrate: true` is passed to `configure`,
  # but can also be called manually at any time.
  #
  # ## Example
  #
  # ```
  # Ralph::Athena.run_pending_migrations
  # ```
  def self.run_pending_migrations : Nil
    migrator = Ralph::Migrations::Migrator.new(Ralph.database)
    pending = migrator.status.select { |_, applied| !applied }

    if pending.any?
      if @@config.log_migrations
        puts "[Ralph::Athena] Running #{pending.size} pending migration(s)..."
      end

      migrator.migrate(:up)

      if @@config.log_migrations
        puts "[Ralph::Athena] Migrations complete!"
      end
    elsif @@config.log_migrations
      puts "[Ralph::Athena] No pending migrations."
    end
  end

  # Create a database backend from a connection URL.
  #
  # Automatically detects the backend type from the URL scheme:
  # - `sqlite3://` → SqliteBackend (requires ralph/backends/sqlite)
  # - `postgres://` or `postgresql://` → PostgresBackend (requires ralph/backends/postgres)
  #
  # ## Raises
  #
  # - `ConfigurationError` if the URL scheme is not supported
  # - `ConfigurationError` if the required backend is not loaded
  private def self.backend_from_url(url : String) : Ralph::Database::Backend
    case url
    when .starts_with?("sqlite3://"), .starts_with?("sqlite://")
      {% if @top_level.has_constant?("Ralph") && Ralph::Database.has_constant?("SqliteBackend") %}
        Ralph::Database::SqliteBackend.new(url)
      {% else %}
        raise ConfigurationError.new(
          "SQLite backend not loaded. Add `require \"ralph/backends/sqlite\"` before requiring the Athena plugin."
        )
      {% end %}
    when .starts_with?("postgres://"), .starts_with?("postgresql://")
      {% if @top_level.has_constant?("Ralph") && Ralph::Database.has_constant?("PostgresBackend") %}
        Ralph::Database::PostgresBackend.new(url)
      {% else %}
        raise ConfigurationError.new(
          "PostgreSQL backend not loaded. Add `require \"ralph/backends/postgres\"` before requiring the Athena plugin."
        )
      {% end %}
    else
      scheme = url.split("://").first? || "unknown"
      raise ConfigurationError.new("Unsupported database scheme: #{scheme}. Supported: sqlite3, postgres")
    end
  end

  # Raised when there's a configuration error in the Athena integration.
  class ConfigurationError < Ralph::Error
  end
end

require "ralph"
require "ralph/backends/sqlite"
require "kemal-session"

# Configure Ralph
# Enable WAL mode for better concurrency with web requests
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./blog.sqlite3")
end

# Configure sessions
Kemal::Session.config do |config|
  config.cookie_name = "blog_session"
  config.secret = ENV.fetch("SESSION_SECRET", "super-secret-key-change-in-production")
  config.gc_interval = 2.minutes
end

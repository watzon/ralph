require "athena"
require "ralph"
require "ralph/backends/sqlite"
require "ralph/plugins/athena"

# Load migrations BEFORE configure so auto_migrate can find them
require "../db/migrations/*"

require "./models/*"
require "./services/*"
require "./controllers/*"
require "./listeners/*"

module Blog
  VERSION = "0.1.0"

  module Controllers; end

  module Models; end

  module Services; end

  module Listeners; end
end

# Configure Ralph using the Athena plugin
# This reads DATABASE_URL from environment, or uses the provided URL
Ralph::Athena.configure(
  database_url: "sqlite3://./blog.sqlite3",
  auto_migrate: true,
  log_migrations: true
)

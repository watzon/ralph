# Ralph ORM - Athena Framework Integration
#
# This plugin provides seamless integration between Ralph ORM and the Athena Framework.
# It includes:
#
# - **Configuration helpers**: Auto-detect database backend from DATABASE_URL
# - **DI Service**: Injectable `Ralph::Athena::Service` for controllers
# - **Auto-migrations**: Optional listener to run migrations on app startup
#
# ## Installation
#
# Add Ralph and Athena to your `shard.yml`:
#
# ```yaml
# dependencies:
#   ralph:
#     github: watzon/ralph
#   athena:
#     github: athena-framework/framework
# ```
#
# ## Quick Start
#
# ```
# require "athena"
# require "ralph"
# require "ralph/backends/sqlite" # or postgres
# require "ralph/plugins/athena"
#
# # Configure Ralph (reads DATABASE_URL from environment)
# Ralph::Athena.configure
#
# # Or with options
# Ralph::Athena.configure(
#   database_url: "sqlite3://./dev.db",
#   auto_migrate: true
# )
#
# # Use in controllers
# class UsersController < ATH::Controller
#   def initialize(@ralph : Ralph::Athena::Service)
#   end
#
#   @[ARTA::Get("/users")]
#   def index : Array(User)
#     User.all.to_a
#   end
#
#   @[ARTA::Post("/users")]
#   def create(request : ATH::Request) : User
#     @ralph.transaction do
#       user = User.new(name: request.request_data["name"].to_s)
#       user.save!
#       user
#     end
#   end
# end
#
# ATH.run
# ```
#
# ## Configuration Options
#
# The `configure` method accepts the following options:
#
# | Option | Type | Default | Description |
# |--------|------|---------|-------------|
# | `database_url` | String? | ENV["DATABASE_URL"] | Database connection URL |
# | `auto_migrate` | Bool | false | Run pending migrations on startup |
# | `log_migrations` | Bool | true | Log migration activity to STDOUT |
#
# You can also pass a block to customize Ralph settings:
#
# ```
# Ralph::Athena.configure(auto_migrate: true) do |config|
#   config.max_pool_size = 50
#   config.query_cache_ttl = 10.minutes
# end
# ```
#
# ## Service Injection
#
# The `Ralph::Athena::Service` is automatically registered with Athena's DI container.
# Inject it into your controllers or services:
#
# ```
# class MyService
#   def initialize(@ralph : Ralph::Athena::Service)
#   end
#
#   def do_something
#     @ralph.transaction do
#       # ... database operations
#     end
#   end
# end
# ```
#
# ## Available Service Methods
#
# | Method | Description |
# |--------|-------------|
# | `database` | Returns the raw database backend |
# | `transaction(&)` | Execute block in transaction |
# | `healthy?` | Check database connectivity |
# | `pool_stats` | Get connection pool statistics |
# | `pool_info` | Get detailed pool information |
# | `clear_cache` | Clear the query cache |
# | `invalidate_cache(table)` | Invalidate cache for specific table |
#
# ## Auto-Migrations
#
# When `auto_migrate: true` is set, Ralph will automatically run pending migrations
# when the application starts (on the first HTTP request).
#
# **Note**: Auto-migrations are convenient for development but not recommended for
# production. In production, run migrations explicitly:
#
# ```bash
# ./ralph.cr db:migrate
# ```
#
# ## Health Checks
#
# Use the service's `healthy?` method for health check endpoints:
#
# ```
# @[ARTA::Get("/health")]
# def health : NamedTuple(status: String, database: Bool)
#   {status: "ok", database: @ralph.healthy?}
# end
# ```

# Require Athena framework (user should have already required this)
require "athena"

# Require plugin components
require "./athena/configuration"
require "./athena/service"
require "./athena/migration_listener"

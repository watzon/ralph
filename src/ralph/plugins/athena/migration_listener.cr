# Athena Framework integration - Auto Migration Listener
#
# An optional event listener that runs pending migrations on the first HTTP request.
# This is useful for development environments where you want migrations to run
# automatically when you start the server.
#
# ## Usage
#
# To enable auto-migrations, require this file and configure Ralph::Athena with
# `auto_migrate: true`:
#
# ```
# require "ralph/plugins/athena"
#
# Ralph::Athena.configure(auto_migrate: true)
# ```
#
# ## Production Considerations
#
# Auto-migrations on first request is generally **not recommended for production**.
# In production, you should run migrations explicitly during deployment:
#
# ```bash
# ./ralph.cr db:migrate
# ```
#
# Or use a separate migration process before starting your application.
module Ralph::Athena
  # Event listener that runs pending migrations on the first HTTP request.
  #
  # This listener is automatically registered with Athena's DI container,
  # but only executes migrations if `Ralph::Athena.config.auto_migrate` is true.
  #
  # The listener runs at high priority (1024) to ensure migrations complete
  # before any database queries are attempted.
  @[ADI::Register]
  struct AutoMigrationListener
    @@migrations_checked : Bool = false

    # Listen for request events at high priority
    # Priority 1024 ensures this runs before most application logic
    @[AEDA::AsEventListener(priority: 1024)]
    def on_request(event : ATH::Events::Request) : Nil
      return unless Ralph::Athena.config.auto_migrate
      return if @@migrations_checked

      @@migrations_checked = true
      Ralph::Athena.run_pending_migrations
    rescue ex : Exception
      # Log migration errors but don't crash the request
      # In a real app, you'd want proper error handling here
      if Ralph::Athena.config.log_migrations
        puts "[Ralph::Athena] Migration error: #{ex.message}"
        puts ex.backtrace.join("\n") if ex.backtrace
      end
      raise ex
    end
  end
end

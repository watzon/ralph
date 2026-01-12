# Ralph ORM - Athena Console Commands
#
# Provides database management commands for Athena applications using Ralph.
# Commands are automatically registered with Athena's DI container and available
# via `ATH.run_console`.
#
# ## Available Commands
#
# - `db:migrate` - Run pending migrations
# - `db:rollback` - Roll back migrations
# - `db:status` - Show migration status
# - `db:version` - Show current migration version
# - `db:create` - Create the database
# - `db:drop` - Drop the database
# - `db:seed` - Load the seed file
# - `db:reset` - Drop, create, migrate, and seed
# - `db:setup` - Create database and run migrations
# - `db:pool` - Show connection pool status
# - `db:pull` - Generate models from database schema
# - `db:generate` - Generate migration from model diff
# - `generate:migration` - Create a new empty migration file
# - `generate:model` - Generate a model with migration
#
# ## Usage
#
# ```
# require "ralph/plugins/athena"
# require "ralph/plugins/athena/commands"
#
# # Commands are automatically registered
# ATH.run_console
# ```

require "athena"
require "option_parser"
require "file_utils"
require "db"

module Ralph::Athena::Commands
  # Base class for all Ralph database commands.
  # Provides common functionality for database operations.
  abstract class DatabaseCommand < ACON::Command
    @migrations_dir : String = "./db/migrations"
    @models_dir : String = "./src/models"

    # Extract a meaningful error message from an exception.
    # Falls back to the exception class name if message is nil or empty.
    protected def error_message(ex : Exception) : String
      ex.message.try(&.presence) || ex.class.name
    end

    protected def configure : Nil
      # Get defaults from global config
      migrations_default = Ralph::Athena.config.migrations_dir
      models_default = Ralph::Athena.config.models_dir

      self
        .option("migrations", "m", :required, "Migrations directory (default: #{migrations_default})")
        .option("models", nil, :required, "Models directory (default: #{models_default})")
    end

    protected def initialize_options(input : ACON::Input::Interface) : Nil
      # Start with global config values as defaults
      @migrations_dir = Ralph::Athena.config.migrations_dir
      @models_dir = Ralph::Athena.config.models_dir

      # Override with command-line options if provided
      if dir = input.option("migrations", String?)
        @migrations_dir = dir
      end
      if dir = input.option("models", String?)
        @models_dir = dir
      end
    end

    # Get the database backend, ensuring connection is established first.
    # Call this for commands that need the database to exist and be accessible.
    protected def database : Ralph::Database::Backend
      Ralph::Athena.ensure_connected
      Ralph.database
    end

    # Get the database URL from config or environment.
    # Use this for commands that need the URL but not an active connection
    # (like db:create and db:drop).
    protected def database_url : String
      Ralph::Athena.config.database_url ||
        ENV["DATABASE_URL"]? ||
        ENV["POSTGRES_URL"]? ||
        ENV["SQLITE_URL"]? ||
        "sqlite3://./db/development.sqlite3"
    end

    # Extract database name from a PostgreSQL URL
    protected def extract_postgres_db_name(url : String) : String
      url_without_query = url.split("?").first
      if match = url_without_query.match(/\/([^\/]+)$/)
        match[1]
      else
        raise "Could not extract database name from URL: #{url}"
      end
    end
  end

  # Run pending database migrations.
  @[ADI::Register]
  @[ACONA::AsCommand("db:migrate", description: "Run pending database migrations")]
  class MigrateCommand < DatabaseCommand
    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      initialize_options(input)
      style = ACON::Style::Athena.new(input, output)

      style.title("Running Migrations")

      migrator = Ralph::Migrations::Migrator.new(database, @migrations_dir)
      pending = migrator.status.select { |_, applied| !applied }

      if pending.empty?
        style.success("No pending migrations.")
        return ACON::Command::Status::SUCCESS
      end

      style.text("Found #{pending.size} pending migration(s)")
      migrator.migrate
      style.success("Migration complete!")

      ACON::Command::Status::SUCCESS
    rescue ex
      msg = error_message(ex)
      if style
        style.error("Migration failed: #{msg}")
      else
        output.puts("<error>Migration failed: #{msg}</error>")
      end
      ACON::Command::Status::FAILURE
    end
  end

  # Roll back the last database migration.
  @[ADI::Register]
  @[ACONA::AsCommand("db:rollback", description: "Roll back the last database migration")]
  class RollbackCommand < DatabaseCommand
    protected def configure : Nil
      super
      self.option("steps", "s", :required, "Number of migrations to rollback (default: 1)")
    end

    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      initialize_options(input)
      style = ACON::Style::Athena.new(input, output)

      steps = input.option("steps", String?).try(&.to_i) || 1

      style.title("Rolling Back Migration")

      migrator = Ralph::Migrations::Migrator.new(database, @migrations_dir)
      rolled_back = migrator.rollback(steps)

      style.success("Rolled back #{rolled_back} migration(s)")

      ACON::Command::Status::SUCCESS
    rescue ex
      msg = error_message(ex)
      if style
        style.error("Rollback failed: #{msg}")
      else
        output.puts("<error>Rollback failed: #{msg}</error>")
      end
      ACON::Command::Status::FAILURE
    end
  end

  # Show migration status.
  @[ADI::Register]
  @[ACONA::AsCommand("db:status", description: "Show database migration status")]
  class StatusCommand < DatabaseCommand
    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      initialize_options(input)
      style = ACON::Style::Athena.new(input, output)

      style.title("Migration Status")

      migrator = Ralph::Migrations::Migrator.new(database, @migrations_dir)
      status = migrator.status

      if status.empty?
        style.warning("No migrations found.")
        return ACON::Command::Status::SUCCESS
      end

      rows = status.map do |version, applied|
        status_str = applied ? "<fg=green>UP</>" : "<fg=yellow>DOWN</>"
        [status_str, version]
      end

      style.table(["Status", "Migration"], rows)

      pending = status.count { |_, applied| !applied }
      if pending > 0
        style.warning("#{pending} pending migration(s)")
      else
        style.success("All migrations are up to date")
      end

      ACON::Command::Status::SUCCESS
    rescue ex
      msg = error_message(ex)
      if style
        style.error("Failed to get status: #{msg}")
      else
        output.puts("<error>Failed to get status: #{msg}</error>")
      end
      ACON::Command::Status::FAILURE
    end
  end

  # Show current migration version.
  @[ADI::Register]
  @[ACONA::AsCommand("db:version", description: "Show current database migration version")]
  class VersionCommand < DatabaseCommand
    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      initialize_options(input)
      style = ACON::Style::Athena.new(input, output)

      migrator = Ralph::Migrations::Migrator.new(database, @migrations_dir)

      if v = migrator.current_version
        style.success("Current version: #{v}")
      else
        style.warning("No migrations have been run")
      end

      ACON::Command::Status::SUCCESS
    rescue ex
      msg = error_message(ex)
      if style
        style.error("Failed to get version: #{msg}")
      else
        output.puts("<error>Failed to get version: #{msg}</error>")
      end
      ACON::Command::Status::FAILURE
    end
  end

  # Create the database.
  @[ADI::Register]
  @[ACONA::AsCommand("db:create", description: "Create the database")]
  class CreateCommand < DatabaseCommand
    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      initialize_options(input)
      style = ACON::Style::Athena.new(input, output)

      url = database_url

      style.title("Creating Database")

      {% begin %}
        case url
        {% if @top_level.has_constant?("Ralph") && Ralph::Database.has_constant?("SqliteBackend") %}
        when /^sqlite3?:\/\/(.+)$/
          path = $1
          FileUtils.mkdir_p(File.dirname(path))
          style.success("Created database: #{path}")
        {% end %}
        {% if @top_level.has_constant?("Ralph") && Ralph::Database.has_constant?("PostgresBackend") %}
        when /^postgres(?:ql)?:\/\//
          db_name = extract_postgres_db_name(url)
          base_url = url.sub(/\/[^\/]+(\?.*)?$/, "/postgres\\1")

          style.text("Creating PostgreSQL database: #{db_name}")

          begin
            temp_db = DB.open(base_url)
            temp_db.exec("CREATE DATABASE \"#{db_name}\"")
            temp_db.close
            style.success("Created database: #{db_name}")
          rescue ex : PQ::PQError
            if ex.message.try(&.includes?("already exists"))
              style.warning("Database already exists: #{db_name}")
            else
              style.error("Error creating database: #{ex.message || ex.class.name}")
              return ACON::Command::Status::FAILURE
            end
          end
        {% end %}
        else
          style.error("Database creation not implemented for: #{url}")
          return ACON::Command::Status::FAILURE
        end
      {% end %}

      ACON::Command::Status::SUCCESS
    end
  end

  # Drop the database.
  @[ADI::Register]
  @[ACONA::AsCommand("db:drop", description: "Drop the database")]
  class DropCommand < DatabaseCommand
    protected def configure : Nil
      super
      self.option("force", "f", :none, "Skip confirmation prompt")
    end

    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      initialize_options(input)
      style = ACON::Style::Athena.new(input, output)

      url = database_url
      force = input.option("force", Bool)

      unless force
        style.caution("This will permanently delete all data!")
        unless style.confirm("Are you sure you want to drop the database?", false)
          style.text("Aborted.")
          return ACON::Command::Status::SUCCESS
        end
      end

      style.title("Dropping Database")

      {% begin %}
        case url
        {% if @top_level.has_constant?("Ralph") && Ralph::Database.has_constant?("SqliteBackend") %}
        when /^sqlite3?:\/\/(.+)$/
          path = $1
          if File.exists?(path)
            File.delete(path)
            style.success("Dropped database: #{path}")
          else
            style.warning("Database does not exist: #{path}")
          end
        {% end %}
        {% if @top_level.has_constant?("Ralph") && Ralph::Database.has_constant?("PostgresBackend") %}
        when /^postgres(?:ql)?:\/\//
          db_name = extract_postgres_db_name(url)
          base_url = url.sub(/\/[^\/]+(\?.*)?$/, "/postgres\\1")

          style.text("Dropping PostgreSQL database: #{db_name}")

          begin
            temp_db = DB.open(base_url)
            # Terminate existing connections first
            temp_db.exec(<<-SQL)
              SELECT pg_terminate_backend(pg_stat_activity.pid)
              FROM pg_stat_activity
              WHERE pg_stat_activity.datname = '#{db_name}'
              AND pid <> pg_backend_pid()
            SQL
            temp_db.exec("DROP DATABASE IF EXISTS \"#{db_name}\"")
            temp_db.close
            style.success("Dropped database: #{db_name}")
          rescue ex
            style.error("Error dropping database: #{ex.message || ex.class.name}")
            return ACON::Command::Status::FAILURE
          end
        {% end %}
        else
          style.error("Database dropping not implemented for: #{url}")
          return ACON::Command::Status::FAILURE
        end
      {% end %}

      ACON::Command::Status::SUCCESS
    end
  end

  # Show connection pool status.
  @[ADI::Register]
  @[ACONA::AsCommand("db:pool", description: "Show database connection pool status")]
  class PoolCommand < DatabaseCommand
    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      initialize_options(input)
      style = ACON::Style::Athena.new(input, output)

      db = database

      style.title("Connection Pool Status")

      # Configuration
      settings = Ralph.settings
      style.section("Configuration")
      style.table(["Setting", "Value"], [
        ["Initial pool size", settings.initial_pool_size.to_s],
        ["Max pool size", settings.max_pool_size == 0 ? "unlimited" : settings.max_pool_size.to_s],
        ["Max idle pool size", settings.max_idle_pool_size.to_s],
        ["Checkout timeout", "#{settings.checkout_timeout}s"],
        ["Retry attempts", settings.retry_attempts.to_s],
        ["Retry delay", "#{settings.retry_delay}s"],
      ])

      # Runtime statistics
      stats = db.pool_stats
      style.section("Runtime Statistics")
      style.table(["Metric", "Value"], [
        ["Open connections", stats.open_connections.to_s],
        ["Idle connections", stats.idle_connections.to_s],
        ["In-flight connections", stats.in_flight_connections.to_s],
        ["Max connections", stats.max_connections == 0 ? "unlimited" : stats.max_connections.to_s],
      ])

      # Utilization
      if stats.max_connections > 0
        utilization = (stats.in_flight_connections.to_f / stats.max_connections * 100).round(1)
        style.text("Pool utilization: #{utilization}%")
      end

      # Health check
      style.section("Health Check")
      healthy = db.pool_healthy?
      if healthy
        style.success("Status: OK")
      else
        style.error("Status: FAILED")
      end

      # Validation warnings
      warnings = settings.validate_pool_settings
      if warnings.any?
        style.section("Warnings")
        warnings.each { |w| style.warning(w) }
      end

      # Backend info
      style.section("Backend")
      style.table(["Property", "Value"], [
        ["Dialect", db.dialect.to_s],
        ["Closed", db.closed?.to_s],
      ])

      ACON::Command::Status::SUCCESS
    rescue ex
      msg = error_message(ex)
      if style
        style.error("Failed to get pool status: #{msg}")
      else
        output.puts("<error>Failed to get pool status: #{msg}</error>")
      end
      ACON::Command::Status::FAILURE
    end
  end

  # Generate models from database schema.
  @[ADI::Register]
  @[ACONA::AsCommand("db:pull", description: "Generate models from database schema")]
  class PullCommand < DatabaseCommand
    protected def configure : Nil
      super
      self
        .option("tables", "t", :required, "Comma-separated list of tables to pull")
        .option("skip", nil, :required, "Comma-separated list of tables to skip")
        .option("overwrite", nil, :none, "Overwrite existing model files")
        .option("dry-run", nil, :none, "Preview changes without writing files")
    end

    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      initialize_options(input)
      style = ACON::Style::Athena.new(input, output)

      tables = input.option("tables", String?).try(&.split(",").map(&.strip))
      skip_tables = input.option("skip", String?).try(&.split(",").map(&.strip)) || [] of String
      overwrite = input.option("overwrite", Bool)
      dry_run = input.option("dry-run", Bool)

      style.title("Pulling Schema from Database")

      puller = Ralph::Cli::SchemaPuller.new(
        db: database,
        output_dir: @models_dir,
        tables: tables,
        skip_tables: skip_tables,
        overwrite: overwrite,
        output: STDOUT
      )

      if dry_run
        style.text("Dry run - previewing changes:")
        puller.preview
      else
        puller.run
        style.success("Schema pull complete!")
      end

      ACON::Command::Status::SUCCESS
    rescue ex
      msg = error_message(ex)
      if style
        style.error("Schema pull failed: #{msg}")
      else
        output.puts("<error>Schema pull failed: #{msg}</error>")
      end
      ACON::Command::Status::FAILURE
    end
  end

  # Generate migration from model diff.
  @[ADI::Register]
  @[ACONA::AsCommand("db:generate", description: "Generate migration from model changes")]
  class GenerateCommand < DatabaseCommand
    protected def configure : Nil
      super
      self
        .option("name", "N", :required, "Migration name (default: auto_migration)")
        .option("skip", nil, :required, "Comma-separated list of tables to skip")
        .option("dry-run", nil, :none, "Preview changes without generating migration")
    end

    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      initialize_options(input)
      style = ACON::Style::Athena.new(input, output)

      name = input.option("name", String?) || "auto_migration"
      skip_tables = input.option("skip", String?).try(&.split(",").map(&.strip)) || [] of String
      dry_run = input.option("dry-run", Bool)

      style.title("Generating Migration from Model Changes")

      unless skip_tables.empty?
        style.text("Skipping tables: #{skip_tables.join(", ")}")
      end

      # Extract model schemas
      style.text("Analyzing models...")
      model_schemas = Ralph::Schema::ModelSchemaExtractor.extract_all

      if model_schemas.empty?
        style.warning("No models found. Make sure your models inherit from Ralph::Model.")
        return ACON::Command::Status::SUCCESS
      end

      style.text("Found #{model_schemas.size} model(s)")

      # Introspect database schema
      style.text("Introspecting database...")
      db = database

      # Check for pending migrations - user should run them first
      migrator = Ralph::Migrations::Migrator.new(db, @migrations_dir)
      pending = migrator.pending_migrations
      unless pending.empty?
        style.error("There are #{pending.size} pending migration(s). Run `db:migrate` first.")
        style.text("Pending migrations:")
        pending.each do |migration|
          style.text("  - #{migration.version}")
        end
        style.text("")
        style.text("The database schema must match your migrations before generating new ones.")
        style.text("This ensures the diff is calculated against the actual database state.")
        return ACON::Command::Status::FAILURE
      end

      db_schema = db.introspect_schema
      style.text("Found #{db_schema.tables.size} table(s)")

      # Compare schemas
      comparator = Ralph::Schema::SchemaComparator.new(model_schemas, db_schema, db.dialect, skip_tables)
      diff = comparator.compare

      if diff.empty?
        style.success("No changes detected. Database schema is up to date.")
        return ACON::Command::Status::SUCCESS
      end

      # Display changes
      style.section("Changes Detected")
      diff.changes.each do |change|
        icon = change.destructive? ? "<fg=red>!</>" : "<fg=green>+</>"
        case change.type
        when .create_table?
          style.text("#{icon} CREATE TABLE #{change.table}")
        when .drop_table?
          style.text("#{icon} DROP TABLE #{change.table}")
        when .add_column?
          style.text("#{icon} ADD COLUMN #{change.table}.#{change.column} (#{change.details["type"]})")
        when .remove_column?
          style.text("#{icon} REMOVE COLUMN #{change.table}.#{change.column}")
        when .change_column_type?
          style.text("#{icon} CHANGE TYPE #{change.table}.#{change.column}: #{change.details["from"]} -> #{change.details["to"]}")
        when .change_column_nullable?
          style.text("#{icon} CHANGE NULL #{change.table}.#{change.column}: #{change.details["from"]} -> #{change.details["to"]}")
        when .add_foreign_key?
          style.text("#{icon} ADD FK #{change.table}.#{change.column} -> #{change.details["to_table"]}")
        when .remove_foreign_key?
          style.text("#{icon} REMOVE FK #{change.table}.#{change.column}")
        end
      end

      # Show warnings
      unless diff.warnings.empty?
        style.section("Warnings")
        diff.warnings.each { |w| style.warning(w) }
      end

      if dry_run
        style.text("Dry run - no files generated")
        return ACON::Command::Status::SUCCESS
      end

      # Generate SQL migration
      generator = Ralph::Schema::SqlMigrationGenerator.new(
        diff: diff,
        name: name,
        output_dir: @migrations_dir,
        dialect: db.dialect,
        model_schemas: model_schemas
      )

      path = generator.generate!
      style.success("Generated: #{path}")

      if diff.has_destructive_changes?
        style.caution("This migration contains destructive changes. Review carefully!")
      end

      ACON::Command::Status::SUCCESS
    rescue ex
      msg = error_message(ex)
      if style
        style.error("Migration generation failed: #{msg}")
      else
        output.puts("<error>Migration generation failed: #{msg}</error>")
      end
      ACON::Command::Status::FAILURE
    end
  end

  # Seed the database.
  @[ADI::Register]
  @[ACONA::AsCommand("db:seed", description: "Load the database seed file")]
  class SeedCommand < DatabaseCommand
    protected def configure : Nil
      super
      self.option("file", "f", :required, "Seed file path (default: ./db/seeds.cr)")
    end

    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      initialize_options(input)
      style = ACON::Style::Athena.new(input, output)

      seed_file = input.option("file", String?) || "./db/seeds.cr"

      unless File.exists?(seed_file)
        style.error("No seed file found at #{seed_file}")
        style.text("Create one first with:")
        style.listing([
          "# #{seed_file}",
          "Ralph::Database::Seeder.run do",
          "  # Your seed code here",
          "end",
        ])
        return ACON::Command::Status::FAILURE
      end

      style.title("Seeding Database")
      style.text("Loading seed file: #{seed_file}")

      status = Process.run("crystal", ["run", seed_file], output: STDOUT, error: STDERR)

      if status.success?
        style.success("Database seeded successfully!")
        ACON::Command::Status::SUCCESS
      else
        style.error("Error running seed file")
        ACON::Command::Status::FAILURE
      end
    end
  end

  # Reset the database (drop, create, migrate, seed).
  @[ADI::Register]
  @[ACONA::AsCommand("db:reset", description: "Drop, create, migrate, and seed the database")]
  class ResetCommand < DatabaseCommand
    protected def configure : Nil
      super
      self.option("force", "f", :none, "Skip confirmation prompt")
    end

    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      initialize_options(input)
      style = ACON::Style::Athena.new(input, output)

      force = input.option("force", Bool)

      unless force
        style.caution("This will permanently delete all data and recreate the database!")
        unless style.confirm("Are you sure you want to reset the database?", false)
          style.text("Aborted.")
          return ACON::Command::Status::SUCCESS
        end
      end

      style.title("Resetting Database")

      # Drop
      style.section("Dropping database...")
      drop_cmd = DropCommand.new
      drop_result = drop_cmd.run(ACON::Input::Hash.new({"--force" => true}), output)
      return drop_result unless drop_result.success?

      # Create
      style.section("Creating database...")
      create_cmd = CreateCommand.new
      create_result = create_cmd.run(ACON::Input::Hash.new, output)
      return create_result unless create_result.success?

      # Need to reinitialize Ralph with new connection after recreating DB
      Ralph::Athena.configure(
        database_url: database_url,
        auto_migrate: false
      )

      # Migrate
      style.section("Running migrations...")
      migrate_cmd = MigrateCommand.new
      migrate_result = migrate_cmd.run(ACON::Input::Hash.new({"-m" => @migrations_dir}), output)
      return migrate_result unless migrate_result.success?

      # Seed
      style.section("Seeding database...")
      seed_cmd = SeedCommand.new
      seed_result = seed_cmd.run(ACON::Input::Hash.new, output)
      # Seed failure is not critical
      if !seed_result.success?
        style.warning("Seeding skipped or failed")
      end

      style.success("Database reset complete!")

      ACON::Command::Status::SUCCESS
    end
  end

  # Setup the database (create and migrate).
  @[ADI::Register]
  @[ACONA::AsCommand("db:setup", description: "Create database and run migrations")]
  class SetupCommand < DatabaseCommand
    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      initialize_options(input)
      style = ACON::Style::Athena.new(input, output)

      style.title("Setting Up Database")

      # Create
      style.section("Creating database...")
      create_cmd = CreateCommand.new
      create_result = create_cmd.run(ACON::Input::Hash.new, output)
      return create_result unless create_result.success?

      # Migrate
      style.section("Running migrations...")
      migrate_cmd = MigrateCommand.new
      migrate_result = migrate_cmd.run(ACON::Input::Hash.new({"-m" => @migrations_dir}), output)
      return migrate_result unless migrate_result.success?

      style.success("Database setup complete!")

      ACON::Command::Status::SUCCESS
    end
  end

  # Generate a new migration file.
  @[ADI::Register]
  @[ACONA::AsCommand("generate:migration", description: "Create a new empty migration file", aliases: ["g:migration"])]
  class GenerateMigrationCommand < DatabaseCommand
    protected def configure : Nil
      super
      self.argument("name", :required, "Name of the migration")
    end

    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      initialize_options(input)
      style = ACON::Style::Athena.new(input, output)

      name = input.argument("name", String)

      style.title("Creating Migration")

      path = Ralph::Migrations::Migrator.create(name, @migrations_dir)
      style.success("Created: #{path}")

      ACON::Command::Status::SUCCESS
    rescue ex
      msg = error_message(ex)
      if style
        style.error("Failed to create migration: #{msg}")
      else
        output.puts("<error>Failed to create migration: #{msg}</error>")
      end
      ACON::Command::Status::FAILURE
    end
  end

  # Generate a new model with migration.
  @[ADI::Register]
  @[ACONA::AsCommand("generate:model", description: "Generate a model with migration", aliases: ["g:model"])]
  class GenerateModelCommand < DatabaseCommand
    protected def configure : Nil
      super
      self
        .argument("name", :required, "Name of the model")
        .argument("fields", :is_array, "Field definitions (name:type ...)")
    end

    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      initialize_options(input)
      style = ACON::Style::Athena.new(input, output)

      name = input.argument("name", String)
      fields = input.argument("fields", Array(String))

      style.title("Generating Model: #{name}")

      generator = Ralph::Cli::Generators::ModelGenerator.new(name, fields, @models_dir, @migrations_dir)
      generator.run

      style.success("Model generated successfully!")

      ACON::Command::Status::SUCCESS
    rescue ex
      msg = error_message(ex)
      if style
        style.error("Failed to generate model: #{msg}")
      else
        output.puts("<error>Failed to generate model: #{msg}</error>")
      end
      ACON::Command::Status::FAILURE
    end
  end
end

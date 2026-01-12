require "option_parser"
require "file_utils"
require "db"

module Ralph
  module Cli
    # CLI runner for Ralph
    #
    # Provides command-line interface for database operations:
    # - Creating migrations
    # - Running migrations
    # - Rolling back migrations
    # - Checking migration status
    class Runner
      @database_url : String?
      @migrations_dir : String
      @models_dir : String
      @environment : String = ENV["RALPH_ENV"]? || "development"
      @output : IO

      def initialize(
        @output : IO = STDOUT,
        @migrations_dir : String = "./db/migrations",
        @models_dir : String = "./src/models",
      )
      end

      # Run the CLI with the given arguments
      def run(args = ARGV)
        if args.empty?
          print_help
          exit 1
        end

        command = args[0]

        # Handle colon syntax (db:migrate) by splitting into command and subcommand
        if command.includes?(":")
          parts = command.split(":", 2)
          command = parts[0]
          # Prepend subcommand to remaining args
          args = [parts[1]] + args[1..]
        else
          args = args[1..]
        end

        case command
        when "version"
          print_version
        when "help", "--help", "-h"
          print_help
        when "db"
          handle_db_command(args)
        when "generate", "g"
          handle_generate_command(args)
        else
          @output.puts "Unknown command: #{command}"
          print_help
          exit 1
        end
      end

      private def print_version
        @output.puts "Ralph v#{Ralph::VERSION}"
        @output.puts "Crystal ORM for delightful database interactions"
      end

      private def print_help
        @output.puts <<-HELP
        Ralph v#{Ralph::VERSION} - Crystal ORM

        Usage:
          ./ralph [command] [options]

        Setup:
          Create a ralph.cr file in your project root:

            require "ralph"
            require "ralph/backends/sqlite"  # and/or postgres

            Ralph::Cli::Runner.new.run

          Then run with: crystal run ./ralph.cr -- [command]
          Or compile once: crystal build ./ralph.cr -o ralph && ./ralph [command]

        Commands:
          db              Database commands
          generate, g     Generator commands
          version         Show version
          help            Show this help

        Database commands:
          db:create                    Create the database
          db:drop                      Drop the database
          db:migrate                   Run pending migrations
          db:rollback                  Roll back the last migration
          db:rollback:all              Roll back all migrations
          db:status                    Show migration status
          db:version                   Show current migration version
          db:seed                      Load the seed file
          db:reset                     Drop, create, migrate, and seed
          db:setup                     Create database and run migrations
          db:pool                      Show connection pool status
          db:pull                      Generate models from database schema
          db:generate                  Generate migration from model diff
          db:check                     Validate model schemas against database

        Generator commands:
          g:migration NAME             Create a new SQL migration file
          g:model NAME                 Generate a model with migration

        Options:
          -e, --env ENV          Environment (default: development)
          -d, --database URL     Database URL (sqlite3:// or postgres://)
          -m, --migrations DIR   Migrations directory (default: ./db/migrations)
          --models DIR           Models directory (default: ./src/models)
          -h, --help             Show help

        Environment variables:
          DATABASE_URL           Primary database URL (any supported backend)
          POSTGRES_URL           PostgreSQL connection URL
          SQLITE_URL             SQLite connection URL
          RALPH_ENV              Environment name (default: development)

        Supported database URLs:
          sqlite3://./path/to/db.sqlite3
          postgres://user:pass@host:port/dbname
          postgres://user@host/dbname?host=/var/run/postgresql

        Migration File Format:
          Migrations are plain SQL files with special comment markers:

            -- +migrate Up
            CREATE TABLE users (...);

            -- +migrate Down
            DROP TABLE IF EXISTS users;

        Examples:
          ./ralph db:migrate
          ./ralph db:seed
          ./ralph g:migration create_users
          ./ralph g:model User name:string email:string
          ./ralph db:pull                           # Pull all tables
          ./ralph db:pull --tables=users,posts      # Pull specific tables
          ./ralph db:rollback                       # Rollback last migration
          ./ralph db:rollback --steps=3             # Rollback 3 migrations
        HELP
      end

      private def handle_db_command(args : Array(String))
        if args.empty?
          @output.puts "Error: db command requires a subcommand"
          @output.puts "Available subcommands: create, drop, migrate, rollback, status, version, seed, reset, setup, pool, pull, generate"
          exit 1
        end

        subcommand = args[0]

        # Parse options
        parse_options(args[1..])

        # Commands that don't need an existing database connection
        case subcommand
        when "create"
          create_database
          return
        when "drop"
          drop_database
          return
        end

        # All other commands need a database connection
        db = initialize_database

        case subcommand
        when "migrate"
          migrate(db)
        when "rollback"
          rollback(db, args[1..])
        when "rollback:all"
          rollback_all(db)
        when "status"
          status(db)
        when "version"
          version(db)
        when "seed"
          seed(db)
        when "reset"
          reset_database(db)
        when "setup"
          setup_database
        when "pool"
          pool_status(db)
        when "pull"
          pull_schema(db, args[1..])
        when "generate"
          generate_migration_from_diff(db, args[1..])
        when "check"
          check_schema(db)
        else
          @output.puts "Unknown db command: #{subcommand}"
          exit 1
        end
      end

      private def handle_generate_command(args : Array(String))
        if args.empty?
          @output.puts "Error: generate command requires a subcommand"
          @output.puts "Available subcommands: migration, model"
          exit 1
        end

        subcommand = args[0]
        remaining_args = args[1..]

        # Parse options for generate commands (after the subcommand)
        name : String? = nil
        fields = [] of String

        # Separate name/fields from flags
        non_flag_args = [] of String
        i = 0
        while i < remaining_args.size
          arg = remaining_args[i]
          if arg.starts_with?("-")
            # Handle flags
            case arg
            when "-m", "--migrations"
              i += 1
              @migrations_dir = remaining_args[i] if i < remaining_args.size
            when "--models"
              i += 1
              @models_dir = remaining_args[i] if i < remaining_args.size
            end
          else
            non_flag_args << arg
          end
          i += 1
        end

        case subcommand
        when "migration", "m"
          if non_flag_args.empty?
            @output.puts "Error: migration name required"
            @output.puts "Usage: ralph g:migration NAME [-m DIR]"
            exit 1
          end
          create_migration(non_flag_args[0])
        when "model"
          if non_flag_args.empty?
            @output.puts "Error: model name required"
            @output.puts "Usage: ralph g:model NAME [field:type ...] [-m DIR] [--models DIR]"
            exit 1
          end
          name = non_flag_args[0]
          fields = non_flag_args[1..]
          generate_model(name, fields)
        else
          @output.puts "Unknown generate command: #{subcommand}"
          exit 1
        end
      end

      private def parse_options(args : Array(String))
        OptionParser.parse(args) do |parser|
          parser.banner = "Usage: ralph [command] [options]"
          parser.on("-e ENV", "--env ENV", "Environment") { |e| @environment = e }
          parser.on("-d URL", "--database URL", "Database URL") { |d| @database_url = d }
          parser.on("-m DIR", "--migrations DIR", "Migrations directory") { |m| @migrations_dir = m }
          parser.on("--models DIR", "Models directory") { |m| @models_dir = m }
          parser.on("-h", "--help", "Show help") { @output.puts parser; exit 0 }
          parser.invalid_option do |flag|
            @output.puts "Error: Unknown option: #{flag}"
            @output.puts parser
            exit 1
          end
        end
      end

      private def initialize_database : Database::Backend
        url = @database_url || database_url_for_env

        {% begin %}
          case url
          {% if @top_level.has_constant?("Ralph") &&
                  Ralph::Database.has_constant?("SqliteBackend") %}
          when .starts_with?("sqlite3://"), .starts_with?("sqlite://")
            Database::SqliteBackend.new(url)
          {% end %}
          {% if @top_level.has_constant?("Ralph") &&
                  Ralph::Database.has_constant?("PostgresBackend") %}
          when .starts_with?("postgres://"), .starts_with?("postgresql://")
            Database::PostgresBackend.new(url)
          {% end %}
          else
            supported = [] of String
            {% if @top_level.has_constant?("Ralph") &&
                    Ralph::Database.has_constant?("SqliteBackend") %}
              supported << "sqlite3://"
            {% end %}
            {% if @top_level.has_constant?("Ralph") &&
                    Ralph::Database.has_constant?("PostgresBackend") %}
              supported << "postgres://"
            {% end %}
            raise "Unsupported database URL: #{url}. Supported: #{supported.join(", ")}"
          end
        {% end %}
      end

      private def database_url_for_env : String
        # Check environment variables first (in order of precedence)
        if url = ENV["DATABASE_URL"]?
          return url
        end

        if url = ENV["POSTGRES_URL"]?
          return url
        end

        if url = ENV["SQLITE_URL"]?
          return url
        end

        # Try to load from config file
        config_file = "./config/database.yml"
        if File.exists?(config_file)
          # TODO: Parse YAML config for environment-specific URLs
          # For now, just use environment variables
        end

        # Default to SQLite
        "sqlite3://./db/#{@environment}.sqlite3"
      end

      private def create_database
        url = @database_url || database_url_for_env

        {% begin %}
          case url
          {% if @top_level.has_constant?("Ralph") &&
                  Ralph::Database.has_constant?("SqliteBackend") %}
          when /^sqlite3?:\/\/(.+)$/
            path = $1
            FileUtils.mkdir_p(File.dirname(path))
            @output.puts "Created database: #{path}"
          {% end %}
          {% if @top_level.has_constant?("Ralph") &&
                  Ralph::Database.has_constant?("PostgresBackend") %}
          when /^postgres(?:ql)?:\/\//
            # Extract database name from URL
            db_name = extract_postgres_db_name(url)
            base_url = url.sub(/\/[^\/]+(\?.*)?$/, "/postgres\\1")

            @output.puts "Creating PostgreSQL database: #{db_name}"

            begin
              # Connect to postgres database to create the target database
              temp_db = DB.open(base_url)
              temp_db.exec("CREATE DATABASE \"#{db_name}\"")
              temp_db.close
              @output.puts "Created database: #{db_name}"
            rescue ex : PQ::PQError
              if ex.message.try(&.includes?("already exists"))
                @output.puts "Database already exists: #{db_name}"
              else
                @output.puts "Error creating database: #{ex.message}"
                exit 1
              end
            end
          {% end %}
          else
            @output.puts "Database creation not implemented for: #{url}"
            exit 1
          end
        {% end %}
      end

      private def drop_database
        url = @database_url || database_url_for_env

        {% begin %}
          case url
          {% if @top_level.has_constant?("Ralph") &&
                  Ralph::Database.has_constant?("SqliteBackend") %}
          when /^sqlite3?:\/\/(.+)$/
            path = $1
            if File.exists?(path)
              File.delete(path)
              @output.puts "Dropped database: #{path}"
            else
              @output.puts "Database does not exist: #{path}"
            end
          {% end %}
          {% if @top_level.has_constant?("Ralph") &&
                  Ralph::Database.has_constant?("PostgresBackend") %}
          when /^postgres(?:ql)?:\/\//
            # Extract database name from URL
            db_name = extract_postgres_db_name(url)
            base_url = url.sub(/\/[^\/]+(\?.*)?$/, "/postgres\\1")

            @output.puts "Dropping PostgreSQL database: #{db_name}"

            begin
              # Connect to postgres database to drop the target database
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
              @output.puts "Dropped database: #{db_name}"
            rescue ex
              @output.puts "Error dropping database: #{ex.message}"
              exit 1
            end
          {% end %}
          else
            @output.puts "Database dropping not implemented for: #{url}"
            exit 1
          end
        {% end %}
      end

      private def migrate(db)
        migrator = Migrations::Migrator.new(db, @migrations_dir, @output)
        migrator.migrate
      end

      private def rollback(db, args : Array(String))
        steps = 1

        # Parse --steps option
        args.each_with_index do |arg, i|
          if arg == "--steps" && i + 1 < args.size
            steps = args[i + 1].to_i
          elsif arg.starts_with?("--steps=")
            steps = arg.split("=", 2).last.to_i
          end
        end

        migrator = Migrations::Migrator.new(db, @migrations_dir, @output)
        migrator.rollback(steps)
      end

      private def rollback_all(db)
        migrator = Migrations::Migrator.new(db, @migrations_dir, @output)
        migrator.rollback_all
      end

      private def status(db)
        migrator = Migrations::Migrator.new(db, @migrations_dir, @output)
        status = migrator.status

        @output.puts "Migration status:"
        @output.puts "Status".ljust(12) + "Migration ID"
        @output.puts "-" * 50

        status.each do |version, applied|
          status_str = applied ? "[   UP    ]" : "[  DOWN   ]"
          @output.puts "#{status_str} #{version}"
        end
      end

      private def version(db)
        migrator = Migrations::Migrator.new(db, @migrations_dir, @output)
        if v = migrator.current_version
          @output.puts "Current version: #{v}"
        else
          @output.puts "No migrations have been run"
        end
      end

      # Show connection pool status and statistics
      private def pool_status(db)
        @output.puts "Connection Pool Status"
        @output.puts "=" * 50
        @output.puts ""

        # Configuration
        settings = Ralph.settings
        @output.puts "Configuration:"
        @output.puts "  Initial pool size:    #{settings.initial_pool_size}"
        @output.puts "  Max pool size:        #{settings.max_pool_size == 0 ? "unlimited" : settings.max_pool_size}"
        @output.puts "  Max idle pool size:   #{settings.max_idle_pool_size}"
        @output.puts "  Checkout timeout:     #{settings.checkout_timeout}s"
        @output.puts "  Retry attempts:       #{settings.retry_attempts}"
        @output.puts "  Retry delay:          #{settings.retry_delay}s"
        @output.puts ""

        # Runtime statistics
        stats = db.pool_stats
        @output.puts "Runtime Statistics:"
        @output.puts "  Open connections:     #{stats.open_connections}"
        @output.puts "  Idle connections:     #{stats.idle_connections}"
        @output.puts "  In-flight connections: #{stats.in_flight_connections}"
        @output.puts "  Max connections:      #{stats.max_connections == 0 ? "unlimited" : stats.max_connections}"
        @output.puts ""

        # Calculate utilization
        if stats.max_connections > 0
          utilization = (stats.in_flight_connections.to_f / stats.max_connections * 100).round(1)
          @output.puts "  Pool utilization:     #{utilization}%"
        end
        @output.puts ""

        # Health check
        @output.puts "Health Check:"
        healthy = db.pool_healthy?
        if healthy
          @output.puts "  Status:               OK"
        else
          @output.puts "  Status:               FAILED"
        end
        @output.puts ""

        # Validation warnings
        warnings = settings.validate_pool_settings
        if warnings.any?
          @output.puts "Warnings:"
          warnings.each do |warning|
            @output.puts "  ⚠ #{warning}"
          end
          @output.puts ""
        end

        # Backend info
        @output.puts "Backend:"
        @output.puts "  Dialect:              #{db.dialect}"
        @output.puts "  Closed:               #{db.closed?}"
      end

      private def create_migration(name : String)
        filepath = Migrations::Migrator.create(name, @migrations_dir)
        @output.puts "Created migration: #{filepath}"
      end

      # Seed the database with data from db/seeds.cr
      private def seed(db)
        seed_file = "./db/seeds.cr"

        unless File.exists?(seed_file)
          @output.puts "No seed file found at #{seed_file}"
          @output.puts "Create one first with:"
          @output.puts "  # db/seeds.cr"
          @output.puts "  Ralph::Database::Seeder.run do"
          @output.puts "    # Your seed code here"
          @output.puts "  end"
          exit 1
        end

        @output.puts "Loading seed file..."

        # Load and execute the seed file
        status = Process.run("crystal", ["run", seed_file], output: @output, error: @output)

        if status.success?
          @output.puts "Seeded database successfully"
        else
          @output.puts "Error running seed file"
          exit 1
        end
      end

      # Reset the database (drop, create, migrate, seed)
      private def reset_database(db)
        @output.puts "Resetting database..."

        # Close existing connection before dropping
        db.close

        # Drop existing database
        drop_database

        # Create database
        create_database

        # Re-initialize database connection after recreation
        db = initialize_database

        # Run migrations
        @output.puts "Running migrations..."
        migrate(db)

        # Run seeds
        seed(db)

        @output.puts "Database reset complete"
      end

      # Setup the database (create and migrate)
      private def setup_database
        @output.puts "Setting up database..."

        # Create database
        create_database

        # Initialize database connection
        db = initialize_database

        # Run migrations
        @output.puts "Running migrations..."
        migrate(db)

        @output.puts "Database setup complete"
      end

      # Generate a model with migration
      private def generate_model(name : String, fields : Array(String))
        generator = Generators::ModelGenerator.new(name, fields, @models_dir, @migrations_dir)
        generator.run
      end

      # Pull models from database schema (db:pull command)
      private def pull_schema(db, args : Array(String))
        tables : Array(String)? = nil
        skip_tables = [] of String
        overwrite = false
        dry_run = false

        # Parse options
        i = 0
        while i < args.size
          arg = args[i]
          case arg
          when "--tables"
            i += 1
            if i < args.size
              tables = args[i].split(",").map(&.strip)
            end
          when .starts_with?("--tables=")
            tables = arg.split("=", 2).last.split(",").map(&.strip)
          when "--skip"
            i += 1
            if i < args.size
              skip_tables = args[i].split(",").map(&.strip)
            end
          when .starts_with?("--skip=")
            skip_tables = arg.split("=", 2).last.split(",").map(&.strip)
          when "--overwrite"
            overwrite = true
          when "--dry-run"
            dry_run = true
          when "--models"
            i += 1
            @models_dir = args[i] if i < args.size
          when .starts_with?("--models=")
            @models_dir = arg.split("=", 2).last
          end
          i += 1
        end

        puller = SchemaPuller.new(
          db: db,
          output_dir: @models_dir,
          tables: tables,
          skip_tables: skip_tables,
          overwrite: overwrite,
          output: @output
        )

        if dry_run
          puller.preview
        else
          puller.run
        end
      end

      # Generate migration from model diff (db:generate command)
      private def generate_migration_from_diff(db, args : Array(String))
        name = "auto_migration"
        dry_run = false

        # Parse options
        i = 0
        while i < args.size
          arg = args[i]
          case arg
          when "--name"
            i += 1
            name = args[i] if i < args.size
          when .starts_with?("--name=")
            name = arg.split("=", 2).last
          when "--dry-run"
            dry_run = true
          when "-m", "--migrations"
            i += 1
            @migrations_dir = args[i] if i < args.size
          when .starts_with?("--migrations=")
            @migrations_dir = arg.split("=", 2).last
          end
          i += 1
        end

        # Extract model schemas from registered models
        @output.puts "Analyzing models..."
        model_schemas = Ralph::Schema::ModelSchemaExtractor.extract_all

        if model_schemas.empty?
          @output.puts "No models found. Make sure your models inherit from Ralph::Model."
          return
        end

        @output.puts "Found #{model_schemas.size} model(s)"

        # Introspect database schema
        @output.puts "Introspecting database..."
        db_schema = db.introspect_schema
        @output.puts "Found #{db_schema.tables.size} table(s)"
        @output.puts ""

        # Compare schemas
        comparator = Ralph::Schema::SchemaComparator.new(model_schemas, db_schema, db.dialect)
        diff = comparator.compare

        if diff.empty?
          @output.puts "No changes detected. Database schema is up to date."
          return
        end

        # Display changes
        @output.puts "Changes detected:"
        diff.changes.each do |change|
          icon = change.destructive? ? "⚠️ " : "  "
          case change.type
          when .create_table?
            @output.puts "#{icon}+ CREATE TABLE #{change.table}"
          when .drop_table?
            @output.puts "#{icon}- DROP TABLE #{change.table}"
          when .add_column?
            @output.puts "#{icon}+ ADD COLUMN #{change.table}.#{change.column} (#{change.details["type"]})"
          when .remove_column?
            @output.puts "#{icon}- REMOVE COLUMN #{change.table}.#{change.column}"
          when .change_column_type?
            @output.puts "#{icon}~ CHANGE TYPE #{change.table}.#{change.column}: #{change.details["from"]} -> #{change.details["to"]}"
          when .change_column_nullable?
            @output.puts "#{icon}~ CHANGE NULL #{change.table}.#{change.column}: #{change.details["from"]} -> #{change.details["to"]}"
          when .add_foreign_key?
            @output.puts "#{icon}+ ADD FK #{change.table}.#{change.column} -> #{change.details["to_table"]}"
          when .remove_foreign_key?
            @output.puts "#{icon}- REMOVE FK #{change.table}.#{change.column}"
          end
        end
        @output.puts ""

        # Show warnings
        unless diff.warnings.empty?
          @output.puts "Warnings:"
          diff.warnings.each { |w| @output.puts "  ⚠️  #{w}" }
          @output.puts ""
        end

        if dry_run
          @output.puts "Dry run - no files generated"
          return
        end

        # Generate SQL migration
        generator = Ralph::Schema::SqlMigrationGenerator.new(
          diff: diff,
          name: name,
          output_dir: @migrations_dir,
          dialect: db.dialect
        )

        path = generator.generate!
        @output.puts "Generated: #{path}"

        if diff.has_destructive_changes?
          @output.puts ""
          @output.puts "⚠️  This migration contains destructive changes. Review carefully!"
        end
      end

      # Extract database name from a PostgreSQL URL
      # Examples:
      #   postgres://user:pass@localhost/mydb -> mydb
      #   postgres://localhost/mydb?host=/tmp -> mydb
      #   postgresql://user@host:5432/dbname -> dbname
      private def extract_postgres_db_name(url : String) : String
        # Remove query string first
        url_without_query = url.split("?").first

        # Get everything after the last /
        if match = url_without_query.match(/\/([^\/]+)$/)
          match[1]
        else
          raise "Could not extract database name from URL: #{url}"
        end
      end

      # Check schema (db:check command)
      #
      # Validates model definitions against the actual database schema,
      # reporting any mismatches that could cause runtime errors.
      private def check_schema(db)
        @output.puts "Validating model schemas against database..."
        @output.puts ""

        results = Ralph::Schema::Validator.validate_all

        if results.empty?
          @output.puts "No models found to validate."
          @output.puts "Make sure your models inherit from Ralph::Model and are loaded."
          exit 1
        end

        valid_count = 0
        warning_count = 0
        invalid_count = 0

        results.each do |table_name, result|
          if result.valid?
            valid_count += 1
            if result.warnings.empty?
              @output.puts "✓ #{result.model_name}"
            else
              warning_count += result.warnings.size
              @output.puts "✓ #{result.model_name} (#{result.warnings.size} warnings)"
              result.warnings.each do |warning|
                @output.puts "    ⚠ #{warning}"
              end
            end
          else
            invalid_count += 1
            @output.puts "✗ #{result.model_name}"
            result.errors.each do |error|
              @output.puts "    ✗ #{error}"
            end
            result.warnings.each do |warning|
              @output.puts "    ⚠ #{warning}"
            end
          end
        end

        @output.puts ""
        @output.puts "=" * 50
        @output.puts "Results: #{results.size} models checked"
        @output.puts "  ✓ Valid:    #{valid_count}"
        @output.puts "  ✗ Invalid:  #{invalid_count}"
        @output.puts "  ⚠ Warnings: #{warning_count}"

        if invalid_count > 0
          @output.puts ""
          @output.puts "Schema validation FAILED"
          @output.puts ""
          @output.puts "To fix these issues:"
          @output.puts "  1. Run 'ralph db:pull' to regenerate models from database schema"
          @output.puts "  2. Or manually update your model column definitions to match"
          exit 1
        else
          @output.puts ""
          @output.puts "Schema validation PASSED"
        end
      end
    end
  end
end

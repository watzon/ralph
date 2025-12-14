require "option_parser"
require "file_utils"

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
      @migrations_dir : String = "./db/migrations"
      @environment : String = ENV["RALPH_ENV"]? || "development"
      @output : IO

      def initialize(@output : IO = STDOUT)
      end

      # Run the CLI with the given arguments
      def run(args = ARGV)
        if args.empty?
          print_help
          exit 1
        end

        command = args[0]

        case command
        when "version"
          print_version
        when "help", "--help", "-h"
          print_help
        when "db"
          handle_db_command(args[1..])
        when "generate", "g"
          handle_generate_command(args[1..])
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
          ralph [command] [options]

        Commands:
          db              Database commands
          generate, g     Generator commands
          version         Show version
          help            Show this help

        Database commands:
          ralph db:create                    Create the database
          ralph db:drop                      Drop the database
          ralph db:migrate                   Run pending migrations
          ralph db:rollback                  Roll back the last migration
          ralph db:status                    Show migration status
          ralph db:version                   Show current migration version
          ralph db:seed                      Load the seed file
          ralph db:reset                     Drop, create, migrate, and seed
          ralph db:setup                     Create database and run migrations

        Generator commands:
          ralph g:migration NAME             Create a new migration
          ralph g:model NAME                 Generate a model with migration
          ralph g:scaffold NAME              Generate full CRUD (model, views, etc.)
          ralph generate:migration NAME
          ralph generate:model NAME
          ralph generate:scaffold NAME

        Options:
          -e, --env ENV     Environment (default: development)
          -d, --database URL Database URL
          -m, --migrations DIR  Migrations directory (default: ./db/migrations)
          -h, --help        Show help

        Examples:
          ralph db:migrate
          ralph db:seed
          ralph db:reset
          ralph db:setup
          ralph g:model User name:string email:string
          ralph g:scaffold Post title:string body:text
        HELP
      end

      private def handle_db_command(args : Array(String))
        if args.empty?
          @output.puts "Error: db command requires a subcommand"
          @output.puts "Available subcommands: create, drop, migrate, rollback, status, version, seed, reset, setup"
          exit 1
        end

        subcommand = args[0]

        # Parse options
        parse_options(args[1..])

        # Initialize database
        db = initialize_database

        case subcommand
        when "create"
          create_database
        when "drop"
          drop_database
        when "migrate"
          migrate(db)
        when "rollback"
          rollback(db)
        when "status"
          status(db)
        when "version"
          version(db)
        when "seed"
          seed(db)
        when "reset"
          reset_database(db)
        when "setup"
          setup_database(db)
        else
          @output.puts "Unknown db command: #{subcommand}"
          exit 1
        end
      end

      private def handle_generate_command(args : Array(String))
        if args.empty?
          @output.puts "Error: generate command requires a subcommand"
          @output.puts "Available subcommands: migration, model, scaffold"
          exit 1
        end

        subcommand = args[0]

        case subcommand
        when "migration", "m"
          if args.size < 2
            @output.puts "Error: migration name required"
            @output.puts "Usage: ralph g:migration NAME"
            exit 1
          end
          create_migration(args[1])
        when "model"
          if args.size < 2
            @output.puts "Error: model name required"
            @output.puts "Usage: ralph g:model NAME [field:type ...]"
            exit 1
          end
          generate_model(args[1], args[2..]? || [] of String)
        when "scaffold"
          if args.size < 2
            @output.puts "Error: scaffold name required"
            @output.puts "Usage: ralph g:scaffold NAME [field:type ...]"
            exit 1
          end
          generate_scaffold(args[1], args[2..]? || [] of String)
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

        case url
        when .starts_with?("sqlite3://")
          Database::SqliteBackend.new(url)
        else
          raise "Unsupported database URL: #{url}"
        end
      end

      private def database_url_for_env : String
        # Try to load from config file
        config_file = "./config/database.yml"

        if File.exists?(config_file)
          # Parse YAML config
          # This is a simplified version
          env_url = ENV["DATABASE_URL"]?
          return env_url if env_url
        end

        # Default to SQLite
        "sqlite3://./db/#{@environment}.sqlite3"
      end

      private def create_database
        url = @database_url || database_url_for_env

        case url
        when /^sqlite3:\/\/(.+)$/
          path = $1
          FileUtils.mkdir_p(File.dirname(path))
          @output.puts "Created database: #{path}"
        else
          @output.puts "Database creation not implemented for: #{url}"
          exit 1
        end
      end

      private def drop_database
        url = @database_url || database_url_for_env

        case url
        when /^sqlite3:\/\/(.+)$/
          path = $1
          if File.exists?(path)
            File.delete(path)
            @output.puts "Dropped database: #{path}"
          else
            @output.puts "Database does not exist: #{path}"
          end
        else
          @output.puts "Database dropping not implemented for: #{url}"
          exit 1
        end
      end

      private def migrate(db)
        migrator = Migrations::Migrator.new(db, @migrations_dir)
        migrator.migrate(:up)
        @output.puts "Migration complete"
      end

      private def rollback(db)
        migrator = Migrations::Migrator.new(db, @migrations_dir)
        migrator.rollback
        @output.puts "Rollback complete"
      end

      private def status(db)
        migrator = Migrations::Migrator.new(db, @migrations_dir)
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
        migrator = Migrations::Migrator.new(db, @migrations_dir)
        if v = migrator.current_version
          @output.puts "Current version: #{v}"
        else
          @output.puts "No migrations have been run"
        end
      end

      private def create_migration(name : String)
        Migrations::Migrator.create(name, @migrations_dir)
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

        # Load and execute the seed file using the block form
        success = Process.run("crystal", ["run", seed_file]) do |process|
          # Process is running, wait for completion
          process.wait.success?
        end

        if success
          @output.puts "Seeded database successfully"
        else
          @output.puts "Error running seed file"
          exit 1
        end
      end

      # Reset the database (drop, create, migrate, seed)
      private def reset_database(db)
        @output.puts "Resetting database..."

        # Drop existing database
        url = @database_url || database_url_for_env
        case url
        when /^sqlite3:\/\/(.+)$/
          path = $1
          if File.exists?(path)
            File.delete(path)
            @output.puts "Dropped database: #{path}"
          end
        end

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
      private def setup_database(db)
        @output.puts "Setting up database..."

        # Create database
        create_database

        # Run migrations
        @output.puts "Running migrations..."
        migrate(db)

        @output.puts "Database setup complete"
      end

      # Generate a model with migration
      private def generate_model(name : String, fields : Array(String))
        generator = Generators::ModelGenerator.new(name, fields)
        generator.run
      end

      # Generate a full scaffold
      private def generate_scaffold(name : String, fields : Array(String))
        generator = Generators::ScaffoldGenerator.new(name, fields)
        generator.run
      end
    end
  end
end

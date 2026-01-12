# SQL Migration Runner
#
# Discovers, tracks, and executes SQL migration files from the migrations directory.
# No recompilation required - migrations are read and executed at runtime.
#
# ## Usage
#
# ```
# migrator = Ralph::Migrations::Migrator.new(Ralph.database)
#
# # Run all pending migrations
# migrator.migrate
#
# # Roll back the last migration
# migrator.rollback
#
# # Check status
# migrator.status.each do |version, applied|
#   puts "#{version}: #{applied ? "UP" : "DOWN"}"
# end
# ```
module Ralph
  module Migrations
    class Migrator
      # Default migrations directory
      DEFAULT_MIGRATIONS_DIR = "./db/migrations"

      # The database backend
      getter database : Database::Backend

      # Path to migrations directory
      getter migrations_dir : String

      # Output for status messages
      property output : IO

      def initialize(
        @database : Database::Backend,
        @migrations_dir : String = DEFAULT_MIGRATIONS_DIR,
        @output : IO = STDOUT,
      )
        ensure_schema_migrations_table
      end

      # Run all pending migrations
      #
      # Returns the number of migrations executed.
      def migrate : Int32
        pending = pending_migrations
        count = 0

        pending.each do |migration|
          run_migration(migration, :up)
          count += 1
        end

        if count == 0
          @output.puts "No pending migrations"
        else
          @output.puts "Ran #{count} migration(s)"
        end

        count
      end

      # Roll back the last applied migration
      #
      # Returns true if a migration was rolled back.
      def rollback(steps : Int32 = 1) : Int32
        applied = applied_migrations.reverse
        count = 0

        applied.first(steps).each do |migration|
          run_migration(migration, :down)
          count += 1
        end

        if count == 0
          @output.puts "No migrations to roll back"
        else
          @output.puts "Rolled back #{count} migration(s)"
        end

        count
      end

      # Roll back all migrations
      def rollback_all : Int32
        rollback(applied_versions.size)
      end

      # Get all available migrations (from filesystem)
      def all_migrations : Array(Migration)
        pattern = File.join(@migrations_dir, "*.sql")
        files = Dir.glob(pattern).sort

        files.map do |filepath|
          Migration.from_file(filepath)
        end
      end

      # Get pending migrations (not yet applied)
      def pending_migrations : Array(Migration)
        applied = applied_versions.to_set
        all_migrations.reject { |m| applied.includes?(m.version) }
      end

      # Get applied migrations (in applied order)
      def applied_migrations : Array(Migration)
        applied = applied_versions.to_set
        all_migrations.select { |m| applied.includes?(m.version) }
      end

      # Get all applied migration versions
      def applied_versions : Array(String)
        versions = [] of String
        result = @database.query_all("SELECT version FROM schema_migrations ORDER BY version")
        result.each do
          versions << result.read(String)
        end
        versions
      ensure
        result.try(&.close)
      end

      # Get migration status as version => applied?
      def status : Hash(String, Bool)
        applied = applied_versions.to_set
        all_migrations.each_with_object({} of String => Bool) do |migration, hash|
          hash[migration.version] = applied.includes?(migration.version)
        end
      end

      # Get current (latest applied) version
      def current_version : String?
        applied_versions.last?
      end

      # Create a new migration file
      #
      # Returns the path to the created file.
      def self.create(name : String, dir : String = DEFAULT_MIGRATIONS_DIR) : String
        FileUtils.mkdir_p(dir)

        timestamp = Time.utc.to_s("%Y%m%d%H%M%S")
        snake_name = name.underscore.gsub(/[^a-z0-9_]/, "_")
        filename = "#{timestamp}_#{snake_name}.sql"
        filepath = File.join(dir, filename)

        content = <<-SQL
        -- Migration: #{name}
        -- Created: #{Time.utc}

        -- +migrate Up
        -- Write your UP migration SQL here
        -- Example:
        -- CREATE TABLE users (
        --     id BIGSERIAL PRIMARY KEY,
        --     name VARCHAR(255) NOT NULL,
        --     email VARCHAR(255) NOT NULL UNIQUE,
        --     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        --     updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        -- );

        -- +migrate Down
        -- Write your DOWN migration SQL here (reverses the UP)
        -- Example:
        -- DROP TABLE IF EXISTS users;
        SQL

        File.write(filepath, content)
        filepath
      end

      # Run a single migration in the specified direction
      private def run_migration(migration : Migration, direction : Symbol)
        statements = direction == :up ? migration.up_statements : migration.down_statements

        if statements.empty?
          @output.puts "Warning: No #{direction} statements in #{migration.version}_#{migration.name}"
          return
        end

        @output.puts "#{direction == :up ? "Running" : "Rolling back"}: #{migration.version}_#{migration.name}"

        begin
          if migration.no_transaction?
            # Run without transaction
            execute_statements(migration, statements)
          else
            # Run in transaction
            @database.transaction do
              execute_statements(migration, statements)
            end
          end

          # Update schema_migrations table
          if direction == :up
            record_migration(migration.version)
          else
            remove_migration(migration.version)
          end
        rescue ex
          raise MigrationError.new(
            ex.message || "Unknown error",
            operation: "#{direction} migration",
            table: nil,
            sql: statements.join("\n"),
            backend: @database.dialect,
            cause: ex
          )
        end
      end

      # Execute SQL statements
      private def execute_statements(migration : Migration, statements : Array(String))
        statements.each do |sql|
          @database.execute(sql)
        end
      end

      # Record a migration as applied
      private def record_migration(version : String)
        @database.execute(
          "INSERT INTO schema_migrations (version) VALUES (?)",
          args: [version] of DB::Any
        )
      end

      # Remove a migration record
      private def remove_migration(version : String)
        @database.execute(
          "DELETE FROM schema_migrations WHERE version = ?",
          args: [version] of DB::Any
        )
      end

      # Ensure schema_migrations table exists
      private def ensure_schema_migrations_table
        @database.execute <<-SQL
          CREATE TABLE IF NOT EXISTS schema_migrations (
            version VARCHAR(14) PRIMARY KEY,
            applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        SQL
      end
    end
  end
end

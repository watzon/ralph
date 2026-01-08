module Ralph
  module Migrations
    # Manages database migrations
    #
    # The migrator tracks which migrations have been applied and
    # can run pending migrations or roll back to previous versions.
    class Migrator
      @database : Database::Backend
      @migrations_dir : String

      # Registry of migration classes
      @@migrations = [] of Migration.class

      # Register a migration class
      def self.register(migration : Migration.class)
        @@migrations << migration
      end

      # Get all registered migrations
      def self.migrations : Array(Migration.class)
        @@migrations
      end

      def initialize(@database : Database::Backend, @migrations_dir : String = "./db/migrations")
        ensure_schema_migrations_table
      end

      # Run all pending migrations
      def migrate(direction : Symbol = :up)
        migrations = @@migrations

        migrations.each do |migration_class|
          migration = migration_class.new(@database)

          if direction == :up
            unless applied?(migration_class.version)
              puts "Running migration: #{migration_class} (#{migration_class.version})"
              migration.up
              record_migration(migration_class.version)
            end
          else
            if applied?(migration_class.version)
              puts "Rolling back migration: #{migration_class} (#{migration_class.version})"
              migration.down
              remove_migration(migration_class.version)
            end
          end
        end
      end

      # Roll back the last migration
      def rollback
        migrations = @@migrations.reverse
        rolled_back = false

        migrations.each do |migration_class|
          migration = migration_class.new(@database)

          if applied?(migration_class.version)
            puts "Rolling back migration: #{migration_class} (#{migration_class.version})"
            migration.down
            remove_migration(migration_class.version)
            rolled_back = true
            break
          end
        end

        unless rolled_back
          puts "No migrations to roll back"
        end
      end

      # Get the current migration version
      def current_version : String?
        result = @database.query_one("SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1")
        return nil unless result

        # query_one already called move_next, so we can read directly
        version = result.read(String)
        result.close
        version
      rescue
        result.close if result
        nil
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
        result.close if result
      end

      # Get migration status
      def status : Hash(String, Bool)
        applied = applied_versions

        @@migrations.each_with_object({} of String => Bool) do |migration_class, status|
          version = migration_class.version
          status[version] = applied.includes?(version)
        end
      end

      # Create a new migration file
      def self.create(name : String, dir : String = "./db/migrations")
        timestamp = Time.utc.to_s("%Y%m%d%H%M%S")
        filename = "#{timestamp}_#{name.underscore}.cr"
        filepath = File.join(dir, filename)

        FileUtils.mkdir_p(dir)

        # Convert name to CamelCase
        class_name = name.split('_').map(&.capitalize).join

        content = <<-MIGRATION
        require "ralph"

        # Migration: #{name}
        # Created: #{Time.utc}
        class #{class_name}_#{timestamp} < Ralph::Migrations::Migration
          migration_version #{timestamp}

          def up : Nil
            # Add your migration code here
            create_table :table_name do |t|
              t.primary_key
              t.string :name
              t.timestamps
            end
          end

          def down : Nil
            # Add your rollback code here
            drop_table :table_name
          end
        end

        # Register the migration
        Ralph::Migrations::Migrator.register(#{class_name}_#{timestamp})
        MIGRATION

        File.write(filepath, content)
        puts "Created migration: #{filepath}"
      end

      # Check if a migration has been applied
      private def applied?(version : String) : Bool
        result = @database.query_one("SELECT 1 FROM schema_migrations WHERE version = ? LIMIT 1", args: [version] of DB::Any)
        found = !!result
        result.close if result
        found
      rescue
        false
      end

      # Record a migration as applied
      private def record_migration(version : String)
        @database.execute("INSERT INTO schema_migrations (version) VALUES (?)", args: [version] of DB::Any)
      end

      # Remove a migration record
      private def remove_migration(version : String)
        @database.execute("DELETE FROM schema_migrations WHERE version = ?", args: [version] of DB::Any)
      end

      # Ensure the schema_migrations table exists
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

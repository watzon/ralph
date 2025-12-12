module Ralph
  module Migrations
    # Abstract base class for migrations
    #
    # Migration files should inherit from this class and implement
    # the `up` and `down` methods.
    #
    # Example:
    # ```
    # class CreateUsersTable < Ralph::Migrations::Migration
    #   def up
    #     create_table :users do |t|
    #       t.column :id, :integer, primary: true
    #       t.column :name, :string, size: 255
    #       t.column :email, :string, size: 255
    #       t.column :created_at, :timestamp
    #       t.timestamps
    #     end
    #   end
    #
    #   def down
    #     drop_table :users
    #   end
    # end
    # ```
    abstract class Migration
      getter database : Database::Backend

      def initialize(@database : Database::Backend)
      end

      # Apply the migration
      abstract def up : Nil

      # Rollback the migration
      abstract def down : Nil

      # Get the migration version number
      #
      # Subclasses should override this
      def self.version : String
        "0"
      end

      # Macro to set the migration version
      macro migration_version(num)
        def self.version : String
          \{{num.stringify}}
        end
      end

      # Create a new table
      def create_table(name : String, &block : Schema::TableDefinition ->)
        definition = Schema::TableDefinition.new(name)
        block.call(definition)

        sql = definition.to_sql
        @database.execute(sql)

        # Create indexes if any
        definition.indexes.each do |index|
          @database.execute(index.to_sql)
        end
      end

      # Drop an existing table
      def drop_table(name : String)
        @database.execute("DROP TABLE IF EXISTS \"#{name}\"")
      end

      # Add a column to an existing table
      def add_column(table : String, name : String, type : Symbol, **options)
        column_def = Schema::ColumnDefinition.new(name, type, **options)
        sql = "ALTER TABLE \"#{table}\" ADD COLUMN #{column_def.to_sql}"
        @database.execute(sql)
      end

      # Remove a column from a table
      def remove_column(table : String, name : String)
        # SQLite-specific: ALTER TABLE ... DROP COLUMN requires recreation
        @database.execute("ALTER TABLE \"#{table}\" DROP COLUMN \"#{name}\"")
      end

      # Rename a column
      def rename_column(table : String, old_name : String, new_name : String)
        @database.execute("ALTER TABLE \"#{table}\" RENAME COLUMN \"#{old_name}\" TO \"#{new_name}\"")
      end

      # Add an index
      def add_index(table : String, column : String, name : String? = nil, unique : Bool = false)
        index_name = name || "index_#{table}_on_#{column}"
        unique_sql = unique ? "UNIQUE" : ""
        @database.execute("CREATE #{unique_sql} INDEX IF NOT EXISTS \"#{index_name}\" ON \"#{table}\" (\"#{column}\")")
      end

      # Remove an index
      def remove_index(table : String, column : String? = nil, name : String? = nil)
        index_name = name || "index_#{table}_on_#{column}"
        @database.execute("DROP INDEX IF EXISTS \"#{index_name}\"")
      end

      # Add a reference column (foreign key) to an existing table
      #
      # Options:
      # - polymorphic: If true, creates both name_id and name_type columns
      #
      # Usage:
      # ```crystal
      # add_reference("comments", "user")                      # Adds user_id column
      # add_reference("comments", "commentable", polymorphic: true)  # Adds commentable_id and commentable_type
      # ```
      def add_reference(table : String, name : String, polymorphic : Bool = false)
        if polymorphic
          # Add both ID and type columns
          id_col = "#{name}_id"
          type_col = "#{name}_type"

          add_column(table, id_col, :bigint)
          add_column(table, type_col, :string)
          add_index(table, id_col, name: "index_#{table}_on_#{id_col}")
        else
          # Regular reference
          col_name = "#{name}_id"
          add_column(table, col_name, :bigint)
          add_index(table, col_name)
        end
      end

      # Alias for add_reference (Rails compatibility)
      def add_references(table : String, name : String, polymorphic : Bool = false)
        add_reference(table, name, polymorphic: polymorphic)
      end

      # Alias for add_reference (Rails compatibility)
      def add_belongs_to(table : String, name : String, polymorphic : Bool = false)
        add_reference(table, name, polymorphic: polymorphic)
      end

      # Remove a reference column from a table
      #
      # Options:
      # - polymorphic: If true, removes both name_id and name_type columns
      def remove_reference(table : String, name : String, polymorphic : Bool = false)
        if polymorphic
          # Remove both ID and type columns
          id_col = "#{name}_id"
          type_col = "#{name}_type"

          remove_index(table, id_col, name: "index_#{table}_on_#{id_col}")
          remove_column(table, type_col)
          remove_column(table, id_col)
        else
          # Regular reference
          col_name = "#{name}_id"
          remove_index(table, col_name)
          remove_column(table, col_name)
        end
      end

      # Alias for remove_reference (Rails compatibility)
      def remove_references(table : String, name : String, polymorphic : Bool = false)
        remove_reference(table, name, polymorphic: polymorphic)
      end

      # Alias for remove_reference (Rails compatibility)
      def remove_belongs_to(table : String, name : String, polymorphic : Bool = false)
        remove_reference(table, name, polymorphic: polymorphic)
      end

      # Execute raw SQL
      def execute(sql : String)
        @database.execute(sql)
      end
    end
  end
end

require "./schema"

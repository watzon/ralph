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
      abstract def up

      # Rollback the migration
      abstract def down

      # Get the migration version number
      #
      # Subclasses should override this
      def self.version : String
        "0"
      end

      # Macro to set the migration version
      macro migration_version(num)
        def self.version : String
          {{num.stringify}}
        end
      end

      def create_table(name : String, &block : Schema::TableDefinition ->)
        dialect = Schema::Dialect.current
        definition = Schema::TableDefinition.new(name, dialect)
        block.call(definition)

        sql = definition.to_sql
        @database.execute(sql)

        definition.indexes.each do |index|
          @database.execute(index.to_sql)
        end
      end

      # Drop an existing table
      def drop_table(name : String)
        @database.execute("DROP TABLE IF EXISTS \"#{name}\"")
      end

      def add_column(table : String, name : String, type : Symbol, **options)
        dialect = Schema::Dialect.current
        opts = options.to_h.transform_values(&.as(String | Int32 | Int64 | Float64 | Bool | Symbol | Nil))
        column_def = Schema::ColumnDefinition.new(name, type, dialect, opts)
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
      # ## Options
      #
      # - **polymorphic**: If true, creates both name_id and name_type columns
      # - **null**: Allow NULL values (default: true)
      # - **foreign_key**: Create a database-level FK constraint (default: false)
      # - **to_table**: Target table for FK constraint (default: pluralized name)
      # - **on_delete**: FK action on delete - :cascade, :nullify, :restrict, :no_action
      # - **on_update**: FK action on update - :cascade, :nullify, :restrict, :no_action
      # - **index**: Add an index (default: true)
      #
      # ## Usage
      #
      # ```
      # add_reference("posts", "user")                                 # Adds user_id column
      # add_reference("posts", "user", null: false, foreign_key: true) # With NOT NULL and FK
      # add_reference("posts", "author", to_table: "users", on_delete: :cascade)
      # add_reference("comments", "commentable", polymorphic: true) # Polymorphic
      # ```
      def add_reference(table : String, name : String, polymorphic : Bool = false, null : Bool = true, foreign_key : Bool = false, to_table : String? = nil, on_delete : Symbol? = nil, on_update : Symbol? = nil, index : Bool = true)
        if polymorphic
          # Add both ID and type columns
          id_col = "#{name}_id"
          type_col = "#{name}_type"

          add_column(table, id_col, :bigint, null: null)
          add_column(table, type_col, :string, null: null)
          add_index(table, id_col, name: "index_#{table}_on_#{id_col}") if index
        else
          # Regular reference
          col_name = "#{name}_id"
          target_table = to_table || "#{name}s"

          add_column(table, col_name, :bigint, null: null)
          add_index(table, col_name) if index

          # Add FK constraint if requested
          if foreign_key || on_delete || on_update
            add_foreign_key(table, target_table, column: col_name, on_delete: on_delete, on_update: on_update)
          end
        end
      end

      # Alias for add_reference (Rails compatibility)
      def add_references(table : String, name : String, polymorphic : Bool = false, null : Bool = true, foreign_key : Bool = false, to_table : String? = nil, on_delete : Symbol? = nil, on_update : Symbol? = nil, index : Bool = true)
        add_reference(table, name, polymorphic: polymorphic, null: null, foreign_key: foreign_key, to_table: to_table, on_delete: on_delete, on_update: on_update, index: index)
      end

      # Alias for add_reference (Rails compatibility)
      def add_belongs_to(table : String, name : String, polymorphic : Bool = false, null : Bool = true, foreign_key : Bool = false, to_table : String? = nil, on_delete : Symbol? = nil, on_update : Symbol? = nil, index : Bool = true)
        add_reference(table, name, polymorphic: polymorphic, null: null, foreign_key: foreign_key, to_table: to_table, on_delete: on_delete, on_update: on_update, index: index)
      end

      # Remove a reference column from a table
      #
      # ## Options
      #
      # - **polymorphic**: If true, removes both name_id and name_type columns
      # - **foreign_key**: Also remove the FK constraint (default: false)
      # - **to_table**: Target table for FK constraint name derivation
      def remove_reference(table : String, name : String, polymorphic : Bool = false, foreign_key : Bool = false, to_table : String? = nil)
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
          target_table = to_table || "#{name}s"

          # Remove FK constraint first if it exists
          if foreign_key
            remove_foreign_key(table, target_table, column: col_name)
          end

          remove_index(table, col_name)
          remove_column(table, col_name)
        end
      end

      # Alias for remove_reference (Rails compatibility)
      def remove_references(table : String, name : String, polymorphic : Bool = false, foreign_key : Bool = false, to_table : String? = nil)
        remove_reference(table, name, polymorphic: polymorphic, foreign_key: foreign_key, to_table: to_table)
      end

      # Alias for remove_reference (Rails compatibility)
      def remove_belongs_to(table : String, name : String, polymorphic : Bool = false, foreign_key : Bool = false, to_table : String? = nil)
        remove_reference(table, name, polymorphic: polymorphic, foreign_key: foreign_key, to_table: to_table)
      end

      # Add a foreign key constraint to an existing table
      #
      # ## Options
      #
      # - **column**: Source column (default: `{to_table singularized}_id`)
      # - **primary_key**: Target column (default: "id")
      # - **on_delete**: Action on delete - :cascade, :nullify, :restrict, :no_action
      # - **on_update**: Action on update - :cascade, :nullify, :restrict, :no_action
      # - **name**: Custom constraint name
      #
      # ## Usage
      #
      # ```
      # add_foreign_key("posts", "users")                         # posts.user_id -> users.id
      # add_foreign_key("posts", "users", on_delete: :cascade)    # With CASCADE
      # add_foreign_key("posts", "users", column: "author_id")    # Custom column
      # add_foreign_key("posts", "users", name: "fk_post_author") # Custom name
      # ```
      def add_foreign_key(from_table : String, to_table : String, column : String? = nil, primary_key : String = "id", on_delete : Symbol? = nil, on_update : Symbol? = nil, name : String? = nil)
        fk = Schema::ForeignKeyDefinition.new(
          from_table: from_table,
          from_column: column || "#{to_table.chomp("s")}_id",
          to_table: to_table,
          to_column: primary_key,
          on_delete: on_delete,
          on_update: on_update,
          name: name
        )
        @database.execute(fk.to_add_sql)
      end

      # Remove a foreign key constraint
      #
      # ## Options
      #
      # - **column**: Source column for deriving constraint name
      # - **name**: Explicit constraint name to drop
      #
      # ## Usage
      #
      # ```
      # remove_foreign_key("posts", "users") # Drop fk_posts_user_id
      # remove_foreign_key("posts", "users", column: "author_id")
      # remove_foreign_key("posts", name: "fk_post_author") # By explicit name
      # ```
      def remove_foreign_key(from_table : String, to_table : String? = nil, column : String? = nil, name : String? = nil)
        constraint_name = name || begin
          col = column || (to_table ? "#{to_table.chomp("s")}_id" : nil)
          raise ArgumentError.new("Must provide column, to_table, or name to remove_foreign_key") unless col
          "fk_#{from_table}_#{col}"
        end
        @database.execute("ALTER TABLE \"#{from_table}\" DROP CONSTRAINT \"#{constraint_name}\"")
      end

      # Rename a table
      #
      # ## Usage
      #
      # ```
      # rename_table("old_users", "users")
      # ```
      def rename_table(old_name : String, new_name : String)
        @database.execute("ALTER TABLE \"#{old_name}\" RENAME TO \"#{new_name}\"")
      end

      # Change a column's type, null constraint, or default value
      #
      # ## Options
      #
      # - **type**: New column type (optional - only change if specified)
      # - **null**: Allow NULL values (optional)
      # - **default**: Default value (optional, use :drop to remove default)
      #
      # ## Usage
      #
      # ```
      # change_column("users", "age", type: :bigint)
      # change_column("users", "name", null: false)
      # change_column("users", "status", default: "active")
      # change_column("users", "email", type: :text, null: false, default: "")
      # ```
      #
      # NOTE: SQLite has limited ALTER TABLE support. This method may require
      # table recreation for complex changes on SQLite.
      def change_column(table : String, column : String, type : Symbol? = nil, null : Bool? = nil, default : String | Int32 | Int64 | Float64 | Bool | Symbol | Nil = nil)
        dialect = Schema::Dialect.current

        # For PostgreSQL/MySQL style databases that support proper ALTER COLUMN
        # SQLite requires table recreation which is more complex
        if type
          type_sql = dialect.column_type(type, {} of Symbol => String | Int32 | Int64 | Float64 | Bool | Symbol | Nil)
          @database.execute("ALTER TABLE \"#{table}\" ALTER COLUMN \"#{column}\" TYPE #{type_sql}")
        end

        if !null.nil?
          if null
            @database.execute("ALTER TABLE \"#{table}\" ALTER COLUMN \"#{column}\" DROP NOT NULL")
          else
            @database.execute("ALTER TABLE \"#{table}\" ALTER COLUMN \"#{column}\" SET NOT NULL")
          end
        end

        if default == :drop
          @database.execute("ALTER TABLE \"#{table}\" ALTER COLUMN \"#{column}\" DROP DEFAULT")
        elsif !default.nil?
          default_sql = case default
                        when String then "'#{default}'"
                        when true   then "TRUE"
                        when false  then "FALSE"
                        else             default.to_s
                        end
          @database.execute("ALTER TABLE \"#{table}\" ALTER COLUMN \"#{column}\" SET DEFAULT #{default_sql}")
        end
      end

      # Change a column's type (convenience method)
      def change_column_type(table : String, column : String, new_type : Symbol)
        change_column(table, column, type: new_type)
      end

      # Change a column's null constraint (convenience method)
      def change_column_null(table : String, column : String, allow_null : Bool)
        change_column(table, column, null: allow_null)
      end

      # Change a column's default value (convenience method)
      def change_column_default(table : String, column : String, new_default : String | Int32 | Int64 | Float64 | Bool | Nil)
        change_column(table, column, default: new_default)
      end

      # Execute raw SQL
      def execute(sql : String)
        @database.execute(sql)
      end
    end
  end
end

require "./schema"

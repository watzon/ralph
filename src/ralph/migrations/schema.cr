require "./dialect"

module Ralph
  module Migrations
    module Schema
      class TableDefinition
        @name : String
        @columns : Array(ColumnDefinition) = [] of ColumnDefinition
        @primary_key_column : String? = nil
        @primary_key_sql : String? = nil
        @indexes : Array(IndexDefinition) = [] of IndexDefinition
        @foreign_keys : Array(ForeignKeyDefinition) = [] of ForeignKeyDefinition
        @dialect : Dialect::Base

        def initialize(@name : String, @dialect : Dialect::Base = Dialect.current)
        end

        def column(name : String, type : Symbol, **options)
          opts = options.to_h.transform_values(&.as(String | Int32 | Int64 | Float64 | Bool | Symbol | Nil))
          @columns << ColumnDefinition.new(name, type, @dialect, opts)
          if options[:primary]?
            @primary_key_column = name
          end
        end

        def primary_key(name = "id")
          @primary_key_sql = @dialect.primary_key_definition(name.to_s)
          @primary_key_column = name.to_s
        end

        # String column
        #
        # ## Options
        #
        # - **size**: Maximum length (default: 255)
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        #
        # ## Example
        #
        # ```
        # create_table :users do |t|
        #   t.string :name, size: 100, null: false
        #   t.string :email, null: false, default: ""
        # end
        # ```
        def string(name : String, size : Int32 = 255, null : Bool = true, default : String | Int32 | Int64 | Float64 | Bool | Nil = nil)
          column(name.to_s, :string, size: size, null: null, default: default)
        end

        # Text column (unlimited length string)
        #
        # ## Options
        #
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        def text(name : String, null : Bool = true, default : String | Int32 | Int64 | Float64 | Bool | Nil = nil)
          column(name.to_s, :text, null: null, default: default)
        end

        # Integer column (32-bit)
        #
        # ## Options
        #
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        def integer(name : String, null : Bool = true, default : Int32? = nil)
          column(name.to_s, :integer, null: null, default: default)
        end

        # Big integer column (64-bit)
        #
        # ## Options
        #
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        def bigint(name : String, null : Bool = true, default : Int64? = nil)
          column(name.to_s, :bigint, null: null, default: default)
        end

        # Float column (64-bit floating point)
        #
        # ## Options
        #
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        def float(name : String, null : Bool = true, default : Float64? = nil)
          column(name.to_s, :float, null: null, default: default)
        end

        # Decimal column (fixed precision)
        #
        # ## Options
        #
        # - **precision**: Total number of digits
        # - **scale**: Number of digits after decimal point
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        def decimal(name : String, precision : Int32? = nil, scale : Int32? = nil, null : Bool = true, default : String | Int32 | Int64 | Float64 | Bool | Nil = nil)
          column(name.to_s, :decimal, precision: precision, scale: scale, null: null, default: default)
        end

        # Boolean column
        #
        # ## Options
        #
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value (true/false)
        def boolean(name : String, null : Bool = true, default : Bool? = nil)
          column(name.to_s, :boolean, null: null, default: default.nil? ? nil : (default ? "TRUE" : "FALSE"))
        end

        # Date column (date only, no time)
        #
        # ## Options
        #
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        def date(name : String, null : Bool = true, default : String | Int32 | Int64 | Float64 | Bool | Nil = nil)
          column(name.to_s, :date, null: null, default: default)
        end

        # Timestamp column (date and time)
        #
        # ## Options
        #
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        def timestamp(name : String, null : Bool = true, default : String | Int32 | Int64 | Float64 | Bool | Nil = nil)
          column(name.to_s, :timestamp, null: null, default: default)
        end

        # Add created_at and updated_at timestamp columns
        #
        # Both columns allow NULL by default. Use timestamps_not_null for NOT NULL columns.
        def timestamps
          column("created_at", :timestamp)
          column("updated_at", :timestamp)
        end

        # Add created_at and updated_at timestamp columns with NOT NULL constraint
        def timestamps_not_null
          column("created_at", :timestamp, null: false)
          column("updated_at", :timestamp, null: false)
        end

        # UUID column
        #
        # ## Options
        #
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value (use "gen_random_uuid()" for PostgreSQL auto-generation)
        def uuid(name : String, null : Bool = true, default : String | Nil = nil)
          column(name.to_s, :uuid, null: null, default: default)
        end

        # JSONB column (PostgreSQL binary JSON, TEXT on SQLite)
        #
        # ## Options
        #
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        def jsonb(name : String, null : Bool = true, default : String | Nil = nil)
          column(name.to_s, :jsonb, null: null, default: default)
        end

        # JSON column (text-based JSON)
        #
        # ## Options
        #
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        def json(name : String, null : Bool = true, default : String | Nil = nil)
          column(name.to_s, :json, null: null, default: default)
        end

        # Enum column - stores enum values in the database
        #
        # ## Options
        #
        # - **values**: Array of allowed string values (required)
        # - **storage**: Storage strategy - :string (default), :integer, or :native (PostgreSQL only)
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        #
        # ## Example
        #
        # ```
        # create_table :users do |t|
        #   t.enum :status, values: ["active", "inactive", "suspended"], null: false
        #   t.enum :priority, values: ["low", "medium", "high"], storage: :integer
        # end
        # ```
        def enum(name : String, values : Array(String), storage : Symbol = :string, null : Bool = true, default : String | Nil = nil)
          column(name.to_s, :enum, values: values.join(","), storage: storage, null: null, default: default)
        end

        # String array column
        #
        # - **PostgreSQL**: TEXT[]
        # - **SQLite**: TEXT (JSON array)
        #
        # ## Options
        #
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        #
        # ## Example
        #
        # ```
        # create_table :posts do |t|
        #   t.string_array :tags, null: false, default: "[]"
        # end
        # ```
        def string_array(name : String, null : Bool = true, default : String | Nil = nil)
          column(name.to_s, :array, element_type: :text, null: null, default: default)
        end

        # Integer array column
        #
        # - **PostgreSQL**: INTEGER[]
        # - **SQLite**: TEXT (JSON array)
        #
        # ## Options
        #
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        def integer_array(name : String, null : Bool = true, default : String | Nil = nil)
          column(name.to_s, :array, element_type: :integer, null: null, default: default)
        end

        # Bigint array column
        #
        # - **PostgreSQL**: BIGINT[]
        # - **SQLite**: TEXT (JSON array)
        #
        # ## Options
        #
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        def bigint_array(name : String, null : Bool = true, default : String | Nil = nil)
          column(name.to_s, :array, element_type: :bigint, null: null, default: default)
        end

        # Float array column
        #
        # - **PostgreSQL**: DOUBLE PRECISION[]
        # - **SQLite**: TEXT (JSON array)
        #
        # ## Options
        #
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        def float_array(name : String, null : Bool = true, default : String | Nil = nil)
          column(name.to_s, :array, element_type: :float, null: null, default: default)
        end

        # Boolean array column
        #
        # - **PostgreSQL**: BOOLEAN[]
        # - **SQLite**: TEXT (JSON array)
        #
        # ## Options
        #
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        def boolean_array(name : String, null : Bool = true, default : String | Nil = nil)
          column(name.to_s, :array, element_type: :boolean, null: null, default: default)
        end

        # UUID array column
        #
        # - **PostgreSQL**: UUID[]
        # - **SQLite**: TEXT (JSON array)
        #
        # ## Options
        #
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        def uuid_array(name : String, null : Bool = true, default : String | Nil = nil)
          column(name.to_s, :array, element_type: :uuid, null: null, default: default)
        end

        # Generic array column with custom element type
        #
        # ## Options
        #
        # - **element_type**: Type of array elements (default: :text)
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        #
        # ## Example
        #
        # ```
        # create_table :data do |t|
        #   t.array :values, element_type: :float, null: false
        # end
        # ```
        def array(name : String, element_type : Symbol = :text, null : Bool = true, default : String | Nil = nil)
          column(name.to_s, :array, element_type: element_type, null: null, default: default)
        end

        # Binary/blob column
        #
        # ## Options
        #
        # - **null**: Allow NULL values (default: true)
        # - **default**: Default value
        def binary(name : String, null : Bool = true, default : String | Nil = nil)
          column(name.to_s, :binary, null: null, default: default)
        end

        # Reference column (foreign key column)
        #
        # Creates a foreign key column pointing to another table.
        #
        # ## Options
        #
        # - **polymorphic**: If true, creates both `{name}_id` and `{name}_type` columns
        # - **null**: Allow NULL values (default: true)
        # - **foreign_key**: Custom column name for the FK (default: `{name}_id`)
        # - **to_table**: Target table name (default: pluralized `name`)
        # - **on_delete**: Action on delete - :cascade, :nullify, :restrict, :no_action (default: nil)
        # - **on_update**: Action on update - :cascade, :nullify, :restrict, :no_action (default: nil)
        # - **index**: Add an index on the FK column (default: true)
        #
        # ## Example
        #
        # ```
        # create_table :posts do |t|
        #   t.reference :user, null: false, on_delete: :cascade
        #   t.reference :author, to_table: :users, foreign_key: "author_id"
        #   t.reference :commentable, polymorphic: true
        # end
        # ```
        def reference(name : String, polymorphic : Bool = false, null : Bool = true, foreign_key : String? = nil, to_table : String? = nil, on_delete : Symbol? = nil, on_update : Symbol? = nil, index : Bool = true)
          if polymorphic
            id_col_name = "#{name}_id"
            type_col_name = "#{name}_type"

            column(id_col_name, :bigint, null: null)
            column(type_col_name, :string, null: null)

            if index
              @indexes << IndexDefinition.new(@name, id_col_name, "index_#{@name}_on_#{id_col_name}", false)
            end
          else
            col_name = foreign_key || "#{name}_id"
            target_table = to_table || "#{name}s" # Simple pluralization
            column(col_name, :bigint, null: null)

            if index
              @indexes << IndexDefinition.new(@name, col_name, "index_#{@name}_on_#{col_name}", false)
            end

            # Add FK constraint if on_delete or on_update specified
            if on_delete || on_update
              @foreign_keys << ForeignKeyDefinition.new(
                from_table: @name,
                from_column: col_name,
                to_table: target_table,
                to_column: "id",
                on_delete: on_delete,
                on_update: on_update
              )
            end
          end
        end

        # Alias for reference (Rails compatibility)
        def references(name : String, polymorphic : Bool = false, null : Bool = true, foreign_key : String? = nil, to_table : String? = nil, on_delete : Symbol? = nil, on_update : Symbol? = nil, index : Bool = true)
          reference(name, polymorphic: polymorphic, null: null, foreign_key: foreign_key, to_table: to_table, on_delete: on_delete, on_update: on_update, index: index)
        end

        # Alias for reference (Rails compatibility)
        def belongs_to(name : String, polymorphic : Bool = false, null : Bool = true, foreign_key : String? = nil, to_table : String? = nil, on_delete : Symbol? = nil, on_update : Symbol? = nil, index : Bool = true)
          reference(name, polymorphic: polymorphic, null: null, foreign_key: foreign_key, to_table: to_table, on_delete: on_delete, on_update: on_update, index: index)
        end

        def index(column : String, name : String? = nil, unique : Bool = false)
          index_name = name || "index_#{@name}_on_#{column}"
          @indexes << IndexDefinition.new(@name, column, index_name, unique)
        end

        # Add a foreign key constraint
        #
        # ## Options
        #
        # - **column**: Source column (default: `{to_table singularized}_id`)
        # - **primary_key**: Target column (default: "id")
        # - **on_delete**: Action on delete - :cascade, :nullify, :restrict, :no_action
        # - **on_update**: Action on update - :cascade, :nullify, :restrict, :no_action
        # - **name**: Custom constraint name
        #
        # ## Example
        #
        # ```
        # create_table :posts do |t|
        #   t.bigint :user_id, null: false
        #   t.foreign_key :users, on_delete: :cascade
        # end
        # ```
        def foreign_key(to_table : String, column : String? = nil, primary_key : String = "id", on_delete : Symbol? = nil, on_update : Symbol? = nil, name : String? = nil)
          # Derive column name from table (e.g., "users" -> "user_id")
          col_name = column || "#{to_table.chomp("s")}_id"
          @foreign_keys << ForeignKeyDefinition.new(
            from_table: @name,
            from_column: col_name,
            to_table: to_table,
            to_column: primary_key,
            on_delete: on_delete,
            on_update: on_update,
            name: name
          )
        end

        def to_sql : String
          all_columns = [] of String

          if pk_sql = @primary_key_sql
            all_columns << pk_sql
          end

          @columns.each do |col|
            next if @primary_key_sql && col.name == @primary_key_column
            all_columns << col.to_sql
          end

          # Add inline foreign key constraints
          @foreign_keys.each do |fk|
            all_columns << fk.to_inline_sql
          end

          columns_sql = all_columns.join(", ")

          pk_constraint = if @primary_key_column && !@primary_key_sql
                            ", PRIMARY KEY (\"#{@primary_key_column}\")"
                          else
                            ""
                          end

          "CREATE TABLE IF NOT EXISTS \"#{@name}\" (#{columns_sql}#{pk_constraint})"
        end

        getter indexes : Array(IndexDefinition)
        getter foreign_keys : Array(ForeignKeyDefinition)
      end

      class ColumnDefinition
        @name : String
        @type : Symbol
        @dialect : Dialect::Base
        @options : Hash(Symbol, String | Int32 | Int64 | Float64 | Bool | Symbol | Nil)

        getter name : String

        def initialize(@name : String, @type : Symbol, @dialect : Dialect::Base, @options : Hash(Symbol, String | Int32 | Int64 | Float64 | Bool | Symbol | Nil))
        end

        def to_sql : String
          sql = "\"#{@name}\" #{@dialect.column_type(@type, @options)}"

          if @options.has_key?(:null) && @options[:null] == false
            sql += " NOT NULL"
          end

          if @options.has_key?(:default) && (default = @options[:default])
            sql += " DEFAULT #{format_default(default)}"
          end

          sql
        end

        private def format_default(value) : String
          case value
          when String then "'#{value}'"
          when true   then "TRUE"
          when false  then "FALSE"
          when Nil    then "NULL"
          else             value.to_s
          end
        end
      end

      class IndexDefinition
        @table : String
        @column : String
        @name : String
        @unique : Bool

        def initialize(@table : String, @column : String, @name : String, @unique : Bool = false)
        end

        getter table
        getter column
        getter name
        getter unique

        def to_sql : String
          unique = @unique ? "UNIQUE " : ""
          "CREATE #{unique}INDEX IF NOT EXISTS \"#{@name}\" ON \"#{@table}\" (\"#{@column}\")"
        end
      end

      # Represents a foreign key constraint
      #
      # Foreign keys enforce referential integrity at the database level.
      class ForeignKeyDefinition
        getter from_table : String
        getter from_column : String
        getter to_table : String
        getter to_column : String
        getter on_delete : Symbol?
        getter on_update : Symbol?
        getter name : String?

        def initialize(
          @from_table : String,
          @from_column : String,
          @to_table : String,
          @to_column : String = "id",
          @on_delete : Symbol? = nil,
          @on_update : Symbol? = nil,
          @name : String? = nil,
        )
        end

        # Generate the constraint name
        def constraint_name : String
          @name || "fk_#{@from_table}_#{@from_column}"
        end

        # Generate inline SQL for CREATE TABLE (CONSTRAINT ... FOREIGN KEY ...)
        def to_inline_sql : String
          sql = "CONSTRAINT \"#{constraint_name}\" FOREIGN KEY (\"#{@from_column}\") REFERENCES \"#{@to_table}\" (\"#{@to_column}\")"
          sql += " ON DELETE #{action_sql(@on_delete)}" if @on_delete
          sql += " ON UPDATE #{action_sql(@on_update)}" if @on_update
          sql
        end

        # Generate ALTER TABLE ADD CONSTRAINT SQL
        def to_add_sql : String
          sql = "ALTER TABLE \"#{@from_table}\" ADD CONSTRAINT \"#{constraint_name}\" FOREIGN KEY (\"#{@from_column}\") REFERENCES \"#{@to_table}\" (\"#{@to_column}\")"
          sql += " ON DELETE #{action_sql(@on_delete)}" if @on_delete
          sql += " ON UPDATE #{action_sql(@on_update)}" if @on_update
          sql
        end

        # Generate ALTER TABLE DROP CONSTRAINT SQL
        def to_drop_sql : String
          "ALTER TABLE \"#{@from_table}\" DROP CONSTRAINT \"#{constraint_name}\""
        end

        private def action_sql(action : Symbol?) : String
          case action
          when :cascade     then "CASCADE"
          when :nullify     then "SET NULL"
          when :restrict    then "RESTRICT"
          when :no_action   then "NO ACTION"
          when :set_default then "SET DEFAULT"
          else                   "NO ACTION"
          end
        end
      end
    end
  end
end

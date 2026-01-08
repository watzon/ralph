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

        # PostgreSQL-specific indexes
        @gin_indexes : Array(GinIndexDefinition) = [] of GinIndexDefinition
        @gist_indexes : Array(GistIndexDefinition) = [] of GistIndexDefinition
        @full_text_indexes : Array(FullTextIndexDefinition) = [] of FullTextIndexDefinition
        @partial_indexes : Array(PartialIndexDefinition) = [] of PartialIndexDefinition
        @expression_indexes : Array(ExpressionIndexDefinition) = [] of ExpressionIndexDefinition

        def initialize(@name : String, @dialect : Dialect::Base = Dialect.current)
        end

        def column(name : String, type : Symbol, **options)
          opts = options.to_h.transform_values(&.as(String | Int32 | Int64 | Float64 | Bool | Symbol | Nil))
          @columns << ColumnDefinition.new(name, type, @dialect, opts)
          if options[:primary]?
            @primary_key_column = name
          end
        end

        # Auto-incrementing integer primary key (default)
        #
        # Creates an auto-incrementing integer primary key column.
        #
        # - **SQLite**: `INTEGER PRIMARY KEY AUTOINCREMENT`
        # - **PostgreSQL**: `BIGSERIAL PRIMARY KEY`
        #
        # ## Example
        #
        # ```
        # create_table :users do |t|
        #   t.primary_key           # Creates "id" column
        #   t.primary_key "user_id" # Custom name
        # end
        # ```
        def primary_key(name = "id")
          @primary_key_sql = @dialect.primary_key_definition(name.to_s)
          @primary_key_column = name.to_s
        end

        # Type-aware primary key
        #
        # Creates a primary key column with the specified type. Useful for UUID,
        # string, or other non-integer primary keys.
        #
        # ## Options
        #
        # - **type**: Column type (:uuid, :string, :text, :integer, :bigint)
        # - **default**: SQL default expression (e.g., "gen_random_uuid()" for PostgreSQL UUID)
        #
        # ## Example
        #
        # ```
        # create_table :users do |t|
        #   t.primary_key "id", :uuid # UUID primary key
        #   t.string :name
        # end
        #
        # create_table :settings do |t|
        #   t.primary_key "key", :string # String primary key
        #   t.text :value
        # end
        # ```
        #
        # ## Backend Behavior
        #
        # | Type | SQLite | PostgreSQL |
        # |------|--------|------------|
        # | :uuid | CHAR(36) PRIMARY KEY NOT NULL | UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid() |
        # | :string | TEXT PRIMARY KEY NOT NULL | TEXT PRIMARY KEY NOT NULL |
        # | :integer | INTEGER PRIMARY KEY AUTOINCREMENT | SERIAL PRIMARY KEY |
        # | :bigint | INTEGER PRIMARY KEY AUTOINCREMENT | BIGSERIAL PRIMARY KEY |
        def primary_key(name : String, type : Symbol, default : String? = nil)
          @primary_key_sql = @dialect.primary_key_definition(name, type, default)
          @primary_key_column = name
        end

        # UUID primary key
        #
        # Creates a UUID primary key column. This is a convenience method for
        # `primary_key("id", :uuid)`.
        #
        # - **SQLite**: Stored as CHAR(36), requires application-level UUID generation
        # - **PostgreSQL**: Native UUID type with automatic generation via gen_random_uuid()
        #
        # ## Options
        #
        # - **name**: Column name (default: "id")
        # - **default**: SQL default expression. PostgreSQL defaults to "gen_random_uuid()".
        #   For SQLite, UUIDs must be generated in application code.
        #
        # ## Example
        #
        # ```
        # create_table :users do |t|
        #   t.uuid_primary_key
        #   t.string :email
        # end
        #
        # create_table :api_keys do |t|
        #   t.uuid_primary_key "key_id"
        #   t.string :name
        # end
        # ```
        def uuid_primary_key(name : String = "id", default : String? = nil)
          primary_key(name, :uuid, default)
        end

        # String primary key
        #
        # Creates a TEXT primary key column. Useful for natural keys like slugs,
        # codes, or external identifiers.
        #
        # ## Options
        #
        # - **name**: Column name (default: "id")
        # - **default**: SQL default expression
        #
        # ## Example
        #
        # ```
        # create_table :settings do |t|
        #   t.string_primary_key "key"
        #   t.text :value
        # end
        #
        # create_table :countries do |t|
        #   t.string_primary_key "code" # e.g., "US", "GB"
        #   t.string :name
        # end
        # ```
        def string_primary_key(name : String = "id", default : String? = nil)
          primary_key(name, :string, default)
        end

        # Bigint primary key (non-auto-incrementing)
        #
        # Creates a BIGINT primary key without auto-increment. Useful when you need
        # to control ID generation (e.g., distributed IDs, snowflake IDs).
        #
        # For auto-incrementing integer primary keys, use `primary_key()` instead.
        #
        # ## Options
        #
        # - **name**: Column name (default: "id")
        # - **default**: SQL default expression
        #
        # ## Example
        #
        # ```
        # create_table :events do |t|
        #   t.bigint_primary_key # Application generates IDs
        #   t.string :type
        # end
        # ```
        def bigint_primary_key(name : String = "id", default : String? = nil)
          primary_key(name, :bigint, default)
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

        # Add deleted_at timestamp column for soft deletes
        #
        # Use this in conjunction with the `paranoid` macro in your model
        # to enable soft delete functionality.
        #
        # ## Example
        #
        # ```
        # # Migration
        # create_table :users do |t|
        #   t.primary_key
        #   t.string :name
        #   t.timestamps
        #   t.soft_deletes # adds deleted_at column
        # end
        #
        # # Model
        # class User < Ralph::Model
        #   table :users
        #   column id, Int64, primary: true
        #   column name, String
        #   timestamps
        #   paranoid # enables soft delete behavior
        # end
        # ```
        def soft_deletes
          column("deleted_at", :timestamp)
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

            # Polymorphic IDs are stored as strings to support any primary key type
            # (Int64, String, UUID, etc.)
            column(id_col_name, :string, null: null)
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

        # ========================================
        # PostgreSQL-Specific Index Methods
        # ========================================

        # Add a GIN index (Generalized Inverted Index)
        #
        # GIN indexes are ideal for:
        # - JSONB containment queries
        # - Array overlap/containment
        # - Full-text search
        #
        # ## Example
        #
        # ```
        # create_table :posts do |t|
        #   t.jsonb :metadata
        #   t.string_array :tags
        #   t.gin_index :metadata
        #   t.gin_index :tags, name: "idx_posts_tags_gin"
        # end
        # ```
        #
        # ## Options
        #
        # - **name**: Custom index name (auto-generated if not provided)
        # - **fastupdate**: Use fast update optimization (default: true). Set to false for better search performance at cost of slower writes.
        def gin_index(column : String, name : String? = nil, fastupdate : Bool = true)
          index_name = name || "index_#{@name}_on_#{column}_gin"
          @gin_indexes << GinIndexDefinition.new(@name, column, index_name, fastupdate)
        end

        # Add a GiST index (Generalized Search Tree)
        #
        # GiST indexes are ideal for:
        # - Geometric data types
        # - Range types
        # - Nearest-neighbor searches
        #
        # ## Example
        #
        # ```
        # create_table :locations do |t|
        #   t.float :latitude
        #   t.float :longitude
        #   t.gist_index "latitude", name: "idx_lat_gist"
        # end
        # ```
        def gist_index(column : String, name : String? = nil)
          index_name = name || "index_#{@name}_on_#{column}_gist"
          @gist_indexes << GistIndexDefinition.new(@name, column, index_name)
        end

        # Add a GiST index on multiple columns
        def gist_index(columns : Array(String), name : String? = nil)
          index_name = name || "index_#{@name}_on_#{columns.join("_")}_gist"
          @gist_indexes << GistIndexDefinition.new(@name, columns, index_name)
        end

        # Add a full-text search index (GIN on tsvector)
        #
        # Creates a GIN index on a tsvector expression for efficient full-text search.
        #
        # ## Example
        #
        # ```
        # create_table :articles do |t|
        #   t.string :title
        #   t.text :content
        #
        #   # Single column
        #   t.full_text_index :title
        #
        #   # Multiple columns
        #   t.full_text_index [:title, :content], config: "english"
        # end
        # ```
        #
        # ## Options
        #
        # - **config**: Text search configuration (default: "english")
        # - **name**: Custom index name
        # - **fastupdate**: Use fast update optimization (default: true)
        def full_text_index(column : String, config : String = "english", name : String? = nil, fastupdate : Bool = true)
          index_name = name || "index_#{@name}_on_#{column}_fts"
          @full_text_indexes << FullTextIndexDefinition.new(@name, column, index_name, config, fastupdate)
        end

        # Add a full-text search index on multiple columns
        def full_text_index(columns : Array(String), config : String = "english", name : String? = nil, fastupdate : Bool = true)
          index_name = name || "index_#{@name}_on_#{columns.join("_")}_fts"
          @full_text_indexes << FullTextIndexDefinition.new(@name, columns, index_name, config, fastupdate)
        end

        # Add a partial index (index with WHERE condition)
        #
        # Partial indexes only index rows matching the WHERE condition.
        #
        # ## Example
        #
        # ```
        # create_table :users do |t|
        #   t.string :email
        #   t.boolean :active
        #
        #   # Only index active users' emails
        #   t.partial_index :email, condition: "active = true", unique: true
        # end
        # ```
        #
        # ## Options
        #
        # - **condition**: SQL WHERE clause (required)
        # - **name**: Custom index name
        # - **unique**: Create unique index (default: false)
        def partial_index(column : String, condition : String, name : String? = nil, unique : Bool = false)
          index_name = name || "index_#{@name}_on_#{column}_partial"
          @partial_indexes << PartialIndexDefinition.new(@name, column, index_name, condition, unique)
        end

        # Add an expression index
        #
        # Expression indexes index the result of an expression rather than a column.
        #
        # ## Example
        #
        # ```
        # create_table :users do |t|
        #   t.string :email
        #
        #   # Case-insensitive email lookup
        #   t.expression_index "lower(email)", name: "idx_users_email_lower", unique: true
        # end
        # ```
        #
        # ## Options
        #
        # - **name**: Index name (required)
        # - **unique**: Create unique index (default: false)
        # - **using**: Index method (e.g., "btree", "hash", "gin", "gist")
        def expression_index(expression : String, name : String, unique : Bool = false, using : String? = nil)
          @expression_indexes << ExpressionIndexDefinition.new(@name, expression, name, unique, using)
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
        getter gin_indexes : Array(GinIndexDefinition)
        getter gist_indexes : Array(GistIndexDefinition)
        getter full_text_indexes : Array(FullTextIndexDefinition)
        getter partial_indexes : Array(PartialIndexDefinition)
        getter expression_indexes : Array(ExpressionIndexDefinition)

        # Get all PostgreSQL-specific indexes
        def postgres_indexes : Array(GinIndexDefinition | GistIndexDefinition | FullTextIndexDefinition | PartialIndexDefinition | ExpressionIndexDefinition)
          result = [] of GinIndexDefinition | GistIndexDefinition | FullTextIndexDefinition | PartialIndexDefinition | ExpressionIndexDefinition
          result.concat(@gin_indexes)
          result.concat(@gist_indexes)
          result.concat(@full_text_indexes)
          result.concat(@partial_indexes)
          result.concat(@expression_indexes)
          result
        end
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

      # ========================================
      # PostgreSQL-Specific Index Definitions
      # ========================================

      # Represents a GIN (Generalized Inverted Index) index
      #
      # GIN indexes are optimized for searching within complex data types:
      # - JSONB containment queries (@>, ?, ?|, ?&)
      # - Array overlap/containment (&&, @>, <@)
      # - Full-text search (@@)
      #
      # ## Example
      #
      # ```
      # create_table :posts do |t|
      #   t.jsonb :metadata
      #   t.gin_index :metadata
      # end
      # ```
      class GinIndexDefinition
        getter table : String
        getter column : String
        getter name : String
        getter fastupdate : Bool

        def initialize(@table : String, @column : String, @name : String, @fastupdate : Bool = true)
        end

        def to_sql : String
          storage_param = @fastupdate ? "" : " WITH (fastupdate = off)"
          "CREATE INDEX IF NOT EXISTS \"#{@name}\" ON \"#{@table}\" USING gin(\"#{@column}\")#{storage_param}"
        end

        def to_drop_sql : String
          "DROP INDEX IF EXISTS \"#{@name}\""
        end
      end

      # Represents a GiST (Generalized Search Tree) index
      #
      # GiST indexes are optimized for:
      # - Geometric data types (point, circle, polygon)
      # - Range types
      # - Full-text search (alternative to GIN)
      # - Nearest-neighbor searches
      #
      # ## Example
      #
      # ```
      # create_table :locations do |t|
      #   t.float :latitude
      #   t.float :longitude
      #   t.gist_index [:latitude, :longitude]
      # end
      # ```
      class GistIndexDefinition
        getter table : String
        getter columns : Array(String)
        getter name : String

        def initialize(@table : String, columns : String | Array(String), @name : String)
          @columns = columns.is_a?(Array) ? columns : [columns]
        end

        def to_sql : String
          cols = @columns.map { |c| "\"#{c}\"" }.join(", ")
          "CREATE INDEX IF NOT EXISTS \"#{@name}\" ON \"#{@table}\" USING gist(#{cols})"
        end

        def to_drop_sql : String
          "DROP INDEX IF EXISTS \"#{@name}\""
        end
      end

      # Represents a full-text search GIN index
      #
      # Creates a GIN index on a tsvector expression for efficient full-text search.
      #
      # ## Example
      #
      # ```
      # create_table :articles do |t|
      #   t.string :title
      #   t.text :content
      #   t.full_text_index :title
      #   t.full_text_index [:title, :content], config: "english"
      # end
      # ```
      class FullTextIndexDefinition
        getter table : String
        getter columns : Array(String)
        getter name : String
        getter config : String
        getter fastupdate : Bool

        def initialize(@table : String, columns : String | Array(String), @name : String, @config : String = "english", @fastupdate : Bool = true)
          @columns = columns.is_a?(Array) ? columns : [columns]
        end

        def to_sql : String
          expression = if @columns.size == 1
                         "to_tsvector('#{@config}', \"#{@columns.first}\")"
                       else
                         coalesced = @columns.map { |c| "coalesce(\"#{c}\", '')" }.join(" || ' ' || ")
                         "to_tsvector('#{@config}', #{coalesced})"
                       end
          storage_param = @fastupdate ? "" : " WITH (fastupdate = off)"
          "CREATE INDEX IF NOT EXISTS \"#{@name}\" ON \"#{@table}\" USING gin(#{expression})#{storage_param}"
        end

        def to_drop_sql : String
          "DROP INDEX IF EXISTS \"#{@name}\""
        end
      end

      # Represents a partial index (index with WHERE condition)
      #
      # Partial indexes only index rows matching the WHERE condition,
      # making them smaller and faster for specific queries.
      #
      # ## Example
      #
      # ```
      # # Only index active users
      # add_partial_index :users, :email, condition: "active = true"
      #
      # # Only index published posts
      # add_partial_index :posts, :title, condition: "status = 'published'"
      # ```
      class PartialIndexDefinition
        getter table : String
        getter column : String
        getter name : String
        getter condition : String
        getter unique : Bool

        def initialize(@table : String, @column : String, @name : String, @condition : String, @unique : Bool = false)
        end

        def to_sql : String
          unique_sql = @unique ? "UNIQUE " : ""
          "CREATE #{unique_sql}INDEX IF NOT EXISTS \"#{@name}\" ON \"#{@table}\" (\"#{@column}\") WHERE #{@condition}"
        end

        def to_drop_sql : String
          "DROP INDEX IF EXISTS \"#{@name}\""
        end
      end

      # Represents an expression index
      #
      # Expression indexes index the result of an expression rather than a column.
      # Useful for case-insensitive searches, computed values, etc.
      #
      # ## Example
      #
      # ```
      # # Case-insensitive email lookup
      # add_expression_index :users, "lower(email)", name: "idx_users_email_lower"
      #
      # # Index on extracted year
      # add_expression_index :orders, "extract(year from created_at)", name: "idx_orders_year"
      # ```
      class ExpressionIndexDefinition
        getter table : String
        getter expression : String
        getter name : String
        getter unique : Bool
        getter using : String?

        def initialize(@table : String, @expression : String, @name : String, @unique : Bool = false, @using : String? = nil)
        end

        def to_sql : String
          unique_sql = @unique ? "UNIQUE " : ""
          using_sql = @using ? " USING #{@using}" : ""
          "CREATE #{unique_sql}INDEX IF NOT EXISTS \"#{@name}\" ON \"#{@table}\"#{using_sql} (#{@expression})"
        end

        def to_drop_sql : String
          "DROP INDEX IF EXISTS \"#{@name}\""
        end
      end
    end
  end
end

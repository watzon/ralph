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

        def string(name : String, size : Int32 = 255, default : String | Int32 | Int64 | Float64 | Bool | Nil = nil)
          column(name.to_s, :string, size: size, default: default)
        end

        def text(name : String, default : String | Int32 | Int64 | Float64 | Bool | Nil = nil)
          column(name.to_s, :text, default: default)
        end

        def integer(name : String, default : Int32? = nil)
          column(name.to_s, :integer, default: default)
        end

        def bigint(name : String, default : Int64? = nil)
          column(name.to_s, :bigint, default: default)
        end

        def float(name : String, default : Float64? = nil)
          column(name.to_s, :float, default: default)
        end

        def decimal(name : String, precision : Int32? = nil, scale : Int32? = nil, default : String | Int32 | Int64 | Float64 | Bool | Nil = nil)
          column(name.to_s, :decimal, precision: precision, scale: scale, default: default)
        end

        def boolean(name : String, default : Bool? = nil)
          column(name.to_s, :boolean, default: default.nil? ? nil : (default ? "TRUE" : "FALSE"))
        end

        def date(name : String, default : String | Int32 | Int64 | Float64 | Bool | Nil = nil)
          column(name.to_s, :date, default: default)
        end

        def timestamp(name : String, default : String | Int32 | Int64 | Float64 | Bool | Nil = nil)
          column(name.to_s, :timestamp, default: default)
        end

        def timestamps
          column("created_at", :timestamp)
          column("updated_at", :timestamp)
        end

        def uuid(name : String, default : String | Nil = nil)
          column(name.to_s, :uuid, default: default)
        end

        def jsonb(name : String, default : String | Nil = nil)
          column(name.to_s, :jsonb, default: default)
        end

        def json(name : String, default : String | Nil = nil)
          column(name.to_s, :json, default: default)
        end

        # Enum column - stores enum values in the database
        #
        # ## Options
        #
        # - **values**: Array of allowed string values (required)
        # - **storage**: Storage strategy - :string (default), :integer, or :native (PostgreSQL only)
        # - **default**: Default value
        #
        # ## Example
        #
        # ```crystal
        # create_table :users do |t|
        #   t.enum :status, values: ["active", "inactive", "suspended"]
        #   t.enum :priority, values: ["low", "medium", "high"], storage: :integer
        # end
        # ```
        def enum(name : String, values : Array(String), storage : Symbol = :string, default : String | Nil = nil)
          column(name.to_s, :enum, values: values.join(","), storage: storage, default: default)
        end

        # String array column
        #
        # - **PostgreSQL**: TEXT[]
        # - **SQLite**: TEXT (JSON array)
        #
        # ## Example
        #
        # ```crystal
        # create_table :posts do |t|
        #   t.string_array :tags
        # end
        # ```
        def string_array(name : String, default : String | Nil = nil)
          column(name.to_s, :array, element_type: :text, default: default)
        end

        # Integer array column
        #
        # - **PostgreSQL**: INTEGER[]
        # - **SQLite**: TEXT (JSON array)
        def integer_array(name : String, default : String | Nil = nil)
          column(name.to_s, :array, element_type: :integer, default: default)
        end

        # Bigint array column
        #
        # - **PostgreSQL**: BIGINT[]
        # - **SQLite**: TEXT (JSON array)
        def bigint_array(name : String, default : String | Nil = nil)
          column(name.to_s, :array, element_type: :bigint, default: default)
        end

        # Float array column
        #
        # - **PostgreSQL**: DOUBLE PRECISION[]
        # - **SQLite**: TEXT (JSON array)
        def float_array(name : String, default : String | Nil = nil)
          column(name.to_s, :array, element_type: :float, default: default)
        end

        # Boolean array column
        #
        # - **PostgreSQL**: BOOLEAN[]
        # - **SQLite**: TEXT (JSON array)
        def boolean_array(name : String, default : String | Nil = nil)
          column(name.to_s, :array, element_type: :boolean, default: default)
        end

        # UUID array column
        #
        # - **PostgreSQL**: UUID[]
        # - **SQLite**: TEXT (JSON array)
        def uuid_array(name : String, default : String | Nil = nil)
          column(name.to_s, :array, element_type: :uuid, default: default)
        end

        # Generic array column with custom element type
        #
        # ## Example
        #
        # ```crystal
        # create_table :data do |t|
        #   t.array :values, element_type: :float
        # end
        # ```
        def array(name : String, element_type : Symbol = :text, default : String | Nil = nil)
          column(name.to_s, :array, element_type: element_type, default: default)
        end

        def binary(name : String, default : String | Nil = nil)
          column(name.to_s, :binary, default: default)
        end

        def reference(name : String, polymorphic : Bool = false, foreign_key : String? = nil)
          if polymorphic
            id_col_name = "#{name}_id"
            type_col_name = "#{name}_type"

            column(id_col_name, :bigint)
            column(type_col_name, :string)

            @indexes << IndexDefinition.new(@name, id_col_name, "index_#{@name}_on_#{id_col_name}", false)
          else
            col_name = foreign_key || "#{name}_id"
            column(col_name, :bigint)
            @indexes << IndexDefinition.new(@name, col_name, "index_#{@name}_on_#{col_name}", false)
          end
        end

        def references(name : String, polymorphic : Bool = false, foreign_key : String? = nil)
          reference(name, polymorphic: polymorphic, foreign_key: foreign_key)
        end

        def belongs_to(name : String, polymorphic : Bool = false, foreign_key : String? = nil)
          reference(name, polymorphic: polymorphic, foreign_key: foreign_key)
        end

        def index(column : String, name : String? = nil, unique : Bool = false)
          index_name = name || "index_#{@name}_on_#{column}"
          @indexes << IndexDefinition.new(@name, column, index_name, unique)
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

          columns_sql = all_columns.join(", ")

          pk_constraint = if @primary_key_column && !@primary_key_sql
                           ", PRIMARY KEY (\"#{@primary_key_column}\")"
                         else
                           ""
                         end

          "CREATE TABLE IF NOT EXISTS \"#{@name}\" (#{columns_sql}#{pk_constraint})"
        end

        getter indexes : Array(IndexDefinition)
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
    end
  end
end

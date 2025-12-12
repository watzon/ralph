module Ralph
  module Migrations
    module Schema
      # Defines a table schema for migrations
      class TableDefinition
        @name : String
        @columns : Array(ColumnDefinition) = [] of ColumnDefinition
        @primary_key : String? = nil
        @indexes : Array(IndexDefinition) = [] of IndexDefinition

        def initialize(@name : String)
        end

        # Add a column to the table definition
        def column(name : String, type : Symbol, **options)
          @columns << ColumnDefinition.new(name, type, **options)
          if options[:primary]?
            @primary_key = name
          end
        end

        # Add a primary key column
        def primary_key(name = "id")
          column(name.to_s, :integer, primary: true)
        end

        # Add a string column
        def string(name : String, size : Int32 = 255, default : String | Int32 | Int64 | Float64 | Bool | Nil = nil)
          column(name.to_s, :string, size: size, default: default)
        end

        # Add a text column
        def text(name : String, default : String | Int32 | Int64 | Float64 | Bool | Nil = nil)
          column(name.to_s, :text, default: default)
        end

        # Add an integer column
        def integer(name : String, default : Int32? = nil)
          column(name.to_s, :integer, default: default)
        end

        # Add a bigint column
        def bigint(name : String, default : Int64? = nil)
          column(name.to_s, :bigint, default: default)
        end

        # Add a float column
        def float(name : String, default : Float64? = nil)
          column(name.to_s, :float, default: default)
        end

        # Add a decimal column
        def decimal(name : String, precision : Int32? = nil, scale : Int32? = nil, default : String | Int32 | Int64 | Float64 | Bool | Nil = nil)
          column(name.to_s, :decimal, precision: precision, scale: scale, default: default)
        end

        # Add a boolean column
        def boolean(name : String, default : Bool? = nil)
          column(name.to_s, :boolean, default: default.nil? ? nil : (default ? "TRUE" : "FALSE"))
        end

        # Add a date column
        def date(name : String, default : String | Int32 | Int64 | Float64 | Bool | Nil = nil)
          column(name.to_s, :date, default: default)
        end

        # Add a timestamp column
        def timestamp(name : String, default : String | Int32 | Int64 | Float64 | Bool | Nil = nil)
          column(name.to_s, :timestamp, default: default)
        end

        # Add created_at and updated_at timestamp columns
        def timestamps
          column("created_at", :timestamp)
          column("updated_at", :timestamp)
        end

        # Add a reference column (foreign key)
        #
        # Options:
        # - polymorphic: If true, creates both name_id and name_type columns
        # - foreign_key: Custom foreign key column name
        #
        # Usage:
        # ```crystal
        # reference("user")                      # Creates user_id column
        # reference("commentable", polymorphic: true)  # Creates commentable_id and commentable_type
        # ```
        def reference(name : String, polymorphic : Bool = false, foreign_key : String? = nil)
          if polymorphic
            # Create both ID and type columns for polymorphic associations
            id_col_name = "#{name}_id"
            type_col_name = "#{name}_type"

            column(id_col_name, :bigint)
            column(type_col_name, :string)

            # Index on the ID column for better query performance
            @indexes << IndexDefinition.new(@name, id_col_name, "index_#{@name}_on_#{id_col_name}", false)
          else
            # Regular reference: just the ID column
            col_name = foreign_key || "#{name}_id"
            column(col_name, :bigint)
            # Index for foreign key
            @indexes << IndexDefinition.new(@name, col_name, "index_#{@name}_on_#{col_name}", false)
          end
        end

        # Alias for reference (Rails compatibility)
        def references(name : String, polymorphic : Bool = false, foreign_key : String? = nil)
          reference(name, polymorphic: polymorphic, foreign_key: foreign_key)
        end

        # Alias for reference (Rails compatibility)
        def belongs_to(name : String, polymorphic : Bool = false, foreign_key : String? = nil)
          reference(name, polymorphic: polymorphic, foreign_key: foreign_key)
        end

        # Add an index
        def index(column : String, name : String? = nil, unique : Bool = false)
          index_name = name || "index_#{@name}_on_#{column}"
          @indexes << IndexDefinition.new(@name, column, index_name, unique)
        end

        # Get the SQL to create the table
        def to_sql : String
          columns_sql = @columns.map(&.to_sql).join(", ")
          pk_sql = @primary_key ? ", PRIMARY KEY (\"#{@primary_key}\")" : ""

          "CREATE TABLE IF NOT EXISTS \"#{@name}\" (#{columns_sql}#{pk_sql})"
        end

        # Get all indexes defined for this table
        getter indexes : Array(IndexDefinition)
      end

      # Defines a column for table creation
      class ColumnDefinition
        @name : String
        @type : Symbol
        @options : Hash(Symbol, String | Int32 | Int64 | Float64 | Bool | Symbol | Nil)

        def initialize(@name : String, @type : Symbol, **options)
          @options = options.to_h.transform_values(&.as(String | Int32 | Int64 | Float64 | Bool | Symbol | Nil))
        end

        def to_sql : String
          sql = "\"#{@name}\" #{sql_type}"

          if @options.has_key?(:null) && @options[:null] == false
            sql += " NOT NULL"
          end

          if @options.has_key?(:default) && (default = @options[:default])
            sql += " DEFAULT #{format_default(default)}"
          end

          sql
        end

        private def sql_type : String
          case @type
          when :integer then "INTEGER"
          when :bigint  then "BIGINT"
          when :string  then "VARCHAR(#{@options[:size] || 255})"
          when :text    then "TEXT"
          when :float   then "REAL"
          when :decimal then "DECIMAL#{@options[:precision] ? "(#{@options[:precision]}, #{@options[:scale] || 0})" : ""}"
          when :boolean then "BOOLEAN"
          when :date    then "DATE"
          when :timestamp then "TIMESTAMP"
          when :datetime then "DATETIME"
          else
            raise "Unknown column type: #{@type}"
          end
        end

        private def format_default(value) : String
          case value
          when String then "'#{value}'"
          when true   then "TRUE"
          when false  then "FALSE"
          when Nil    then "NULL"
          else value.to_s
          end
        end
      end

      # Defines an index for table creation
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

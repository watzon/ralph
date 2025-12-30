module Ralph
  module Migrations
    module Schema
      module Dialect
        abstract class Base
          abstract def column_type(type : Symbol, options : Hash(Symbol, String | Int32 | Int64 | Float64 | Bool | Symbol | Nil)) : String
          abstract def primary_key_definition(name : String) : String
          abstract def auto_increment_clause : String
          abstract def identifier : Symbol

          def precision_sql(options : Hash(Symbol, String | Int32 | Int64 | Float64 | Bool | Symbol | Nil)) : String
            precision = options[:precision]?
            scale = options[:scale]?
            if precision
              "(#{precision}, #{scale || 0})"
            else
              ""
            end
          end
        end

        class Sqlite < Base
          def column_type(type : Symbol, options : Hash(Symbol, String | Int32 | Int64 | Float64 | Bool | Symbol | Nil)) : String
            case type
            # Primitive types
            when :integer   then "INTEGER"
            when :bigint    then "BIGINT"
            when :string    then "VARCHAR(#{options[:size]? || 255})"
            when :text      then "TEXT"
            when :float     then "REAL"
            when :decimal   then "DECIMAL#{precision_sql(options)}"
            when :boolean   then "BOOLEAN"
            when :date      then "DATE"
            when :timestamp then "TIMESTAMP"
            when :datetime  then "DATETIME"
            when :binary    then "BLOB"
            # Advanced types (emulated in SQLite)
            when :json      then "TEXT"  # JSON stored as TEXT, validated with json_valid()
            when :jsonb     then "TEXT"  # JSONB emulated as TEXT in SQLite
            when :uuid      then "CHAR(36)"  # UUID stored as text
            when :array     then "TEXT"  # Arrays stored as JSON
            when :enum
              # Enum storage depends on options
              case options[:storage]?
              when :integer then "SMALLINT"
              else               "VARCHAR(50)"
              end
            else
              raise "Unknown column type for SQLite: #{type}"
            end
          end

          def primary_key_definition(name : String) : String
            "\"#{name}\" INTEGER PRIMARY KEY AUTOINCREMENT"
          end

          def auto_increment_clause : String
            "AUTOINCREMENT"
          end

          def identifier : Symbol
            :sqlite
          end
        end

        class Postgres < Base
          def column_type(type : Symbol, options : Hash(Symbol, String | Int32 | Int64 | Float64 | Bool | Symbol | Nil)) : String
            case type
            # Primitive types
            when :integer   then "INTEGER"
            when :bigint    then "BIGINT"
            when :string    then "VARCHAR(#{options[:size]? || 255})"
            when :text      then "TEXT"
            when :float     then "DOUBLE PRECISION"
            when :decimal   then "NUMERIC#{precision_sql(options)}"
            when :boolean   then "BOOLEAN"
            when :date      then "DATE"
            when :timestamp then "TIMESTAMP"
            when :datetime  then "TIMESTAMP"
            when :binary    then "BYTEA"
            # Advanced types (native in PostgreSQL)
            when :uuid      then "UUID"
            when :jsonb     then "JSONB"
            when :json      then "JSON"
            when :array
              # Array type needs element type
              element = options[:element_type]? || :text
              "#{element_type_to_sql(element)}[]"
            when :enum
              # Enum storage depends on options
              case options[:storage]?
              when :native  then options[:enum_name]?.try { |n| "\"#{n}\"" } || "VARCHAR(50)"
              when :integer then "SMALLINT"
              else               "VARCHAR(50)"
              end
            else
              raise "Unknown column type for PostgreSQL: #{type}"
            end
          end

          # Convert element type symbol to PostgreSQL SQL type
          private def element_type_to_sql(element : Symbol | String | Int32 | Int64 | Float64 | Bool | Nil) : String
            case element
            when :string, :text, "string", "text" then "TEXT"
            when :integer, "integer"              then "INTEGER"
            when :bigint, "bigint"                then "BIGINT"
            when :float, "float"                  then "DOUBLE PRECISION"
            when :boolean, "boolean"              then "BOOLEAN"
            when :uuid, "uuid"                    then "UUID"
            else                                       "TEXT"
            end
          end

          def primary_key_definition(name : String) : String
            "\"#{name}\" BIGSERIAL PRIMARY KEY"
          end

          def auto_increment_clause : String
            ""
          end

          def identifier : Symbol
            :postgres
          end
        end

        @@current : Base = Sqlite.new

        def self.current : Base
          @@current
        end

        def self.current=(dialect : Base)
          @@current = dialect
        end

        def self.set_from_backend(backend : Ralph::Database::Backend)
          @@current = case backend.dialect
                      when :sqlite   then Sqlite.new
                      when :postgres then Postgres.new
                      else                Sqlite.new
                      end
        end

        def self.sqlite : Sqlite
          Sqlite.new
        end

        def self.postgres : Postgres
          Postgres.new
        end
      end
    end
  end
end

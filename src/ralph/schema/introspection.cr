# Schema introspection data structures
#
# These records represent database schema objects as they exist in the actual
# database. They are used by both `db:pull` (to generate models from schema)
# and `db:generate` (to compare models against schema).
#
# Introspection is implemented at the backend/adapter level, so each database
# backend (SQLite, PostgreSQL, MySQL, etc.) provides its own implementation
# of the introspection methods that return these data structures.

module Ralph
  module Schema
    # Represents a database column as it exists in the actual database
    record DatabaseColumn,
      # Column name
      name : String,
      # Raw SQL type (e.g., "VARCHAR(255)", "BIGINT", "integer")
      type : String,
      # Whether the column allows NULL values
      nullable : Bool,
      # Default value expression as a string (e.g., "0", "'active'", "now()")
      default : String?,
      # Whether this column is part of the primary key
      primary_key : Bool,
      # Whether this column auto-increments (SERIAL, AUTOINCREMENT, etc.)
      auto_increment : Bool

    # Represents a database index
    record DatabaseIndex,
      # Index name
      name : String,
      # Table the index belongs to
      table : String,
      # Columns included in the index (in order)
      columns : Array(String),
      # Whether this is a unique index
      unique : Bool,
      # Index type (e.g., :btree, :hash, :gin, :gist) - nil for default
      type : Symbol? = nil,
      # Partial index condition (PostgreSQL)
      condition : String? = nil

    # Represents a foreign key constraint
    record DatabaseForeignKey,
      # Constraint name (may be nil for SQLite)
      name : String?,
      # Source table (the table with the FK column)
      from_table : String,
      # Source column (the FK column)
      from_column : String,
      # Target table (the referenced table)
      to_table : String,
      # Target column (usually the primary key)
      to_column : String,
      # ON DELETE action (:cascade, :set_null, :restrict, :no_action)
      on_delete : Symbol? = nil,
      # ON UPDATE action
      on_update : Symbol? = nil

    # Represents a complete database table schema
    struct DatabaseTable
      property name : String
      property columns : Array(DatabaseColumn)
      property indexes : Array(DatabaseIndex)
      property foreign_keys : Array(DatabaseForeignKey)
      property primary_key_columns : Array(String)

      def initialize(
        @name : String,
        @columns : Array(DatabaseColumn) = [] of DatabaseColumn,
        @indexes : Array(DatabaseIndex) = [] of DatabaseIndex,
        @foreign_keys : Array(DatabaseForeignKey) = [] of DatabaseForeignKey,
        @primary_key_columns : Array(String) = [] of String,
      )
      end

      # Get a column by name
      def column(name : String) : DatabaseColumn?
        @columns.find { |c| c.name == name }
      end

      # Check if table has a column
      def has_column?(name : String) : Bool
        @columns.any? { |c| c.name == name }
      end

      # Get the primary key column (assumes single-column PK)
      def primary_key : DatabaseColumn?
        @columns.find { |c| c.primary_key }
      end
    end

    # Represents the complete database schema
    struct DatabaseSchema
      property tables : Hash(String, DatabaseTable)

      def initialize(@tables : Hash(String, DatabaseTable) = {} of String => DatabaseTable)
      end

      # Get a table by name
      def table(name : String) : DatabaseTable?
        @tables[name]?
      end

      # Check if schema has a table
      def has_table?(name : String) : Bool
        @tables.has_key?(name)
      end

      # Get all table names
      def table_names : Array(String)
        @tables.keys
      end

      # Iterate over all tables
      def each_table(&block : DatabaseTable ->)
        @tables.each_value { |t| yield t }
      end
    end

    # Helper to parse ON DELETE/UPDATE actions from string
    def self.parse_referential_action(action : String?) : Symbol?
      return nil if action.nil?

      case action.upcase
      when "CASCADE"     then :cascade
      when "SET NULL"    then :set_null
      when "SET DEFAULT" then :set_default
      when "RESTRICT"    then :restrict
      when "NO ACTION"   then :no_action
      else                    nil
      end
    end
  end
end

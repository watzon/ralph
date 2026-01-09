# Schema Comparator for db:generate
#
# Compares model schemas against database schemas to produce
# a diff that can be used to generate migrations.

module Ralph
  module Schema
    # Column definition from a model
    record ModelColumn,
      name : String,
      crystal_type : String,
      sql_type : Symbol,
      nullable : Bool,
      primary_key : Bool,
      default : String | Int32 | Int64 | Float64 | Bool | Nil

    # Foreign key definition from a model association
    record ModelForeignKey,
      from_column : String,
      to_table : String,
      to_column : String,
      on_delete : Symbol? = nil,
      on_update : Symbol? = nil

    # Complete model schema derived from Ralph::Model
    struct ModelSchema
      property table_name : String
      property columns : Array(ModelColumn)
      property foreign_keys : Array(ModelForeignKey)
      property indexes : Array(DatabaseIndex)

      def initialize(
        @table_name : String,
        @columns : Array(ModelColumn) = [] of ModelColumn,
        @foreign_keys : Array(ModelForeignKey) = [] of ModelForeignKey,
        @indexes : Array(DatabaseIndex) = [] of DatabaseIndex,
      )
      end

      # Get a column by name
      def column(name : String) : ModelColumn?
        @columns.find { |c| c.name == name }
      end

      # Check if model has a column
      def has_column?(name : String) : Bool
        @columns.any? { |c| c.name == name }
      end
    end

    # Types of schema changes
    enum ChangeType
      CreateTable
      DropTable
      AddColumn
      RemoveColumn
      ChangeColumnType
      ChangeColumnDefault
      ChangeColumnNullable
      AddForeignKey
      RemoveForeignKey
      AddIndex
      RemoveIndex
    end

    # Represents a single schema change
    struct SchemaChange
      property type : ChangeType
      property table : String
      property column : String?
      property details : Hash(String, String)
      property warning : String?

      def initialize(@type, @table, @column = nil, @details = {} of String => String, @warning = nil)
      end

      # True if this change could cause data loss
      def destructive? : Bool
        case @type
        when .drop_table?, .remove_column?, .change_column_type?
          true
        else
          false
        end
      end
    end

    # Result of comparing schemas
    struct SchemaDiff
      property changes : Array(SchemaChange)
      property warnings : Array(String)

      def initialize(@changes = [] of SchemaChange, @warnings = [] of String)
      end

      def empty? : Bool
        @changes.empty?
      end

      def has_destructive_changes? : Bool
        @changes.any?(&.destructive?)
      end
    end

    # Compares model schemas against database schema
    class SchemaComparator
      @model_schemas : Hash(String, ModelSchema)
      @db_schema : DatabaseSchema
      @dialect : Symbol

      def initialize(@model_schemas, @db_schema, @dialect = :sqlite)
      end

      def compare : SchemaDiff
        changes = [] of SchemaChange
        warnings = [] of String

        # 1. Find tables in models but not in DB (need to create)
        @model_schemas.each do |table_name, model_schema|
          unless @db_schema.has_table?(table_name)
            changes << SchemaChange.new(
              type: ChangeType::CreateTable,
              table: table_name,
              details: {"columns" => model_schema.columns.map(&.name).join(", ")}
            )
            next
          end

          # Table exists, compare columns
          db_table = @db_schema.table(table_name).not_nil!
          changes.concat(compare_columns(model_schema, db_table))
          changes.concat(compare_foreign_keys(model_schema, db_table))
        end

        # 2. Find tables in DB but not in models (might drop, with warning)
        @db_schema.table_names.each do |db_table_name|
          # Skip internal tables
          next if db_table_name.starts_with?("_") || db_table_name == "schema_migrations"

          unless @model_schemas.has_key?(db_table_name)
            changes << SchemaChange.new(
              type: ChangeType::DropTable,
              table: db_table_name,
              warning: "Table #{db_table_name} exists in database but not in models"
            )
            warnings << "Table '#{db_table_name}' will be dropped. This will delete all data in the table."
          end
        end

        SchemaDiff.new(changes, warnings)
      end

      private def compare_columns(model : ModelSchema, db_table : DatabaseTable) : Array(SchemaChange)
        changes = [] of SchemaChange
        model_cols = model.columns.map { |c| {c.name, c} }.to_h
        db_cols = db_table.columns.map { |c| {c.name, c} }.to_h

        # Columns in model but not in DB (add)
        model_cols.each do |name, model_col|
          unless db_cols.has_key?(name)
            changes << SchemaChange.new(
              type: ChangeType::AddColumn,
              table: model.table_name,
              column: name,
              details: {
                "type"     => model_col.sql_type.to_s,
                "nullable" => model_col.nullable.to_s,
              }
            )
          end
        end

        # Columns in DB but not in model (remove)
        db_cols.each do |name, db_col|
          unless model_cols.has_key?(name)
            changes << SchemaChange.new(
              type: ChangeType::RemoveColumn,
              table: model.table_name,
              column: name,
              warning: "Column #{name} will be removed"
            )
          end
        end

        # Columns in both - check for differences
        model_cols.each do |name, model_col|
          next unless db_col = db_cols[name]?

          # Compare types (simplified - would need proper mapping)
          db_sql_type = map_db_type_to_symbol(db_col.type)
          if model_col.sql_type != db_sql_type
            changes << SchemaChange.new(
              type: ChangeType::ChangeColumnType,
              table: model.table_name,
              column: name,
              details: {
                "from" => db_col.type,
                "to"   => model_col.sql_type.to_s,
              },
              warning: "Type change may cause data loss"
            )
          end

          # Compare nullable
          if model_col.nullable != db_col.nullable
            changes << SchemaChange.new(
              type: ChangeType::ChangeColumnNullable,
              table: model.table_name,
              column: name,
              details: {
                "from" => db_col.nullable.to_s,
                "to"   => model_col.nullable.to_s,
              }
            )
          end
        end

        changes
      end

      private def compare_foreign_keys(model : ModelSchema, db_table : DatabaseTable) : Array(SchemaChange)
        changes = [] of SchemaChange

        # Build comparable FK sets
        model_fks = model.foreign_keys.map { |fk| {fk.from_column, fk} }.to_h
        db_fks = db_table.foreign_keys.map { |fk| {fk.from_column, fk} }.to_h

        # FKs in model but not in DB
        model_fks.each do |col, fk|
          unless db_fks.has_key?(col)
            changes << SchemaChange.new(
              type: ChangeType::AddForeignKey,
              table: model.table_name,
              column: col,
              details: {
                "to_table"  => fk.to_table,
                "to_column" => fk.to_column,
              }
            )
          end
        end

        # FKs in DB but not in model
        db_fks.each do |col, fk|
          unless model_fks.has_key?(col)
            changes << SchemaChange.new(
              type: ChangeType::RemoveForeignKey,
              table: model.table_name,
              column: col
            )
          end
        end

        changes
      end

      private def map_db_type_to_symbol(db_type : String) : Symbol
        case db_type.downcase
        when /^(bigint|int8|bigserial)/
          :bigint
        when /^(integer|int4?|smallint|int2|serial)/
          :integer
        when /^(varchar|character varying|char|text|clob)/
          :string
        when /^(boolean|bool)/
          :boolean
        when /^(real|float4)/
          :float
        when /^(double|float8|decimal|numeric)/
          :float
        when /^(timestamp|datetime)/
          :timestamp
        when /^(date)/
          :date
        when /^(time)/
          :time
        when /^(json|jsonb)/
          :jsonb
        when /^(bytea|blob|binary)/
          :binary
        when /^uuid/
          :uuid
        else
          :string
        end
      end
    end
  end
end

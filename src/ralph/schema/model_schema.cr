# Model Schema Extractor for db:generate
#
# Extracts schema information from Ralph model definitions
# so it can be compared against the actual database schema.

module Ralph
  module Schema
    # Extracts schema from a model class
    class ModelSchemaExtractor
      # Map Crystal types to SQL symbols used in migrations
      TYPE_MAP = {
        "Int64"     => :bigint,
        "Int32"     => :integer,
        "Int16"     => :smallint,
        "String"    => :string,
        "Bool"      => :boolean,
        "Float64"   => :float,
        "Float32"   => :float,
        "Time"      => :timestamp,
        "JSON::Any" => :jsonb,
        "Bytes"     => :binary,
        "UUID"      => :uuid,
      }

      def self.extract(model_class : Ralph::Model.class) : ModelSchema
        table_name = model_class.table_name
        columns = extract_columns(model_class)
        foreign_keys = extract_foreign_keys(model_class)
        indexes = [] of DatabaseIndex # TODO: Extract indexes from model if defined

        ModelSchema.new(table_name, columns, foreign_keys, indexes)
      end

      def self.extract_all : Hash(String, ModelSchema)
        result = {} of String => ModelSchema

        Ralph::Schema.registered_models.each do |model_class|
          schema = extract(model_class)
          result[schema.table_name] = schema
        end

        result
      end

      private def self.extract_columns(model_class : Ralph::Model.class) : Array(ModelColumn)
        model_class.columns.map do |name, meta|
          # Handle both String? and (String | Nil) forms
          nullable = meta.type_name.ends_with?("?") || meta.type_name.includes?("| Nil")

          # Extract base type, removing nullable markers
          type_str = meta.type_name
            .gsub("?", "")
            .gsub(/\s*\|\s*Nil\s*/, "")
            .gsub(/^\(/, "")
            .gsub(/\)$/, "")
            .strip

          sql_type = TYPE_MAP[type_str]? || :string

          ModelColumn.new(
            name: name,
            crystal_type: meta.type_name,
            sql_type: sql_type,
            nullable: nullable,
            primary_key: meta.primary,
            default: meta.default
          )
        end
      end

      private def self.extract_foreign_keys(model_class : Ralph::Model.class) : Array(ModelForeignKey)
        fks = [] of ModelForeignKey

        class_name = model_class.name.split("::").last
        associations = Ralph::Associations.associations[class_name]?
        return fks unless associations

        associations.each do |name, meta|
          next unless meta.type == :belongs_to
          next if meta.polymorphic

          # belongs_to implies a foreign key column
          # on_delete and on_update are optional and default to nil
          fks << ModelForeignKey.new(
            from_column: meta.foreign_key,
            to_table: meta.table_name,
            to_column: meta.primary_key,
            on_delete: nil, # TODO: Extract from association metadata if available
            on_update: nil  # TODO: Extract from association metadata if available
          )
        end

        fks
      end
    end
  end
end

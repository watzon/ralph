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
        "Float64"   => :float64, # DOUBLE PRECISION
        "Float32"   => :float32, # REAL
        "Time"      => :timestamp,
        "JSON::Any" => :jsonb,
        "Bytes"     => :binary,
        "UUID"      => :uuid,
      }

      # Get the set of polymorphic FK column names for a model
      def self.polymorphic_fk_columns(model_class : Ralph::Model.class) : Set(String)
        columns = Set(String).new
        class_name = model_class.name.split("::").last
        associations = Ralph::Associations.associations[class_name]?
        return columns unless associations

        associations.each do |name, meta|
          next unless meta.type == :belongs_to && meta.polymorphic
          columns << meta.foreign_key
        end

        columns
      end

      def self.extract(model_class : Ralph::Model.class) : ModelSchema
        table_name = model_class.table_name
        columns = extract_columns(model_class)
        foreign_keys = extract_foreign_keys(model_class)
        indexes = [] of DatabaseIndex # TODO: Extract indexes from model if defined
        poly_fk_cols = polymorphic_fk_columns(model_class)

        ModelSchema.new(table_name, columns, foreign_keys, indexes, poly_fk_cols)
      end

      def self.extract_all : Hash(String, ModelSchema)
        result = {} of String => ModelSchema

        # Use compile-time macro to find all Model subclasses
        # This avoids relying on runtime registration which has timing issues
        {% for model_class in Ralph::Model.all_subclasses %}
          {% unless model_class.abstract? %}
            result[{{ model_class }}.table_name] = extract({{ model_class }})
          {% end %}
        {% end %}

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

          # Get the actual table name from the associated model class
          # This is more accurate than the metadata which may be derived from class name
          target_table = resolve_table_name(meta.class_name)

          # belongs_to implies a foreign key column
          # on_delete and on_update are optional and default to nil
          fks << ModelForeignKey.new(
            from_column: meta.foreign_key,
            to_table: target_table,
            to_column: meta.primary_key,
            on_delete: nil, # TODO: Extract from association metadata if available
            on_update: nil  # TODO: Extract from association metadata if available
          )
        end

        fks
      end

      # Resolve the actual table name for a model class by name
      # Uses compile-time macro to check all known model subclasses
      private def self.resolve_table_name(class_name : String) : String
        # Try to find the model class and get its actual table name
        {% for model_class in Ralph::Model.all_subclasses %}
          {% unless model_class.abstract? %}
            if class_name == {{ model_class.name.stringify }} || class_name == {{ model_class.name.split("::").last.stringify }}
              return {{ model_class }}.table_name
            end
          {% end %}
        {% end %}

        # Fallback: pluralize the underscored class name (Rails convention)
        # Handle namespaced class names like "Admin::User" -> "user"
        base_name = class_name.split("::").last
        base_name.underscore + "s"
      end
    end
  end
end

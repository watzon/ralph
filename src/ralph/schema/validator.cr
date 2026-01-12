# Schema Validator
#
# Compares model definitions against actual database schema to catch
# mismatches before they cause cryptic runtime errors.
#
# ## Usage
#
# ```
# # Validate a single model
# result = Ralph::Schema::Validator.validate(User)
# puts result.valid?
# puts result.errors
#
# # Validate all registered models
# results = Ralph::Schema::Validator.validate_all
# results.each do |table_name, result|
#   unless result.valid?
#     puts "#{table_name}: #{result.errors.join(", ")}"
#   end
# end
#
# # Validate and raise on any errors (useful for boot-time checks)
# Ralph::Schema::Validator.validate!(User)
# Ralph::Schema::Validator.validate_all!
# ```

module Ralph
  module Schema
    # Result of validating a single model against database schema
    struct ValidationResult
      getter model_name : String
      getter table_name : String
      getter errors : Array(String)
      getter warnings : Array(String)

      def initialize(
        @model_name : String,
        @table_name : String,
        @errors : Array(String) = [] of String,
        @warnings : Array(String) = [] of String,
      )
      end

      def valid? : Bool
        @errors.empty?
      end

      def to_s(io : IO) : Nil
        if valid?
          io << @model_name << ": OK"
          unless @warnings.empty?
            io << " (#{@warnings.size} warnings)"
          end
        else
          io << @model_name << ": INVALID\n"
          @errors.each do |error|
            io << "  - " << error << "\n"
          end
          @warnings.each do |warning|
            io << "  - [WARN] " << warning << "\n"
          end
        end
      end
    end

    # Validates model schemas against database schema
    module Validator
      # PostgreSQL type mappings to Crystal types
      # Used to check if model types match database types
      PG_TYPE_TO_CRYSTAL = {
        # Integers
        "smallint"    => ["Int16", "Int32"],
        "integer"     => ["Int32"],
        "bigint"      => ["Int64"],
        "int2"        => ["Int16", "Int32"],
        "int4"        => ["Int32"],
        "int8"        => ["Int64"],
        "serial"      => ["Int32"],
        "bigserial"   => ["Int64"],
        "smallserial" => ["Int16", "Int32"],

        # Floating point - CRITICAL: real is Float32, not Float64!
        "real"             => ["Float32"],
        "float4"           => ["Float32"],
        "double precision" => ["Float64"],
        "float8"           => ["Float64"],
        "numeric"          => ["Float64", "PG::Numeric", "BigDecimal"],
        "decimal"          => ["Float64", "PG::Numeric", "BigDecimal"],

        # Text
        "text"              => ["String"],
        "varchar"           => ["String"],
        "character varying" => ["String"],
        "char"              => ["String"],
        "character"         => ["String"],
        "name"              => ["String"],

        # Boolean
        "boolean" => ["Bool"],
        "bool"    => ["Bool"],

        # Date/Time
        "timestamp"                   => ["Time"],
        "timestamp without time zone" => ["Time"],
        "timestamp with time zone"    => ["Time"],
        "timestamptz"                 => ["Time"],
        "date"                        => ["Time"],
        "time"                        => ["Time"],
        "time without time zone"      => ["Time"],
        "time with time zone"         => ["Time"],
        "timetz"                      => ["Time"],

        # UUID
        "uuid" => ["UUID"],

        # JSON
        "json"  => ["JSON::Any"],
        "jsonb" => ["JSON::Any"],

        # Binary
        "bytea" => ["Bytes", "Slice(UInt8)"],

        # Arrays (simplified - actual type checking is complex)
        "text[]"    => ["Array(String)"],
        "integer[]" => ["Array(Int32)"],
        "bigint[]"  => ["Array(Int64)"],
        "boolean[]" => ["Array(Bool)"],
      }

      # Validate a model class against the database schema
      def self.validate(model_class : Ralph::Model.class) : ValidationResult
        model_name = model_class.name
        table_name = model_class.table_name
        errors = [] of String
        warnings = [] of String

        # Get database columns
        begin
          db_columns = Ralph.database.introspect_columns(table_name)
        rescue ex
          errors << "Cannot introspect table '#{table_name}': #{ex.message}"
          return ValidationResult.new(model_name, table_name, errors, warnings)
        end

        db_column_map = db_columns.map { |c| {c.name, c} }.to_h

        # Get model columns
        model_columns = model_class.columns

        # Check for columns missing in model (exist in DB but not model)
        db_column_names = db_columns.map(&.name).to_set
        model_column_names = model_columns.keys.to_set

        missing_in_model = db_column_names - model_column_names
        unless missing_in_model.empty?
          errors << "Missing columns in model: #{missing_in_model.to_a.join(", ")}"
        end

        # Check for extra columns in model (exist in model but not DB)
        extra_in_model = model_column_names - db_column_names
        unless extra_in_model.empty?
          errors << "Extra columns in model (not in database): #{extra_in_model.to_a.join(", ")}"
        end

        # Check each model column against database
        model_columns.each do |name, meta|
          db_col = db_column_map[name]?
          next unless db_col # Already reported as extra

          # Check type compatibility
          type_error = check_type_compatibility(name, meta.type_name, db_col.type)
          errors << type_error if type_error

          # Check nullability
          model_nullable = meta.type_name.ends_with?("?") || meta.type_name.includes?("| Nil")
          if db_col.nullable && !model_nullable && !meta.primary
            warnings << "Column '#{name}' is nullable in DB but not in model"
          elsif !db_col.nullable && model_nullable
            warnings << "Column '#{name}' is NOT nullable in DB but is nilable in model"
          end
        end

        ValidationResult.new(model_name, table_name, errors, warnings)
      end

      # Validate a model and raise if invalid
      def self.validate!(model_class : Ralph::Model.class) : Nil
        result = validate(model_class)
        unless result.valid?
          raise Ralph::SchemaMismatchError.new(
            model_name: result.model_name,
            table_name: result.table_name,
            expected_columns: model_class.column_names_ordered,
            actual_columns: Ralph.database.introspect_columns(result.table_name).map(&.name)
          )
        end
      end

      # Validate all registered model classes
      def self.validate_all : Hash(String, ValidationResult)
        results = {} of String => ValidationResult

        {% for model_class in Ralph::Model.all_subclasses %}
          {% unless model_class.abstract? %}
            results[{{ model_class }}.table_name] = validate({{ model_class }})
          {% end %}
        {% end %}

        results
      end

      # Validate all models and raise if any are invalid
      def self.validate_all! : Nil
        results = validate_all
        invalid = results.select { |_, r| !r.valid? }

        unless invalid.empty?
          message = String.build do |str|
            str << "Schema validation failed for #{invalid.size} model(s):\n\n"
            invalid.each do |table_name, result|
              str << result.to_s << "\n"
            end
          end
          raise Ralph::Error.new(message)
        end
      end

      # Print a validation report for all models
      def self.report : String
        results = validate_all

        String.build do |str|
          str << "Schema Validation Report\n"
          str << "=" * 50 << "\n\n"

          valid_count = 0
          invalid_count = 0

          results.each do |table_name, result|
            str << result.to_s << "\n"
            if result.valid?
              valid_count += 1
            else
              invalid_count += 1
            end
          end

          str << "\n" << "=" * 50 << "\n"
          str << "Total: #{results.size} models, #{valid_count} valid, #{invalid_count} invalid\n"
        end
      end

      # Check if a Crystal type is compatible with a PostgreSQL type
      private def self.check_type_compatibility(
        column_name : String,
        crystal_type : String,
        db_type : String,
      ) : String?
        # Normalize the crystal type (remove nilable markers)
        base_crystal_type = crystal_type
          .gsub("?", "")
          .gsub(/\s*\|\s*Nil\s*/, "")
          .gsub(/^\(/, "")
          .gsub(/\)$/, "")
          .strip

        # Normalize DB type (remove size/precision info, lowercase)
        normalized_db_type = db_type
          .downcase
          .gsub(/\(\d+(\s*,\s*\d+)?\)/, "") # Remove (10) or (10, 2)
          .strip

        # Get acceptable Crystal types for this DB type
        acceptable_types = PG_TYPE_TO_CRYSTAL[normalized_db_type]?

        unless acceptable_types
          # Unknown DB type - we can't validate, just warn
          return nil
        end

        unless acceptable_types.includes?(base_crystal_type)
          return "Column '#{column_name}' type mismatch: " \
                 "model has #{base_crystal_type}, " \
                 "database has #{db_type} " \
                 "(expected one of: #{acceptable_types.join(", ")})"
        end

        nil
      end
    end
  end
end

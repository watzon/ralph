require "./base"
require "json"

module Ralph
  module Types
    # JSON mode - determines how JSON is stored
    enum JsonMode
      Json  # Standard JSON (text storage)
      Jsonb # Binary JSON (PostgreSQL native, SQLite emulated)
    end

    # JSON type that provides unified JSON/JSONB support across backends
    #
    # ## Backend Behavior
    #
    # - **PostgreSQL**: Uses native JSON or JSONB types with full indexing support
    # - **SQLite**: Stores as TEXT with JSON validation (SQLite 3.38+ supports json_valid)
    #
    # ## Example
    #
    # ```crystal
    # # Standard JSON
    # type = Ralph::Types::JsonType.new
    # type.dump({"key" => "value"})  # => "{\"key\":\"value\"}"
    # type.load("{\"key\":\"value\"}") # => JSON::Any
    #
    # # JSONB (PostgreSQL optimized)
    # type = Ralph::Types::JsonType.new(JsonMode::Jsonb)
    # ```
    #
    # ## Usage in Models
    #
    # ```crystal
    # class Post < Ralph::Model
    #   column metadata : JSON::Any
    # end
    #
    # post = Post.new(metadata: JSON.parse(%({"theme":"dark"})))
    # post.save
    # ```
    class JsonType < BaseType
      getter mode : JsonMode

      def initialize(@mode : JsonMode = JsonMode::Json)
      end

      def type_symbol : Symbol
        @mode == JsonMode::Jsonb ? :jsonb : :json
      end

      # Cast external value to JSON::Any
      def cast(value) : Value
        case value
        when JSON::Any
          value
        when Hash
          JSON::Any.new(value.transform_values { |v| to_json_any(v) })
        when Array
          JSON::Any.new(value.map { |v| to_json_any(v) })
        when String
          begin
            JSON.parse(value)
          rescue JSON::ParseException
            # If it's not valid JSON, wrap as a string value
            JSON::Any.new(value)
          end
        when Int32, Int64
          JSON::Any.new(value.to_i64)
        when Float32, Float64
          JSON::Any.new(value.to_f64)
        when Bool
          JSON::Any.new(value)
        when Nil
          JSON::Any.new(nil)
        else
          nil
        end
      end

      # Dump JSON::Any to database format (string)
      def dump(value) : DB::Any
        case value
        when JSON::Any
          value.to_json
        when Hash, Array
          value.to_json
        when String
          # Validate it's valid JSON, or wrap it
          begin
            JSON.parse(value)
            value
          rescue JSON::ParseException
            value.to_json
          end
        when Nil
          nil
        else
          value.to_json
        end
      end

      # Load JSON from database
      def load(value : DB::Any) : Value
        case value
        when String
          begin
            JSON.parse(value)
          rescue JSON::ParseException
            # Return the raw string wrapped in JSON::Any for error recovery
            JSON::Any.new(value)
          end
        when JSON::Any
          value
        when Nil
          nil
        else
          # Try to convert to JSON
          JSON::Any.new(value.to_s)
        end
      end

      # SQL type depends on backend
      def sql_type(dialect : Symbol) : String?
        case dialect
        when :postgres
          @mode == JsonMode::Jsonb ? "JSONB" : "JSON"
        when :sqlite
          "TEXT"
        else
          "TEXT"
        end
      end

      # SQLite CHECK constraint for JSON validation
      def check_constraint(column_name : String) : String?
        # SQLite 3.38+ supports json_valid() function
        "json_valid(\"#{column_name}\")"
      end

      # Deep copy for dirty tracking
      def deep_copy(value)
        case value
        when JSON::Any
          JSON.parse(value.to_json)
        else
          value
        end
      end

      private def to_json_any(value) : JSON::Any
        case value
        when JSON::Any
          value
        when Hash
          JSON::Any.new(value.transform_values { |v| to_json_any(v) })
        when Array
          JSON::Any.new(value.map { |v| to_json_any(v) })
        when String
          JSON::Any.new(value)
        when Int32, Int64
          JSON::Any.new(value.to_i64)
        when Float32, Float64
          JSON::Any.new(value.to_f64)
        when Bool
          JSON::Any.new(value)
        when Nil
          JSON::Any.new(nil)
        else
          JSON::Any.new(value.to_s)
        end
      end
    end

    # Alias for creating a JSONB type
    def self.jsonb_type : JsonType
      JsonType.new(JsonMode::Jsonb)
    end

    # Alias for creating a JSON type
    def self.json_type : JsonType
      JsonType.new(JsonMode::Json)
    end
  end
end

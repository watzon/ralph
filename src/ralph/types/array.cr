require "./base"
require "json"

module Ralph
  module Types
    # Array type with element type awareness
    #
    # ## Backend Behavior
    #
    # - **PostgreSQL**: Uses native array types (TEXT[], INTEGER[], etc.)
    # - **SQLite**: Stores as JSON array in TEXT column
    #
    # ## Example
    #
    # ```crystal
    # # String array
    # type = Ralph::Types::ArrayType(String).new
    # type.dump(["a", "b", "c"])  # => '["a","b","c"]' or '{a,b,c}'
    # type.load('["a","b","c"]')  # => ["a", "b", "c"]
    #
    # # Integer array
    # type = Ralph::Types::ArrayType(Int32).new
    # type.dump([1, 2, 3])        # => '[1,2,3]' or '{1,2,3}'
    # type.load('[1,2,3]')        # => [1, 2, 3]
    # ```
    #
    # ## Usage in Models
    #
    # ```crystal
    # class Post < Ralph::Model
    #   column tags : Array(String)
    #   column scores : Array(Int32)
    # end
    # ```
    class ArrayType(T) < BaseType
      def type_symbol : Symbol
        :array
      end

      # Cast external value to Array(T)
      def cast(value) : Value
        case value
        when Array
          cast_array(value)
        when JSON::Any
          if arr = value.as_a?
            cast_json_array(arr)
          else
            nil
          end
        when String
          # Try to parse as JSON array
          begin
            parsed = JSON.parse(value)
            if arr = parsed.as_a?
              cast_json_array(arr)
            else
              nil
            end
          rescue JSON::ParseException
            # Try PostgreSQL array format: {a,b,c}
            parse_pg_array(value)
          end
        else
          nil
        end
      end

      # Dump Array(T) to database format
      def dump(value) : DB::Any
        case value
        when Array
          # Store as JSON for SQLite compatibility
          # PostgreSQL driver handles Array -> native array conversion
          value.to_json
        else
          nil
        end
      end

      # Load Array from database
      def load(value : DB::Any) : Value
        case value
        when Array
          # Already an array (PostgreSQL native)
          cast_array(value)
        when String
          # Try JSON format first
          begin
            parsed = JSON.parse(value)
            if arr = parsed.as_a?
              cast_json_array(arr)
            else
              nil
            end
          rescue JSON::ParseException
            # Try PostgreSQL array format
            parse_pg_array(value)
          end
        else
          nil
        end
      end

      # SQL type depends on backend and element type
      def sql_type(dialect : Symbol) : String?
        case dialect
        when :postgres
          "#{element_sql_type}[]"
        when :sqlite
          "TEXT" # Stored as JSON
        else
          "TEXT"
        end
      end

      # Check constraint for SQLite (validate JSON array)
      def check_constraint(column_name : String) : String?
        # Validate it's a valid JSON array
        "json_valid(\"#{column_name}\") AND json_type(\"#{column_name}\") = 'array'"
      end

      # Deep copy for dirty tracking
      def deep_copy(value)
        case value
        when Array
          value.dup
        else
          value
        end
      end

      private def element_sql_type : String
        {% if T == String %}
          "TEXT"
        {% elsif T == Int32 %}
          "INTEGER"
        {% elsif T == Int64 %}
          "BIGINT"
        {% elsif T == Float64 %}
          "DOUBLE PRECISION"
        {% elsif T == Float32 %}
          "REAL"
        {% elsif T == Bool %}
          "BOOLEAN"
        {% else %}
          "TEXT"
        {% end %}
      end

      private def cast_array(arr : Array) : Array(T)?
        result = [] of T
        arr.each do |item|
          if element = cast_element(item)
            result << element
          else
            return nil
          end
        end
        result
      end

      private def cast_json_array(arr : Array(JSON::Any)) : Array(T)?
        result = [] of T
        arr.each do |item|
          if element = cast_json_element(item)
            result << element
          else
            return nil
          end
        end
        result
      end

      private def cast_element(item) : T?
        {% if T == String %}
          case item
          when String then item
          else item.to_s
          end
        {% elsif T == Int32 %}
          case item
          when Int32 then item
          when Int64 then item.to_i32
          when String then item.to_i32?
          else nil
          end
        {% elsif T == Int64 %}
          case item
          when Int64 then item
          when Int32 then item.to_i64
          when String then item.to_i64?
          else nil
          end
        {% elsif T == Float64 %}
          case item
          when Float64 then item
          when Float32 then item.to_f64
          when Int32, Int64 then item.to_f64
          when String then item.to_f64?
          else nil
          end
        {% elsif T == Float32 %}
          case item
          when Float32 then item
          when Float64 then item.to_f32
          when Int32, Int64 then item.to_f32
          when String then item.to_f32?
          else nil
          end
        {% elsif T == Bool %}
          case item
          when Bool then item
          when String then item.downcase == "true" || item == "1"
          when Int32, Int64 then item != 0
          else nil
          end
        {% else %}
          item.as?(T)
        {% end %}
      end

      private def cast_json_element(item : JSON::Any) : T?
        {% if T == String %}
          item.as_s? || item.raw.to_s
        {% elsif T == Int32 %}
          item.as_i?
        {% elsif T == Int64 %}
          item.as_i64? || item.as_i?.try(&.to_i64)
        {% elsif T == Float64 %}
          item.as_f? || item.as_i?.try(&.to_f64)
        {% elsif T == Float32 %}
          (item.as_f? || item.as_i?.try(&.to_f64)).try(&.to_f32)
        {% elsif T == Bool %}
          item.as_bool?
        {% else %}
          nil
        {% end %}
      end

      private def parse_pg_array(value : String) : Array(T)?
        return nil unless value.starts_with?("{") && value.ends_with?("}")

        content = value[1...-1]
        return [] of T if content.empty?

        # Simple comma split (doesn't handle quoted strings with commas)
        parts = content.split(",")
        result = [] of T

        parts.each do |part|
          cleaned = part.strip
          # Remove quotes if present
          if cleaned.starts_with?('"') && cleaned.ends_with?('"')
            cleaned = cleaned[1...-1]
          end

          if element = parse_element(cleaned)
            result << element
          else
            return nil
          end
        end

        result
      end

      private def parse_element(part : String) : T?
        {% if T == String %}
          part
        {% elsif T == Int32 %}
          part.to_i32?
        {% elsif T == Int64 %}
          part.to_i64?
        {% elsif T == Float64 %}
          part.to_f64?
        {% elsif T == Float32 %}
          part.to_f32?
        {% elsif T == Bool %}
          part.downcase == "true" || part == "1" || part == "t"
        {% else %}
          nil
        {% end %}
      end
    end

    # Factory methods for common array types
    def self.string_array_type : ArrayType(String)
      ArrayType(String).new
    end

    def self.int_array_type : ArrayType(Int32)
      ArrayType(Int32).new
    end

    def self.bigint_array_type : ArrayType(Int64)
      ArrayType(Int64).new
    end

    def self.float_array_type : ArrayType(Float64)
      ArrayType(Float64).new
    end

    def self.bool_array_type : ArrayType(Bool)
      ArrayType(Bool).new
    end
  end
end

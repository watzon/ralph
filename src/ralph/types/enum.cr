require "./base"

module Ralph
  module Types
    # Enum type that supports multiple storage strategies
    #
    # Crystal enums can be stored in the database using different formats:
    #
    # - **:string** (default) - Store as VARCHAR with enum member name
    # - **:integer** - Store as SMALLINT with enum value
    # - **:native** - Use database ENUM type (PostgreSQL only)
    #
    # ## Example
    #
    # ```crystal
    # enum Status
    #   Active
    #   Inactive
    #   Suspended
    # end
    #
    # # String storage (default)
    # type = Ralph::Types::EnumType(Status).new
    # type.dump(Status::Active)  # => "Active"
    # type.load("Active")        # => Status::Active
    #
    # # Integer storage
    # type = Ralph::Types::EnumType(Status).new(:integer)
    # type.dump(Status::Active)  # => 0
    # type.load(0)               # => Status::Active
    # ```
    #
    # ## Migration
    #
    # ```crystal
    # create_table :users do |t|
    #   t.enum :status, values: ["Active", "Inactive", "Suspended"]
    #   t.enum :priority, values: [1, 2, 3], storage: :integer
    # end
    # ```
    class EnumType(E) < BaseType
      # Storage strategy for the enum
      enum Storage
        String
        Integer
        Native
      end

      getter storage : Storage

      def initialize(storage : Symbol = :string)
        @storage = case storage
                   when :string  then Storage::String
                   when :integer then Storage::Integer
                   when :native  then Storage::Native
                   else               Storage::String
                   end
      end

      def initialize(@storage : Storage = Storage::String)
      end

      def type_symbol : Symbol
        :enum
      end

      # Cast external value to enum (returns serialized form as Value)
      # Note: For enum types, cast returns the string/int representation.
      # The model layer is responsible for converting to the actual enum type.
      def cast(value) : Value
        result = case value
                 when E
                   case @storage
                   when Storage::Integer, Storage::Native
                     value.value.to_i32
                   else
                     value.to_s
                   end
                 when String
                   parsed = parse_string(value)
                   if parsed
                     case @storage
                     when Storage::Integer, Storage::Native
                       parsed.value.to_i32
                     else
                       parsed.to_s
                     end
                   else
                     nil
                   end
                 when Int32
                   parsed = E.from_value?(value)
                   if parsed
                     case @storage
                     when Storage::Integer, Storage::Native
                       value
                     else
                       parsed.to_s
                     end
                   else
                     nil
                   end
                 when Int64
                   parsed = E.from_value?(value.to_i32)
                   if parsed
                     case @storage
                     when Storage::Integer, Storage::Native
                       value.to_i32
                     else
                       parsed.to_s
                     end
                   else
                     nil
                   end
                 when Symbol
                   parsed = parse_string(value.to_s)
                   if parsed
                     case @storage
                     when Storage::Integer, Storage::Native
                       parsed.value.to_i32
                     else
                       parsed.to_s
                     end
                   else
                     nil
                   end
                 else
                   nil
                 end
        result
      end

      # Dump enum to database format
      def dump(value) : DB::Any
        case value
        when E
          case @storage
          when Storage::Integer, Storage::Native
            value.value.to_i32
          else
            value.to_s
          end
        else
          nil
        end
      end

      # Load enum from database (returns serialized form as Value)
      # Note: Returns the DB value as-is for the model layer to parse.
      def load(value : DB::Any) : Value
        # Return the value as-is; model layer will parse it
        case value
        when Int32, Int64, String
          value
        else
          nil
        end
      end

      # SQL type for this enum
      def sql_type(dialect : Symbol) : String?
        case @storage
        when Storage::Native
          # PostgreSQL native ENUM - requires CREATE TYPE first
          "\"#{E.to_s.underscore}_enum\"" if dialect == :postgres
        when Storage::Integer
          "SMALLINT"
        else
          "VARCHAR(50)"
        end
      end

      # Generate CHECK constraint for SQLite
      def check_constraint(column_name : String) : String?
        case @storage
        when Storage::Integer
          values = E.values
          min_val = values.map(&.value).min
          max_val = values.map(&.value).max
          "\"#{column_name}\" >= #{min_val} AND \"#{column_name}\" <= #{max_val}"
        when Storage::String
          allowed = E.values.map { |v| "'#{v.to_s}'" }.join(", ")
          "\"#{column_name}\" IN (#{allowed})"
        else
          nil
        end
      end

      # Get all valid enum values as strings
      def valid_values : Array(String)
        E.values.map(&.to_s)
      end

      # Get all valid enum values as integers
      def valid_int_values : Array(Int32)
        E.values.map(&.value)
      end

      private def parse_string(str : String) : E?
        # Try exact match first
        E.parse?(str) || E.parse?(str.downcase) || E.parse?(str.upcase) || E.parse?(str.camelcase)
      end
    end

    # Factory method to create an enum type for a given enum class
    def self.enum_type(enum_class : E.class, storage : Symbol = :string) : EnumType(E) forall E
      EnumType(E).new(storage)
    end
  end
end

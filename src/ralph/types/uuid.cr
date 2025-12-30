require "./base"
require "uuid"

module Ralph
  module Types
    # UUID type with automatic generation support
    #
    # ## Backend Behavior
    #
    # - **PostgreSQL**: Uses native UUID type (16 bytes, indexed efficiently)
    # - **SQLite**: Stores as CHAR(36) text representation
    #
    # ## Example
    #
    # ```crystal
    # type = Ralph::Types::UuidType.new
    # uuid = UUID.random
    #
    # type.dump(uuid)                           # => "550e8400-e29b-41d4-a716-446655440000"
    # type.load("550e8400-e29b-41d4-a716-446655440000") # => UUID
    # ```
    #
    # ## Auto-Generation
    #
    # ```crystal
    # type = Ralph::Types::UuidType.new(auto_generate: true)
    # type.default_sql(:postgres) # => "gen_random_uuid()"
    # ```
    #
    # ## Usage in Models
    #
    # ```crystal
    # class User < Ralph::Model
    #   column id : UUID, primary: true
    #   column api_key : UUID
    # end
    # ```
    class UuidType < BaseType
      getter auto_generate : Bool

      def initialize(@auto_generate : Bool = false)
      end

      def type_symbol : Symbol
        :uuid
      end

      # Cast external value to UUID
      def cast(value) : Value
        case value
        when UUID
          value
        when String
          parse_uuid(value)
        else
          nil
        end
      end

      # Dump UUID to database format (string)
      def dump(value) : DB::Any
        case value
        when UUID
          value.to_s
        when String
          # Validate and normalize
          if uuid = parse_uuid(value)
            uuid.to_s
          else
            value
          end
        else
          nil
        end
      end

      # Load UUID from database
      def load(value : DB::Any) : Value
        case value
        when UUID
          value
        when String
          parse_uuid(value)
        else
          nil
        end
      end

      # SQL type depends on backend
      def sql_type(dialect : Symbol) : String?
        case dialect
        when :postgres
          "UUID"
        when :sqlite
          "CHAR(36)"
        else
          "CHAR(36)"
        end
      end

      # Default SQL for auto-generation
      def default_sql(dialect : Symbol) : String?
        return nil unless @auto_generate

        case dialect
        when :postgres
          "gen_random_uuid()"
        else
          # SQLite doesn't have native UUID generation
          # Would need application-level generation
          nil
        end
      end

      # Check constraint for SQLite UUID format validation
      def check_constraint(column_name : String) : String?
        # Validate UUID format (8-4-4-4-12 hex pattern)
        pattern = "'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'"
        "\"#{column_name}\" GLOB #{pattern}"
      end

      private def parse_uuid(str : String) : UUID?
        UUID.new(str)
      rescue ArgumentError
        nil
      end
    end

    # Factory method to create a UUID type
    def self.uuid_type(auto_generate : Bool = false) : UuidType
      UuidType.new(auto_generate)
    end
  end
end

require "json"
require "db"
require "uuid"

module Ralph
  module Types
    # Value type that can be stored in the database
    # Extends DB::Any to include advanced types for custom column support
    alias Value = Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | JSON::Any | UUID | Array(String) | Array(Int32) | Array(Int64) | Array(Float64) | Array(Bool) | Nil

    # Base class for all custom types in Ralph
    #
    # Implements three-phase transformation following the Ecto pattern:
    # - **cast**: External input (user data) → Internal (domain type)
    # - **dump**: Internal (domain type) → Database format
    # - **load**: Database format → Internal (domain type)
    #
    # ## Creating Custom Types
    #
    # ```crystal
    # class MoneyType < Ralph::Types::BaseType
    #   def type_symbol : Symbol
    #     :money
    #   end
    #
    #   def cast(value) : Money?
    #     case value
    #     when Money
    #       value
    #     when String
    #       Money.parse(value)
    #     when Int32, Int64, Float64
    #       Money.new(value.to_f64)
    #     else
    #       nil
    #     end
    #   end
    #
    #   def dump(value : Money) : DB::Any
    #     value.cents.to_i64
    #   end
    #
    #   def load(value : DB::Any) : Money?
    #     case value
    #     when Int64
    #       Money.from_cents(value)
    #     else
    #       nil
    #     end
    #   end
    # end
    #
    # # Register the type
    # Ralph::Types::Registry.register(:money, MoneyType.new)
    # ```
    #
    # ## Backend Behavior
    #
    # Types can provide backend-specific SQL type strings via `sql_type`,
    # and SQLite CHECK constraints via `check_constraint` for emulation
    # of types not natively supported.
    abstract class BaseType
      # Database type symbol for migration DSL (e.g., :jsonb, :uuid)
      abstract def type_symbol : Symbol

      # Cast external value to internal type (validation and coercion)
      #
      # Called when assigning values to model attributes from user input.
      # Should handle various input formats (String, Int, JSON, etc.)
      #
      # Returns the casted value, or nil if casting fails.
      abstract def cast(value) : Value

      # Dump internal value to database format
      #
      # Called before INSERT/UPDATE to convert the internal representation
      # to a format the database can store.
      abstract def dump(value) : DB::Any

      # Load value from database and convert to internal type
      #
      # Called after SELECT to convert the raw database value
      # to the internal representation.
      abstract def load(value : DB::Any) : Value

      # Optional: Generate CHECK constraint for SQLite emulation
      #
      # Some types (like ENUM) don't exist in SQLite and need to be
      # emulated with CHECK constraints.
      #
      # Returns nil if no constraint is needed.
      def check_constraint(column_name : String) : String?
        nil
      end

      # Optional: Backend-specific SQL type generation
      #
      # Override this to provide different SQL types for different backends.
      # Returns nil to use the default from the dialect.
      def sql_type(dialect : Symbol) : String?
        nil
      end

      # Optional: Default value for the database
      #
      # Some types (like UUID) can have auto-generated defaults.
      def default_sql(dialect : Symbol) : String?
        nil
      end

      # Whether this type requires special handling in the model macro
      def requires_converter? : Bool
        true
      end

      # Compare two values of this type for equality
      def equal?(a, b) : Bool
        a == b
      end

      # Deep copy a value (for dirty tracking)
      def deep_copy(value)
        value
      end
    end

    # Primitive type wrapper - used for basic types that don't need conversion
    #
    # This is used internally for types like String, Int32, etc. that can
    # be passed directly to the database without transformation.
    class PrimitiveType < BaseType
      getter type_symbol : Symbol

      def initialize(@type_symbol : Symbol)
      end

      def cast(value) : Value
        value.as(Value)
      end

      def dump(value) : DB::Any
        value.as(DB::Any)
      end

      def load(value : DB::Any) : Value
        value.as(Value)
      end

      def requires_converter? : Bool
        false
      end
    end
  end
end

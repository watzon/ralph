# Requires all type modules
require "./base"
require "./registry"
require "./enum"
require "./json"
require "./uuid"
require "./array"

module Ralph
  module Types
    # Initialize and register all built-in types
    #
    # This is called automatically when the types module is loaded.
    # Custom types can be registered at any time using `Registry.register`.
    def self.initialize_built_in_types
      return if Registry.initialized?

      # Register global types (work for all backends)
      Registry.register(:json, JsonType.new(JsonMode::Json))
      Registry.register(:jsonb, JsonType.new(JsonMode::Jsonb))
      Registry.register(:uuid, UuidType.new)

      # Primitive type wrappers
      Registry.register(:string, PrimitiveType.new(:string))
      Registry.register(:text, PrimitiveType.new(:text))
      Registry.register(:integer, PrimitiveType.new(:integer))
      Registry.register(:bigint, PrimitiveType.new(:bigint))
      Registry.register(:float, PrimitiveType.new(:float))
      Registry.register(:decimal, PrimitiveType.new(:decimal))
      Registry.register(:boolean, PrimitiveType.new(:boolean))
      Registry.register(:date, PrimitiveType.new(:date))
      Registry.register(:timestamp, PrimitiveType.new(:timestamp))
      Registry.register(:datetime, PrimitiveType.new(:datetime))
      Registry.register(:binary, PrimitiveType.new(:binary))

      # Array types
      Registry.register(:string_array, ArrayType(String).new)
      Registry.register(:int_array, ArrayType(Int32).new)
      Registry.register(:bigint_array, ArrayType(Int64).new)
      Registry.register(:float_array, ArrayType(Float64).new)
      Registry.register(:bool_array, ArrayType(Bool).new)

      Registry.initialized!
    end

    # Convenience method to get a type by symbol
    def self.get(symbol : Symbol, backend : Symbol = :sqlite) : BaseType?
      initialize_built_in_types
      Registry.lookup(symbol, backend)
    end

    # Convenience method to get a type by symbol, raising if not found
    def self.get!(symbol : Symbol, backend : Symbol = :sqlite) : BaseType
      initialize_built_in_types
      Registry.lookup!(symbol, backend)
    end

    # Register a custom type
    def self.register(symbol : Symbol, type : BaseType)
      Registry.register(symbol, type)
    end

    # Register a custom type for a specific backend
    def self.register_for_backend(backend : Symbol, symbol : Symbol, type : BaseType)
      Registry.register_for_backend(backend, symbol, type)
    end
  end
end

# Auto-initialize types when module is loaded
Ralph::Types.initialize_built_in_types

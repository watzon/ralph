module Ralph
  module Types
    # Centralized type registry with backend-specific registration support
    #
    # The registry allows types to be registered globally or for specific backends.
    # When looking up a type, backend-specific types take priority over global types.
    #
    # ## Global Registration
    #
    # ```
    # Ralph::Types::Registry.register(:money, MoneyType.new)
    # ```
    #
    # ## Backend-Specific Registration
    #
    # ```
    # # Register different implementations for different backends
    # Ralph::Types::Registry.register_for_backend(:postgres, :uuid, PostgresUuidType.new)
    # Ralph::Types::Registry.register_for_backend(:sqlite, :uuid, SqliteUuidType.new)
    # ```
    #
    # ## Lookup
    #
    # ```
    # type = Ralph::Types::Registry.lookup(:uuid, :postgres)
    # ```
    class Registry
      @@types = {} of Symbol => BaseType
      @@backend_types = {} of Symbol => Hash(Symbol, BaseType)
      @@initialized = false

      # Register a type globally (works for all backends)
      def self.register(symbol : Symbol, type : BaseType)
        @@types[symbol] = type
      end

      # Register type for specific backend only
      def self.register_for_backend(backend : Symbol, type_symbol : Symbol, type : BaseType)
        @@backend_types[backend] ||= {} of Symbol => BaseType
        @@backend_types[backend][type_symbol] = type
      end

      # Lookup type by symbol (checks backend-specific first)
      def self.lookup(symbol : Symbol, backend : Symbol = :sqlite) : BaseType?
        # Check backend-specific first
        if backend_types = @@backend_types[backend]?
          if type = backend_types[symbol]?
            return type
          end
        end

        # Fall back to global
        @@types[symbol]?
      end

      # Lookup type by symbol, raising if not found
      def self.lookup!(symbol : Symbol, backend : Symbol = :sqlite) : BaseType
        lookup(symbol, backend) || raise ArgumentError.new("Unknown type: #{symbol}")
      end

      # Check if type exists
      def self.registered?(symbol : Symbol, backend : Symbol? = nil) : Bool
        if backend
          if backend_types = @@backend_types[backend]?
            return true if backend_types.has_key?(symbol)
          end
        end

        @@types.has_key?(symbol)
      end

      # List all registered types
      def self.all_types(backend : Symbol? = nil) : Array(Symbol)
        result = @@types.keys.to_a

        if backend && (backend_types = @@backend_types[backend]?)
          result = result | backend_types.keys.to_a
        end

        result
      end

      # Clear all types (useful for testing)
      def self.clear!
        @@types.clear
        @@backend_types.clear
        @@initialized = false
      end

      # Check if types have been initialized
      def self.initialized? : Bool
        @@initialized
      end

      # Mark types as initialized
      def self.initialized!
        @@initialized = true
      end

      # Get all global types
      def self.global_types : Hash(Symbol, BaseType)
        @@types
      end

      # Get all backend-specific types
      def self.backend_types : Hash(Symbol, Hash(Symbol, BaseType))
        @@backend_types
      end
    end
  end
end

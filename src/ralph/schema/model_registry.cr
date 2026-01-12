# Model Registry for db:generate
#
# Tracks all Ralph model classes to enable schema comparison
# between model definitions and database schema.

module Ralph
  module Schema
    # Storage for registered model classes
    @@registered_models = [] of Ralph::Model.class

    # Register a model class
    # NOTE: This runtime registration has timing issues with macro finished.
    # Use ModelSchemaExtractor.extract_all which uses compile-time discovery instead.
    def self.register_model(model_class : Ralph::Model.class)
      @@registered_models << model_class unless @@registered_models.includes?(model_class)
    end

    # Get all registered model classes
    def self.registered_models : Array(Ralph::Model.class)
      @@registered_models
    end

    # Clear registry (useful for testing)
    def self.clear_registry
      @@registered_models.clear
    end
  end
end

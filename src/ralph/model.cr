module Ralph
  # Metadata about a column
  class ColumnMetadata
    property name : String
    property type_name : String
    property primary : Bool
    property default : String | Int32 | Int64 | Float64 | Bool | Nil
    property nilable : Bool

    def initialize(@name : String, type : Class, @primary : Bool = false, @default : String | Int32 | Int64 | Float64 | Bool | Nil = nil, @nilable : Bool = false)
      @type_name = type.to_s
    end
  end

  # Base class for all ORM models
  #
  # Models should inherit from this class and define their columns
  # using the `column` macro.
  abstract class Model
    include Ralph::Validations
    include Ralph::Callbacks
    include Ralph::Associations
    include Ralph::BulkOperations

    # When a subclass is defined, set up callbacks and validations after parsing completes
    macro inherited
      macro finished
        # Generate save method with callbacks
        def save : Bool
          # Run before_validation callbacks
          \{% for meth in @type.methods %}
            \{% if meth.annotation(Ralph::Callbacks::BeforeValidation) %}
              \{% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
              \{% if options %}
                \{% if_method = options[:if] %}
                \{% unless_method = options[:unless] %}
                \{% if if_method && unless_method %}
                  if \{{if_method.id}} && !\{{unless_method.id}}
                    \{{meth.name}}
                  end
                \{% elsif if_method %}
                  if \{{if_method.id}}
                    \{{meth.name}}
                  end
                \{% elsif unless_method %}
                  unless \{{unless_method.id}}
                    \{{meth.name}}
                  end
                \{% else %}
                  \{{meth.name}}
                \{% end %}
              \{% else %}
                \{{meth.name}}
              \{% end %}
            \{% end %}
          \{% end %}

          # Run validations
          is_valid = valid?

          # Run after_validation callbacks
          \{% for meth in @type.methods %}
            \{% if meth.annotation(Ralph::Callbacks::AfterValidation) %}
              \{% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
              \{% if options %}
                \{% if_method = options[:if] %}
                \{% unless_method = options[:unless] %}
                \{% if if_method && unless_method %}
                  if \{{if_method.id}} && !\{{unless_method.id}}
                    \{{meth.name}}
                  end
                \{% elsif if_method %}
                  if \{{if_method.id}}
                    \{{meth.name}}
                  end
                \{% elsif unless_method %}
                  unless \{{unless_method.id}}
                    \{{meth.name}}
                  end
                \{% else %}
                  \{{meth.name}}
                \{% end %}
              \{% else %}
                \{{meth.name}}
              \{% end %}
            \{% end %}
          \{% end %}

          # Return false if validations failed
          return false unless is_valid

          # Run before_save callbacks
          \{% for meth in @type.methods %}
            \{% if meth.annotation(Ralph::Callbacks::BeforeSave) %}
              \{% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
              \{% if options %}
                \{% if_method = options[:if] %}
                \{% unless_method = options[:unless] %}
                \{% if if_method && unless_method %}
                  if \{{if_method.id}} && !\{{unless_method.id}}
                    \{{meth.name}}
                  end
                \{% elsif if_method %}
                  if \{{if_method.id}}
                    \{{meth.name}}
                  end
                \{% elsif unless_method %}
                  unless \{{unless_method.id}}
                    \{{meth.name}}
                  end
                \{% else %}
                  \{{meth.name}}
                \{% end %}
              \{% else %}
                \{{meth.name}}
              \{% end %}
            \{% end %}
          \{% end %}

          # Run timestamp before_save hook (if timestamps macro was used)
          \{% for meth in @type.methods %}
            \{% if meth.name == "_ralph_timestamp_before_save" %}
              _ralph_timestamp_before_save
            \{% end %}
          \{% end %}

          result = if new_record?
            # Run before_create callbacks
            \{% for meth in @type.methods %}
              \{% if meth.annotation(Ralph::Callbacks::BeforeCreate) %}
                \{% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
                \{% if options %}
                  \{% if_method = options[:if] %}
                  \{% unless_method = options[:unless] %}
                  \{% if if_method && unless_method %}
                    if \{{if_method.id}} && !\{{unless_method.id}}
                      \{{meth.name}}
                    end
                  \{% elsif if_method %}
                    if \{{if_method.id}}
                      \{{meth.name}}
                    end
                  \{% elsif unless_method %}
                    unless \{{unless_method.id}}
                      \{{meth.name}}
                    end
                  \{% else %}
                    \{{meth.name}}
                  \{% end %}
                \{% else %}
                  \{{meth.name}}
                \{% end %}
              \{% end %}
            \{% end %}

            # Run timestamp before_create hook (if timestamps macro was used)
            \{% for meth in @type.methods %}
              \{% if meth.name == "_ralph_timestamp_before_create" %}
                _ralph_timestamp_before_create
              \{% end %}
            \{% end %}

            insert_result = insert

            if insert_result
              # Run after_create callbacks
              \{% for meth in @type.methods %}
                \{% if meth.annotation(Ralph::Callbacks::AfterCreate) %}
                  \{% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
                  \{% if options %}
                    \{% if_method = options[:if] %}
                    \{% unless_method = options[:unless] %}
                    \{% if if_method && unless_method %}
                      if \{{if_method.id}} && !\{{unless_method.id}}
                        \{{meth.name}}
                      end
                    \{% elsif if_method %}
                      if \{{if_method.id}}
                        \{{meth.name}}
                      end
                    \{% elsif unless_method %}
                      unless \{{unless_method.id}}
                        \{{meth.name}}
                      end
                    \{% else %}
                      \{{meth.name}}
                    \{% end %}
                  \{% else %}
                    \{{meth.name}}
                  \{% end %}
                \{% end %}
              \{% end %}
            end

            insert_result
          else
            # Run before_update callbacks
            \{% for meth in @type.methods %}
              \{% if meth.annotation(Ralph::Callbacks::BeforeUpdate) %}
                \{% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
                \{% if options %}
                  \{% if_method = options[:if] %}
                  \{% unless_method = options[:unless] %}
                  \{% if if_method && unless_method %}
                    if \{{if_method.id}} && !\{{unless_method.id}}
                      \{{meth.name}}
                    end
                  \{% elsif if_method %}
                    if \{{if_method.id}}
                      \{{meth.name}}
                    end
                  \{% elsif unless_method %}
                    unless \{{unless_method.id}}
                      \{{meth.name}}
                    end
                  \{% else %}
                    \{{meth.name}}
                  \{% end %}
                \{% else %}
                  \{{meth.name}}
                \{% end %}
              \{% end %}
            \{% end %}

            update_result = update_record

            if update_result
              # Run after_update callbacks
              \{% for meth in @type.methods %}
                \{% if meth.annotation(Ralph::Callbacks::AfterUpdate) %}
                  \{% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
                  \{% if options %}
                    \{% if_method = options[:if] %}
                    \{% unless_method = options[:unless] %}
                    \{% if if_method && unless_method %}
                      if \{{if_method.id}} && !\{{unless_method.id}}
                        \{{meth.name}}
                      end
                    \{% elsif if_method %}
                      if \{{if_method.id}}
                        \{{meth.name}}
                      end
                    \{% elsif unless_method %}
                      unless \{{unless_method.id}}
                        \{{meth.name}}
                      end
                    \{% else %}
                      \{{meth.name}}
                    \{% end %}
                  \{% else %}
                    \{{meth.name}}
                  \{% end %}
                \{% end %}
              \{% end %}
            end

            update_result
          end

          if result
            # Run after_save callbacks
            \{% for meth in @type.methods %}
              \{% if meth.annotation(Ralph::Callbacks::AfterSave) %}
                \{% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
                \{% if options %}
                  \{% if_method = options[:if] %}
                  \{% unless_method = options[:unless] %}
                  \{% if if_method && unless_method %}
                    if \{{if_method.id}} && !\{{unless_method.id}}
                      \{{meth.name}}
                    end
                  \{% elsif if_method %}
                    if \{{if_method.id}}
                      \{{meth.name}}
                    end
                  \{% elsif unless_method %}
                    unless \{{unless_method.id}}
                      \{{meth.name}}
                    end
                  \{% else %}
                    \{{meth.name}}
                  \{% end %}
                \{% else %}
                  \{{meth.name}}
                \{% end %}
              \{% end %}
            \{% end %}
          end

          result
        end

        # Generate destroy method with callbacks
        # Skip if paranoid macro is used (it defines its own destroy method)
        \{% unless @type.has_constant?("PARANOID_MODE") %}
        def destroy : Bool
          return false if new_record?

          # Run before_destroy callbacks
          \{% for meth in @type.methods %}
            \{% if meth.annotation(Ralph::Callbacks::BeforeDestroy) %}
              \{% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
              \{% if options %}
                \{% if_method = options[:if] %}
                \{% unless_method = options[:unless] %}
                \{% if if_method && unless_method %}
                  if \{{if_method.id}} && !\{{unless_method.id}}
                    \{{meth.name}}
                  end
                \{% elsif if_method %}
                  if \{{if_method.id}}
                    \{{meth.name}}
                  end
                \{% elsif unless_method %}
                  unless \{{unless_method.id}}
                    \{{meth.name}}
                  end
                \{% else %}
                  \{{meth.name}}
                \{% end %}
              \{% else %}
                \{{meth.name}}
              \{% end %}
            \{% end %}
          \{% end %}

          # Handle dependent associations before destroying this record
          # Look for _handle_dependent_* methods generated by association macros
          \{% for meth in @type.methods %}
            \{% if meth.name.starts_with?("_handle_dependent_") %}
              unless \{{meth.name}}
                return false
              end
            \{% end %}
          \{% end %}

          query = Ralph::Query::Builder.new(self.class.table_name)

          # Build WHERE clause for all primary keys (supports composite keys)
          pk_values = primary_key_values
          pk_values.each do |pk_name, pk_val|
            query = query.where("#{pk_name} = ?", pk_val)
          end

          sql, args = query.build_delete
          Ralph.database.execute(sql, args: args)
          result = true

          # Invalidate query cache for this table if auto-invalidation is enabled
          if Ralph.settings.query_cache_auto_invalidate
            Ralph::Query::Builder.invalidate_table_cache(self.class.table_name)
          end

          # Remove from identity map
          Ralph::IdentityMap.remove(self)

          if result
            # Run after_destroy callbacks
            \{% for meth in @type.methods %}
              \{% if meth.annotation(Ralph::Callbacks::AfterDestroy) %}
                \{% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
                \{% if options %}
                  \{% if_method = options[:if] %}
                  \{% unless_method = options[:unless] %}
                  \{% if if_method && unless_method %}
                    if \{{if_method.id}} && !\{{unless_method.id}}
                      \{{meth.name}}
                    end
                  \{% elsif if_method %}
                    if \{{if_method.id}}
                      \{{meth.name}}
                    end
                  \{% elsif unless_method %}
                    unless \{{unless_method.id}}
                      \{{meth.name}}
                    end
                  \{% else %}
                    \{{meth.name}}
                  \{% end %}
                \{% else %}
                  \{{meth.name}}
                \{% end %}
              \{% end %}
            \{% end %}
          end

          result
        end
        \{% end %}

        # Generate valid? method that calls all validation methods
        def valid? : Bool
          errors.clear

          # Call each validation method (generated by validates_* macros)
          \{% for meth in @type.methods %}
            \{% if meth.name.starts_with?("_ralph_validate_") %}
              \{{meth.name}}
            \{% end %}
          \{% end %}

          # Also call custom validation methods marked with the annotation
          \{% for meth in @type.methods %}
            \{% if meth.annotation(Ralph::Validations::ValidationMethod) %}
              \{{meth.name}}
            \{% end %}
          \{% end %}

          errors.empty?
        end

        # Generate preload dispatcher for all associations
        _generate_preload_dispatcher

        # Generate instance method for nested preloading
        _generate_preload_on_class

        # Register model with schema registry for db:generate discovery
        Ralph::Schema.register_model(\{{@type}})
      end
    end

    @@table_name : String = ""
    @@columns : Hash(String, ColumnMetadata) = {} of String => ColumnMetadata
    @@primary_key : String = "id"
    @@primary_key_type : String = "Int64"
    @@primary_keys : Array(String) = [] of String

    # Default primary key type alias (Int64) - overridden by column macro when primary: true
    # This allows associations to reference Model::PrimaryKeyType at compile time
    alias PrimaryKeyType = Int64

    # Dirty tracking instance variables
    @_changed_attributes : Set(String) = Set(String).new
    @_original_attributes : Hash(String, DB::Any) = {} of String => DB::Any

    # Persistence tracking - true once record has been saved to database
    # This is separate from checking PK because non-auto PKs (like UUID)
    # can be set before the record is actually persisted
    @_persisted : Bool = false

    # Preloaded associations tracking
    # Stores preloaded single records (belongs_to, has_one)
    @_preloaded_one : Hash(String, Model?) = Hash(String, Model?).new
    # Stores preloaded collections (has_many)
    @_preloaded_many : Hash(String, Array(Model)) = Hash(String, Array(Model)).new
    # Tracks which associations have been preloaded
    @_preloaded_associations : Set(String) = Set(String).new

    # Set the table name for this model
    macro table(name)
      @@table_name = {{name.id.stringify}}
    end

    # Define a column on the model
    #
    # Supports two syntaxes:
    #   column id : Int64, primary: true           # Type declaration syntax (preferred)
    #   column id, Int64, primary: true            # Legacy positional syntax
    #
    # Type declarations control nullability:
    #   column name : String      # Non-nullable: getter returns String (raises if nil)
    #   column bio : String?      # Nullable: getter returns String?
    #   column age : Int32 | Nil  # Nullable: getter returns Int32 | Nil
    #
    # Options:
    #   primary: true   - Mark as primary key
    #   default: value  - Default value for new records
    macro column(decl_or_name, type = nil, primary = false, default = nil)
      # Handle type declaration syntax: column id : Int64
      {% if decl_or_name.is_a?(TypeDeclaration) %}
        {% col_name = decl_or_name.var %}
        {% col_type = decl_or_name.type %}
        {% col_default = decl_or_name.value || default %}
      {% else %}
        # Legacy positional syntax: column id, Int64
        {% col_name = decl_or_name %}
        {% col_type = type %}
        {% col_default = default %}
      {% end %}

      # Detect if the declared type is nilable (String?, Int32 | Nil, etc.)
      # We check the string representation since resolve doesn't work reliably in all contexts.
      # Each pattern is designed to match only Nil type references, not types containing "Nil" as substring:
      #   - ends_with?("?")    → "String?" shorthand syntax
      #   - includes?("| Nil") → "Int32 | Nil" union with space
      #   - includes?("Nil |") → "Nil | Int32" union (Nil first)
      #   - includes?("Nil)")  → "::Union(Time, Nil)" macro expansion
      #   - includes?("Nil,")  → "::Union(Nil, Time)" macro expansion
      #   - includes?("::Nil") → "Int64 | ::Nil" fully qualified
      #   - == "Nil"           → Exactly "Nil" type
      {% col_type_str = col_type.stringify %}
      {% is_nilable = col_type_str.ends_with?("?") ||
                      col_type_str.includes?("| Nil") ||
                      col_type_str.includes?("Nil |") ||
                      col_type_str.includes?("Nil)") ||
                      col_type_str.includes?("Nil,") ||
                      col_type_str.includes?("::Nil") ||
                      col_type_str == "Nil" %}

      # Extract the base type (without Nil) for non-nilable declarations
      # For nilable types, we keep the full type including Nil
      {% if is_nilable %}
        {% base_type = col_type %}
      {% else %}
        {% base_type = col_type %}
      {% end %}

      {% if primary %}
        @@primary_key = {{col_name.stringify}}
        # Track primary key type for association foreign key inference
        @@primary_key_type = {{col_type.stringify}}
        # Add to primary_keys array for composite key support
        @@primary_keys << {{col_name.stringify}} unless @@primary_keys.includes?({{col_name.stringify}})

        # Create type alias for associations to reference at compile time
        # This allows belongs_to/has_many to infer foreign key types automatically
        # Only define if not already defined by parent class with same type
        {% unless @type.has_constant?("PRIMARY_KEY_TYPE_DEFINED") %}
          PRIMARY_KEY_TYPE_DEFINED = true
          alias PrimaryKeyType = {{col_type}}
        {% end %}
      {% end %}

      # Skip if column already defined (prevents duplicate definitions from polymorphic associations)
      {% unless @type.has_constant?("_RALPH_COL_#{col_name.id.upcase}") %}
        # Mark this column as defined to prevent duplicates
        _RALPH_COL_{{col_name.id.upcase}} = true

        # Register column metadata with nullability info
        @@columns[{{col_name.stringify}}] = Ralph::ColumnMetadata.new({{col_name.stringify}}, {{base_type}}, {{primary}}, {{col_default}}, {{is_nilable}})

        # Define the property with nilable type internally to allow uninitialized state
        @{{col_name}} : {{col_type}} | Nil

        # Getter - return type depends on declared nullability
        {% if is_nilable %}
          # Nullable column: return the nilable type directly
          def {{col_name}} : {{col_type}}
            {% if col_default %}
              # Use explicit nil check to handle false/0 values correctly
              if @{{col_name}}.nil?
                @{{col_name}} = {{col_default}}
              end
              @{{col_name}}
            {% else %}
              @{{col_name}}
            {% end %}
          end
        {% else %}
          # Non-nullable column: return non-nil type, raise if accessed before set
          def {{col_name}} : {{col_type}}
            {% if col_default %}
              # Use explicit nil check to handle false/0 values correctly
              if @{{col_name}}.nil?
                @{{col_name}} = {{col_default}}
              end
              @{{col_name}}.not_nil!
            {% else %}
              if (val = @{{col_name}}).nil?
                raise NilAssertionError.new("Column '{{col_name}}' is nil but declared as non-nullable {{col_type}}. Ensure the value is set before accessing.")
              else
                val
              end
            {% end %}
          end

          # Also provide a nilable accessor for cases where nil-check is desired
          def {{col_name}}? : {{col_type}} | Nil
            @{{col_name}}
          end
        {% end %}

        # Setter
        def {{col_name}}=(value : {{col_type}} | Nil)
          @{{col_name}} = value
        end
      {% end %}
    end

    # Get the table name for this model
    def self.table_name : String
      @@table_name
    end

    # Get the primary key field name
    def self.primary_key : String
      @@primary_key
    end

    # Get the primary key type as a string (e.g., "Int64", "UUID", "String")
    def self.primary_key_type : String
      @@primary_key_type
    end

    # Get all primary key field names (for composite keys)
    def self.primary_keys : Array(String)
      @@primary_keys.empty? ? [@@primary_key] : @@primary_keys
    end

    # Check if this model has a composite primary key
    def self.composite_primary_key? : Bool
      @@primary_keys.size > 1
    end

    # Get all column metadata
    def self.columns : Hash(String, ColumnMetadata)
      @@columns
    end

    # Get column names in the order they should be read from result sets.
    # This matches the order of instance variables in from_result_set.
    # Generated at compile time to ensure consistency.
    def self.column_names_ordered : Array(String)
      {% begin %}
        [
          {% for ivar in @type.instance_vars %}
            {% unless ivar.name.starts_with?("_") %}
              {{ivar.name.stringify}},
            {% end %}
          {% end %}
        ]
      {% end %}
    end

    # Get fully-qualified, aliased column expressions for SELECT queries.
    #
    # Returns columns in the format: `"table_name"."column_name" AS "column_name"`
    #
    # This is the safest way to select columns for model hydration because:
    # - Explicit table qualification prevents ambiguity in JOINs
    # - Explicit aliasing ensures column names in ResultSet match model expectations
    # - Column order matches `column_names_ordered` for `from_result_set`
    #
    # ## Example
    #
    # ```
    # User.select_list_sql
    # # => ["\"users\".\"id\" AS \"id\"", "\"users\".\"name\" AS \"name\"", ...]
    # ```
    def self.select_list_sql : Array(String)
      column_names_ordered.map { |col| %("#{table_name}"."#{col}" AS "#{col}") }
    end

    # Create a base query builder with columns selected in the correct order
    # for from_result_set to read them properly. This ensures column order
    # matches instance variable order regardless of database schema order.
    protected def self.base_query : Ralph::Query::Builder
      Ralph::Query::Builder.new(self.table_name).select(column_names_ordered)
    end

    # Find a record by ID
    #
    # When an IdentityMap is active, returns the cached instance if available.
    def self.find(id)
      # Check identity map first
      if cached = Ralph::IdentityMap.get(self, id)
        return cached
      end

      query = base_query.where("#{@@primary_key} = ?", id)

      result = Ralph.database.query_one(query.build_select, args: query.where_args)
      return nil unless result

      record = from_result_set(result)
      result.close

      # Store in identity map
      Ralph::IdentityMap.set(record) if record
      record
    end

    # Find all records
    def self.all : Array(self)
      query = base_query
      results = Ralph.database.query_all(query.build_select)

      records = [] of self
      results.each do
        records << from_result_set(results)
      end
      records
    ensure
      results.close if results
    end

    # Get a query builder for this model
    def self.query : Ralph::Query::Builder
      Ralph::Query::Builder.new(self.table_name)
    end

    # Find records matching conditions
    # The block receives a Builder and should return the modified Builder
    # (since Builder is immutable, each method returns a new instance)
    def self.query(&block : Ralph::Query::Builder -> Ralph::Query::Builder) : Ralph::Query::Builder
      query = Ralph::Query::Builder.new(self.table_name)
      block.call(query)
    end

    # Find records matching conditions (alias for query)
    def self.with_query(&block : Ralph::Query::Builder -> Ralph::Query::Builder) : Ralph::Query::Builder
      query(&block)
    end

    # ========================================
    # Query Scopes
    # ========================================

    # Define a named scope for this model
    #
    # Scopes are reusable query fragments that can be chained together.
    # They're defined as class methods that return Ralph::Query::Builder instances.
    #
    # The block receives a Ralph::Query::Builder and should return it after applying conditions.
    #
    # Example without arguments:
    # ```
    # class User < Ralph::Model
    #   table "users"
    #   column id, Int64, primary: true
    #   column active, Bool
    #   column age, Int32
    #
    #   scope :active, ->(q : Ralph::Query::Builder) { q.where("active = ?", true) }
    #   scope :adults, ->(q : Ralph::Query::Builder) { q.where("age >= ?", 18) }
    # end
    #
    # User.active                    # Returns Builder with active = true
    # User.active.merge(User.adults) # Chains scopes together
    # User.active.limit(10)          # Chains with other query methods
    # ```
    #
    # Example with arguments:
    # ```
    # class User < Ralph::Model
    #   scope :older_than, ->(q : Ralph::Query::Builder, age : Int32) { q.where("age > ?", age) }
    #   scope :with_role, ->(q : Ralph::Query::Builder, role : String) { q.where("role = ?", role) }
    # end
    #
    # User.older_than(21)
    # User.with_role("admin").merge(User.older_than(18))
    # ```
    macro scope(name, block)
      {% if block.args.size == 1 %}
        # Scope without extra arguments (just the query builder)
        # The first block arg is the query builder variable name
        # Since Builder is immutable, the block body returns the modified builder
        {% query_arg = block.args[0] %}
        {% query_var_name = query_arg.is_a?(TypeDeclaration) ? query_arg.var : query_arg %}
        def self.{{name.id}} : Ralph::Query::Builder
          # Pre-select columns in model order to ensure consistent reading
          {{query_var_name.id}} = Ralph::Query::Builder.new(self.table_name).select(column_names_ordered)
          {{block.body}}
        end
      {% else %}
        # Scope with arguments (first arg is query builder, rest are user args)
        # Since Builder is immutable, the block body returns the modified builder
        {% query_arg = block.args[0] %}
        {% query_var_name = query_arg.is_a?(TypeDeclaration) ? query_arg.var : query_arg %}
        {% user_args = block.args[1..-1] %}
        def self.{{name.id}}(
          {% for arg, idx in user_args %}
            {% if arg.is_a?(TypeDeclaration) %}
              __scope_arg_{{idx}}__ : {{arg.type}}{% if idx < user_args.size - 1 %},{% end %}
            {% else %}
              __scope_arg_{{idx}}__{% if idx < user_args.size - 1 %},{% end %}
            {% end %}
          {% end %}
        ) : Ralph::Query::Builder
          # Pre-select columns in model order to ensure consistent reading
          {{query_var_name.id}} = Ralph::Query::Builder.new(self.table_name).select(column_names_ordered)
          # Assign scope args to their expected names
          {% for arg, idx in user_args %}
            {% if arg.is_a?(TypeDeclaration) %}
              {{arg.var.id}} = __scope_arg_{{idx}}__
            {% else %}
              {{arg.id}} = __scope_arg_{{idx}}__
            {% end %}
          {% end %}
          {{block.body}}
        end
      {% end %}
    end

    # Apply an inline/anonymous scope to a query
    #
    # This is useful for one-off query customizations that don't need
    # to be defined as named scopes.
    #
    # The block receives a Builder and should return the modified Builder
    # (since Builder is immutable, each method returns a new instance)
    #
    # Example:
    # ```
    # User.scoped { |q| q.where("active = ?", true).order("name", :asc) }
    # User.scoped { |q| q.where("age > ?", 18) }.limit(10)
    # ```
    def self.scoped(&block : Ralph::Query::Builder -> Ralph::Query::Builder) : Ralph::Query::Builder
      query = Ralph::Query::Builder.new(self.table_name)
      block.call(query)
    end

    # Build a query with GROUP BY clause
    def self.group_by(*columns : String) : Ralph::Query::Builder
      Ralph::Query::Builder.new(self.table_name).group(*columns)
    end

    # Build a query with GROUP BY clause and block
    # The block receives a Builder and should return the modified Builder
    def self.group_by(*columns : String, &block : Ralph::Query::Builder -> Ralph::Query::Builder) : Ralph::Query::Builder
      query = Ralph::Query::Builder.new(self.table_name).group(*columns)
      block.call(query)
    end

    # Build a query with DISTINCT
    def self.distinct : Ralph::Query::Builder
      Ralph::Query::Builder.new(self.table_name).distinct
    end

    # Build a query with DISTINCT and block
    # The block receives a Builder and should return the modified Builder
    def self.distinct(&block : Ralph::Query::Builder -> Ralph::Query::Builder) : Ralph::Query::Builder
      query = Ralph::Query::Builder.new(self.table_name).distinct
      block.call(query)
    end

    # Build a query with DISTINCT on specific columns
    def self.distinct(*columns : String) : Ralph::Query::Builder
      Ralph::Query::Builder.new(self.table_name).distinct(*columns)
    end

    # Build a query with DISTINCT on specific columns and block
    # The block receives a Builder and should return the modified Builder
    def self.distinct(*columns : String, &block : Ralph::Query::Builder -> Ralph::Query::Builder) : Ralph::Query::Builder
      query = Ralph::Query::Builder.new(self.table_name).distinct(*columns)
      block.call(query)
    end

    # Join an association by name
    #
    # This method looks up the association metadata and automatically
    # generates the appropriate join condition.
    #
    # Example:
    # ```
    # User.join_assoc(:posts)              # INNER JOIN posts ON posts.user_id = users.id
    # Post.join_assoc(:author, :left)      # LEFT JOIN users ON users.id = posts.user_id
    # User.join_assoc(:posts, :inner, "p") # INNER JOIN posts AS p ON p.user_id = users.id
    # ```
    def self.join_assoc(association_name : Symbol, join_type : Symbol = :inner, alias as_alias : String? = nil) : Ralph::Query::Builder
      query = Ralph::Query::Builder.new(self.table_name)

      # Get association metadata for this model
      type_str = self.to_s
      associations = Ralph::Associations.associations[type_str]?

      unless associations
        raise "No associations found for model #{type_str}"
      end

      # Find the specific association
      assoc_key = association_name.to_s
      association = associations[assoc_key]?

      unless association
        raise "Unknown association: #{association_name} for model #{type_str}"
      end

      # Build the join condition based on association type
      # Use the table_name from association metadata
      table_name = association.table_name
      foreign_key = association.foreign_key

      on_clause = if association.type == :belongs_to
                    # For belongs_to: associated_table.id = self_table.foreign_key
                    "\"#{table_name}\".\"id\" = \"#{self.table_name}\".\"#{foreign_key}\""
                  else
                    # For has_one/has_many: associated_table.foreign_key = self_table.id
                    "\"#{table_name}\".\"#{foreign_key}\" = \"#{self.table_name}\".\"id\""
                  end

      query.join(table_name, on_clause, join_type, as_alias)
    end

    # ========================================
    # Eager Loading / Preloading
    # ========================================

    # Preload associations on an existing collection of models
    #
    # This uses the preloading strategy (separate queries with IN batching).
    # Useful when you already have a collection and want to preload associations.
    #
    # Example:
    # ```
    # authors = Author.all
    # Author.preload(authors, :posts)
    # authors.each { |a| a.posts } # Already loaded, no additional queries
    #
    # # Multiple associations
    # Author.preload(authors, [:posts, :profile])
    #
    # # Nested associations
    # Author.preload(authors, {posts: :comments})
    # ```
    def self.preload(models : Array(self), associations : Symbol) : Array(self)
      _preload_association(models, associations)
      models
    end

    def self.preload(models : Array(self), associations : Array(Symbol)) : Array(self)
      associations.each { |assoc| _preload_association(models, assoc) }
      models
    end

    def self.preload(models : Array(self), associations : Hash(Symbol, T)) : Array(self) forall T
      _preload_nested(models, associations)
      models
    end

    # Macro to generate dispatch method for preloading associations
    # This is called at compile time to generate a case statement that dispatches
    # to the correct _preload_<name> method for each association
    macro _generate_preload_dispatcher
      protected def self._preload_association(models : Array(self), association : Symbol) : Nil
        return if models.empty?

        # Look up the preload method by association name
        # The preload methods are generated by the association macros as _preload_<name>
        {% methods = @type.class.methods.select { |m| m.name.starts_with?("_preload_") } %}
        {% if methods.size > 0 %}
          case association.to_s
          {% for method in methods %}
            {% assoc_name = method.name.stringify.gsub(/^_preload_/, "") %}
            when {{assoc_name}}
              {{method.name}}(models)
          {% end %}
          else
            # Unknown association, ignore
          end
        {% end %}
      end
    end

    # Internal helper to preload nested associations
    private def self._preload_nested(models : Array(self), associations : Hash(Symbol, T)) : Nil forall T
      associations.each do |assoc, nested|
        _preload_association(models, assoc)

        # Get the preloaded associated records for nested preloading
        associated_records = [] of Model
        models.each do |model|
          if many = model._get_preloaded_many(assoc.to_s)
            associated_records.concat(many)
          elsif one = model._get_preloaded_one(assoc.to_s)
            associated_records << one
          end
        end

        next if associated_records.empty?

        # Dispatch nested preloading based on the nested type
        case nested
        when Symbol
          _preload_nested_on_records(associated_records, nested)
        when Hash
          nested.as(Hash).each do |nested_assoc, further_nested|
            _preload_nested_on_records(associated_records, nested_assoc.as(Symbol))
          end
        end
      end
    end

    # Preload associations on records of potentially different types
    private def self._preload_nested_on_records(records : Array(Model), assoc : Symbol) : Nil
      # Group records by class
      by_class = records.group_by(&.class)
      by_class.each do |klass, class_records|
        # Try to find a _preload method on the class
        # This requires runtime dispatch, which we handle via a generated method
        class_records.first._preload_on_class(class_records, assoc)
      end
    end

    # Instance method to dispatch preloading on this class
    # Used for nested preloading when we have Array(Model) but need to call
    # class-specific preload methods
    # Base implementation - subclasses override this via macro
    def _preload_on_class(records : Array(Ralph::Model), assoc : Symbol) : Nil
      # Default does nothing - subclasses implement this
    end

    # This is a macro that generates a proper typed method in subclasses
    macro _generate_preload_on_class
      def _preload_on_class(records : Array(Ralph::Model), assoc : Symbol) : Nil
        typed_records = records.compact_map { |r| r.as?({{@type}}) }.compact
        return if typed_records.empty?
        {{@type}}._preload_association(typed_records, assoc)
      end
    end

    # Helper for preloading - fetch all records matching a query
    # This is called by the generated _preload_* methods
    def self._preload_fetch_all(query : Ralph::Query::Builder) : Array(self)
      # Ensure we select columns in the correct order for from_result_set
      query = query.select(column_names_ordered) if query.selects.empty?
      results = Ralph.database.query_all(query.build_select, args: query.where_args)
      records = [] of self
      results.each do
        records << from_result_set(results)
      end
      records
    ensure
      results.close if results
    end

    # Find the first record matching conditions
    def self.first : self?
      query = base_query
        .limit(1)
        .order(@@primary_key, :asc)

      result = Ralph.database.query_one(query.build_select)
      return nil unless result

      record = from_result_set(result)
      result.close
      record
    end

    # Find the last record
    def self.last : self?
      query = base_query
        .limit(1)
        .order(@@primary_key, :desc)

      result = Ralph.database.query_one(query.build_select)
      return nil unless result

      record = from_result_set(result)
      result.close
      record
    end

    # Find a record by a specific column value
    #
    # Example:
    # ```
    # User.find_by("email", "user@example.com")
    # ```
    def self.find_by(column : String, value) : self?
      query = base_query
        .where("#{column} = ?", value)
        .limit(1)

      result = Ralph.database.query_one(query.build_select, args: query.where_args)
      return nil unless result

      record = from_result_set(result)
      result.close
      record
    end

    # Find all records matching a column value
    #
    # Example:
    # ```
    # User.find_all_by("age", 25)
    # ```
    def self.find_all_by(column : String, value) : Array(self)
      query = base_query
        .where("#{column} = ?", value)

      results = Ralph.database.query_all(query.build_select, args: query.where_args)
      records = [] of self
      results.each do
        records << from_result_set(results)
      end
      records
    ensure
      results.close if results
    end

    # Find all records matching multiple column conditions
    #
    # Used primarily for polymorphic associations where we need to match
    # both type and id columns.
    #
    # Example:
    # ```
    # Comment.find_all_by_conditions({"commentable_type" => "Post", "commentable_id" => 1})
    # ```
    def self.find_all_by_conditions(conditions : Hash(String, DB::Any)) : Array(self)
      query = base_query
      conditions.each do |column, value|
        query = query.where("\"#{column}\" = ?", value)
      end

      results = Ralph.database.query_all(query.build_select, args: query.where_args)
      records = [] of self
      results.each do
        records << from_result_set(results)
      end
      records
    ensure
      results.close if results
    end

    # Find one record matching multiple column conditions
    #
    # Used primarily for polymorphic associations where we need to match
    # both type and id columns.
    def self.find_by_conditions(conditions : Hash(String, DB::Any)) : self?
      query = base_query
      conditions.each do |column, value|
        query = query.where("\"#{column}\" = ?", value)
      end
      query = query.limit(1)

      result = Ralph.database.query_one(query.build_select, args: query.where_args)
      return nil unless result

      record = from_result_set(result)
      result.close
      record
    end

    # Find a record by conditions, or initialize a new one if not found
    #
    # The new record will have the search conditions set as attributes.
    # If a block is given, it will be yielded the new record for additional setup.
    # The record is NOT saved automatically.
    #
    # Example:
    # ```
    # # Without block
    # user = User.find_or_initialize_by({"email" => "alice@example.com"})
    #
    # # With block for additional attributes
    # user = User.find_or_initialize_by({"email" => "alice@example.com"}) do |u|
    #   u.name = "Alice"
    #   u.role = "user"
    # end
    # user.save # Must save manually
    # ```
    def self.find_or_initialize_by(conditions : Hash(String, DB::Any), &block : self ->) : self
      existing = find_by_conditions(conditions)
      return existing if existing

      record = new
      conditions.each do |column, value|
        record.set_attribute(column, value)
      end
      yield record
      record
    end

    # Find a record by conditions, or initialize a new one if not found (without block)
    def self.find_or_initialize_by(conditions : Hash(String, DB::Any)) : self
      find_or_initialize_by(conditions) { }
    end

    # Find a record by conditions, or create a new one if not found
    #
    # The new record will have the search conditions set as attributes.
    # If a block is given, it will be yielded the new record for additional setup
    # before saving.
    #
    # Example:
    # ```
    # # Without block - creates with just the search conditions
    # user = User.find_or_create_by({"email" => "alice@example.com"})
    #
    # # With block for additional attributes
    # user = User.find_or_create_by({"email" => "alice@example.com"}) do |u|
    #   u.name = "Alice"
    #   u.role = "user"
    # end
    # ```
    def self.find_or_create_by(conditions : Hash(String, DB::Any), &block : self ->) : self
      existing = find_by_conditions(conditions)
      return existing if existing

      record = new
      conditions.each do |column, value|
        record.set_attribute(column, value)
      end
      yield record
      record.save
      record
    end

    # Find a record by conditions, or create a new one if not found (without block)
    def self.find_or_create_by(conditions : Hash(String, DB::Any)) : self
      find_or_create_by(conditions) { }
    end

    # Find all records using a pre-built query builder
    #
    # Used primarily for scoped associations where additional WHERE conditions
    # are added to the query via a lambda.
    #
    # Example:
    # ```
    # query = Ralph::Query::Builder.new(User.table_name)
    # query.where("age > ?", 18)
    # User.find_all_with_query(query)
    # ```
    def self.find_all_with_query(query : Ralph::Query::Builder) : Array(self)
      # Ensure we select columns in the correct order for from_result_set
      query = query.select(column_names_ordered) if query.selects.empty?
      sql = query.build_select
      results = Ralph.database.query_all(sql, args: query.where_args)
      records = [] of self
      results.each do
        records << from_result_set(results)
      end
      records
    ensure
      results.close if results
    end

    # Count records using a pre-built query builder
    #
    # Used for counting scoped associations.
    def self.count_with_query(query : Ralph::Query::Builder) : Int32
      result = Ralph.database.scalar(query.build_count, args: query.where_args)
      return 0 unless result

      case result
      when Int32 then result
      when Int64 then result.to_i32
      else            0
      end
    end

    # Count all records
    def self.count : Int64
      query = Ralph::Query::Builder.new(self.table_name)
      result = Ralph.database.scalar(query.build_count)
      return 0_i64 unless result

      case result
      when Int32 then result.to_i64
      when Int64 then result.as(Int64)
      else            0_i64
      end
    end

    # Reset a counter cache column to the actual count
    #
    # This is useful when counter caches get out of sync.
    # Call this on the parent model to reset the counter for a specific record.
    #
    # Example:
    # ```
    # # Reset books_count for publisher with id 1
    # Publisher.reset_counter_cache(1, "books_count", Book, "publisher_id")
    #
    # # Or more commonly via instance method
    # publisher.reset_counter_cache!("books_count", Book, "publisher_id")
    # ```
    def self.reset_counter_cache(id, counter_column : String, child_class, foreign_key : String)
      # Count actual children using scalar (handles both SQLite and Postgres)
      child_table = child_class.table_name
      count_sql = "SELECT COUNT(*) FROM \"#{child_table}\" WHERE \"#{foreign_key}\" = ?"
      result = Ralph.database.scalar(count_sql, args: [id])
      return unless result

      count = case result
              when Int32 then result.to_i64
              when Int64 then result
              else            0_i64
              end

      # Update the counter
      sql = "UPDATE \"#{self.table_name}\" SET \"#{counter_column}\" = ? WHERE \"#{self.primary_key}\" = ?"
      Ralph.database.execute(sql, args: [count, id])
    end

    # Reset all counter caches for this model to their actual counts
    #
    # Example:
    # ```
    # Publisher.reset_all_counter_caches("books_count", Book, "publisher_id")
    # ```
    def self.reset_all_counter_caches(counter_column : String, child_class, foreign_key : String)
      child_table = child_class.table_name
      sql = <<-SQL
        UPDATE "#{self.table_name}" SET "#{counter_column}" = (
          SELECT COUNT(*)
          FROM "#{child_table}"
          WHERE "#{child_table}"."#{foreign_key}" = "#{self.table_name}"."#{self.primary_key}"
        )
      SQL
      Ralph.database.execute(sql)
    end

    # Instance method to reset a counter cache
    def reset_counter_cache!(counter_column : String, child_class, foreign_key : String)
      pk = primary_key_value
      return if pk.nil?
      self.class.reset_counter_cache(pk, counter_column, child_class, foreign_key)
      reload
    end

    # Count records matching a column value
    def self.count_by(column : String, value) : Int64
      query = Ralph::Query::Builder.new(self.table_name)
        .where("#{column} = ?", value)

      result = Ralph.database.scalar(query.build_count, args: query.where_args)
      return 0_i64 unless result

      case result
      when Int32 then result.to_i64
      when Int64 then result.as(Int64)
      else            0_i64
      end
    end

    # Get the sum of a column
    #
    # Example:
    # ```
    # User.sum(:age)
    # ```
    def self.sum(column : String) : Float64?
      query = Ralph::Query::Builder.new(self.table_name)
      result = Ralph.database.scalar(query.build_sum(column))
      return nil unless result

      case result
      when Int32, Int64     then result.to_f64
      when Float32, Float64 then result.as(Float64)
      else                       nil
      end
    end

    # Get the average of a column
    #
    # Example:
    # ```
    # User.average(:age)
    # ```
    def self.average(column : String) : Float64?
      query = Ralph::Query::Builder.new(self.table_name)
      result = Ralph.database.scalar(query.build_avg(column))
      return nil unless result

      case result
      when Int32, Int64     then result.to_f64
      when Float32, Float64 then result.as(Float64)
      else                       nil
      end
    end

    # Get the minimum value of a column
    #
    # Example:
    # ```
    # User.minimum(:age)
    # ```
    def self.minimum(column : String) : DB::Any?
      query = Ralph::Query::Builder.new(self.table_name)
      Ralph.database.scalar(query.build_min(column))
    end

    # Get the maximum value of a column
    #
    # Example:
    # ```
    # User.maximum(:age)
    # ```
    def self.maximum(column : String) : DB::Any?
      query = Ralph::Query::Builder.new(self.table_name)
      Ralph.database.scalar(query.build_max(column))
    end

    # Create a new record and save it
    def self.create(**kwargs) : self
      record = new(**kwargs)
      record.save
      record
    end

    # Initialize with attributes
    def initialize(**kwargs)
      # Set provided values
      kwargs.each do |key, value|
        __set_by_key_name(key.to_s, value)
      end
    end

    # Check if any attributes have changed
    def changed? : Bool
      !@_changed_attributes.empty?
    end

    # Check if a specific attribute has changed
    def changed?(attribute : String) : Bool
      @_changed_attributes.includes?(attribute)
    end

    # Get list of changed attributes
    def changed_attributes : Set(String)
      @_changed_attributes.dup
    end

    # Get original value of an attribute before changes
    def original_value(attribute : String) : DB::Any?
      @_original_attributes[attribute]?
    end

    # Get changes as a hash of attribute => [old, new]
    def changes : Hash(String, Tuple(DB::Any?, DB::Any?))
      changes = {} of String => Tuple(DB::Any?, DB::Any?)
      @_changed_attributes.each do |attr|
        old_value = @_original_attributes[attr]?
        new_value = __get_by_key_name(attr)
        changes[attr] = {old_value, new_value}
      end
      changes
    end

    # Mark all attributes as clean (no changes)
    def clear_changes_information
      @_changed_attributes.clear
      @_original_attributes.clear
    end

    # ========================================
    # Preloaded Associations Support
    # ========================================

    # Set a preloaded single record (belongs_to, has_one)
    def _set_preloaded_one(association : String, record : Model?) : Nil
      @_preloaded_one[association] = record
      @_preloaded_associations.add(association)
    end

    # Set preloaded collection (has_many)
    def _set_preloaded_many(association : String, records : Array(Model)) : Nil
      @_preloaded_many[association] = records
      @_preloaded_associations.add(association)
    end

    # Get a preloaded single record
    def _get_preloaded_one(association : String) : Model?
      @_preloaded_one[association]?
    end

    # Get preloaded collection
    def _get_preloaded_many(association : String) : Array(Model)?
      @_preloaded_many[association]?
    end

    # Check if an association has been preloaded
    def _has_preloaded?(association : String) : Bool
      @_preloaded_associations.includes?(association)
    end

    # Clear all preloaded associations
    def _clear_preloaded! : Nil
      @_preloaded_one.clear
      @_preloaded_many.clear
      @_preloaded_associations.clear
    end

    # Mark a specific attribute as changed
    protected def attribute_will_change!(attribute : String)
      # Store original value if not already tracked
      unless @_changed_attributes.includes?(attribute)
        current = __get_by_key_name(attribute)
        @_original_attributes[attribute] = current unless current.nil?
      end
      @_changed_attributes.add(attribute)
    end

    # Note: save and destroy methods are provided by the Callbacks module
    # which wraps insert/update_record/destroy operations with callback support

    # Set an attribute by name at runtime
    #
    # This is useful for dynamic attribute assignment when you have
    # the attribute name as a string.
    #
    # Example:
    # ```
    # user = User.new
    # user.set_attribute("name", "Alice")
    # user.set_attribute("email", "alice@example.com")
    # ```
    def set_attribute(name : String, value : DB::Any) : Nil
      __set_by_key_name(name, value)
    end

    # Update attributes and save the record
    #
    # Example:
    # ```
    # user = User.find(1)
    # user.update(name: "New Name", age: 30)
    # ```
    def update(**kwargs) : Bool
      # Apply the new attribute values
      kwargs.each do |key, value|
        __set_by_key_name(key.to_s, value)
      end

      # Save the changes
      save
    end

    # Reload the record from the database
    #
    # Example:
    # ```
    # user = User.find(1)
    # user.reload
    # ```
    def reload : self
      return self if new_record?

      query = self.class.base_query
        .where("#{self.class.primary_key} = ?", primary_key_value)

      result = Ralph.database.query_one(query.build_select, args: query.where_args)
      return self unless result

      begin
        # Re-populate using the macro-based approach
        _reload_from_result_set(result)
      ensure
        result.close
      end

      self
    end

    # Helper method to reload from a result set
    private def _reload_from_result_set(rs : DB::ResultSet)
      # Strict ResultSet validation (when enabled)
      if Ralph.settings.strict_resultset_validation
        actual_columns = [] of String
        rs.column_count.times do |i|
          actual_columns << rs.column_name(i)
        end
        expected_columns = self.class.column_names_ordered

        if actual_columns != expected_columns
          raise Ralph::SchemaMismatchError.new(
            model_name: {{@type.name.stringify}},
            table_name: self.class.table_name,
            expected_columns: expected_columns,
            actual_columns: actual_columns
          )
        end
      end

      # Track column index for error reporting
      column_index = 0

      # Read values and assign to instance variables via setters
      {% for ivar in @type.instance_vars %}
        {% unless ivar.name.starts_with?("_") %}
          {% type_str = ivar.type.stringify %}
          # Detect nilable types using consistent pattern
          {% nilable = type_str.ends_with?("?") ||
                       type_str.includes?("| Nil") ||
                       type_str.includes?("Nil |") ||
                       type_str.includes?("Nil)") ||
                       type_str.includes?("Nil,") ||
                       type_str.includes?("::Nil") ||
                       type_str == "Nil" %}

          begin
          {% if type_str.includes?("Int64") %}
            {% if nilable %}
              self.{{ivar.name}}=rs.read(Int64 | Nil)
            {% else %}
              self.{{ivar.name}}=rs.read(Int64)
            {% end %}
          {% elsif type_str.includes?("Int32") %}
            {% if nilable %}
              self.{{ivar.name}}=rs.read(Int32 | Nil)
            {% else %}
              self.{{ivar.name}}=rs.read(Int32)
            {% end %}
          {% elsif type_str.includes?("Float32") %}
            # Float32 - PostgreSQL REAL type or NUMERIC
            %raw_float32 = rs.read(Float32 | PG::Numeric | Nil)
            {% if nilable %}
              if %raw_float32.nil?
                self.{{ivar.name}} = nil
              elsif %raw_float32.is_a?(PG::Numeric)
                self.{{ivar.name}} = %raw_float32.to_f.to_f32
              else
                self.{{ivar.name}} = %raw_float32
              end
            {% else %}
              if %raw_float32.is_a?(PG::Numeric)
                self.{{ivar.name}} = %raw_float32.to_f.to_f32
              elsif %raw_float32
                self.{{ivar.name}} = %raw_float32
              else
                self.{{ivar.name}} = 0.0_f32
              end
            {% end %}
          {% elsif type_str.includes?("Float64") %}
            # Float64 - PostgreSQL NUMERIC/DECIMAL returns PG::Numeric
            %raw_float = rs.read(PG::Numeric | Float64 | Nil)
            {% if nilable %}
              if %raw_float.nil?
                self.{{ivar.name}} = nil
              elsif %raw_float.is_a?(PG::Numeric)
                self.{{ivar.name}} = %raw_float.to_f64
              else
                self.{{ivar.name}} = %raw_float
              end
            {% else %}
              if %raw_float.is_a?(PG::Numeric)
                self.{{ivar.name}} = %raw_float.to_f64
              elsif %raw_float
                self.{{ivar.name}} = %raw_float
              else
                self.{{ivar.name}} = 0.0
              end
            {% end %}
          {% elsif type_str.includes?("String") %}
            {% if nilable %}
              self.{{ivar.name}}=rs.read(String | Nil)
            {% else %}
              self.{{ivar.name}}=rs.read(String)
            {% end %}
          {% elsif type_str.includes?("Time") %}
            {% if nilable %}
              self.{{ivar.name}}=rs.read(Time | Nil)
            {% else %}
              self.{{ivar.name}}=rs.read(Time)
            {% end %}
          {% elsif type_str.includes?("Bool") %}
            {% if nilable %}
              self.{{ivar.name}}=rs.read(Bool | Nil)
            {% else %}
              self.{{ivar.name}}=rs.read(Bool)
            {% end %}
          {% else %}
            self.{{ivar.name}}=rs.read(String | Nil)
          {% end %}

          rescue ex : DB::ColumnTypeMismatchError
            rs_column_name = if column_index < rs.column_count
              rs.column_name(column_index)
            else
              nil
            end

            raise Ralph::TypeMismatchError.new(
              model_name: {{@type.name.stringify}},
              column_name: {{ivar.name.stringify}},
              column_index: column_index,
              expected_type: {{type_str}},
              actual_type: ex.message.try { |m| m.match(/returned a (\w+)/).try(&.[1]) } || "unknown",
              resultset_column_name: rs_column_name,
              cause: ex
            )
          end

          column_index += 1
        {% end %}
      {% end %}

      clear_changes_information
    end

    # Check if this is a new record (not persisted)
    def new_record? : Bool
      !persisted?
    end

    # Check if this record has been persisted to the database
    # Uses explicit @_persisted flag rather than PK presence because
    # non-auto PKs (UUID, String) can be set before the record is saved
    def persisted? : Bool
      @_persisted
    end

    # Mark this record as persisted (called after successful insert/load)
    protected def mark_persisted!
      @_persisted = true
    end

    # Mark this record as not persisted (called after destroy)
    protected def mark_unpersisted!
      @_persisted = false
    end

    # Get the primary key value (single key)
    protected def primary_key_value
      __get_by_key_name(self.class.primary_key)
    end

    # Get all primary key values as a hash (for composite keys)
    protected def primary_key_values : Hash(String, DB::Any)
      hash = {} of String => DB::Any
      self.class.primary_keys.each do |pk|
        val = __get_by_key_name(pk)
        # Convert UUID to string for DB compatibility
        if val.is_a?(UUID)
          hash[pk] = val.to_s
        elsif !val.nil?
          hash[pk] = val.as(DB::Any)
        end
      end
      hash
    end

    # Check if the primary key is auto-generated by the database (Int types)
    private def auto_generated_primary_key? : Bool
      pk_type = self.class.primary_key_type
      pk_type == "Int64" || pk_type == "Int32"
    end

    # Insert a new record
    private def insert
      query = Ralph::Query::Builder.new(self.class.table_name)
      data = to_h

      # For auto-generated PKs (Int64/Int32), remove nil PK from insert
      # For non-auto PKs (String/UUID), the PK should already be set
      if auto_generated_primary_key?
        data.delete(self.class.primary_key) if data[self.class.primary_key]?.nil?
      end

      sql, args = query.build_insert(data)
      id = Ralph.database.insert(sql, args: args)

      # Only set the PK from the database return value for auto-generated PKs
      if auto_generated_primary_key?
        __set_by_key_name(self.class.primary_key, id)
      end

      # Invalidate query cache for this table if auto-invalidation is enabled
      if Ralph.settings.query_cache_auto_invalidate
        Ralph::Query::Builder.invalidate_table_cache(self.class.table_name)
      end

      # Store in identity map if enabled
      Ralph::IdentityMap.set(self)

      # Mark as persisted now that insert succeeded
      mark_persisted!

      clear_changes_information
      true
    end

    # Update an existing record
    private def update_record
      query = Ralph::Query::Builder.new(self.class.table_name)

      # Build WHERE clause for all primary keys (supports composite keys)
      pk_values = primary_key_values
      pk_values.each do |pk_name, pk_val|
        query = query.where("#{pk_name} = ?", pk_val)
      end

      data = to_h
      # Remove all primary key columns from update data
      self.class.primary_keys.each do |pk|
        data.delete(pk)
      end

      sql, args = query.build_update(data)
      Ralph.database.execute(sql, args: args)

      # Invalidate query cache for this table if auto-invalidation is enabled
      if Ralph.settings.query_cache_auto_invalidate
        Ralph::Query::Builder.invalidate_table_cache(self.class.table_name)
      end

      clear_changes_information
      true
    end

    # Convert model to hash for database operations
    # Handles serialization of advanced types (JSON, UUID, Array, Enum)
    # Uses getter to apply defaults, but catches NilAssertionError for
    # non-nullable columns that don't have a value yet (e.g., auto-increment id).
    def to_h : Hash(String, DB::Any)
      hash = {} of String => DB::Any
      {% for ivar in @type.instance_vars %}
        {% unless ivar.name.starts_with?("_") %}
          {% type_str = ivar.type.stringify %}
          # Try getter to apply defaults; if NilAssertionError, skip this column
          # Use a unique variable name per ivar to avoid type union issues
          __temp_{{ivar.name}} = begin
            {{ivar.name}}
          rescue NilAssertionError
            nil
          end
          unless __temp_{{ivar.name}}.nil?
            {% if type_str.includes?("JSON::Any") %}
              # Serialize JSON::Any to string
              hash[{{ivar.name.stringify}}] = __temp_{{ivar.name}}.to_json
            {% elsif type_str.includes?("UUID") %}
              # Serialize UUID to string
              hash[{{ivar.name.stringify}}] = __temp_{{ivar.name}}.to_s
            {% elsif type_str.includes?("Array(") %}
              # Serialize Array to JSON string
              hash[{{ivar.name.stringify}}] = __temp_{{ivar.name}}.to_json
            {% elsif type_str.includes?("Time") %}
              # Time needs conversion - use to_utc for DB storage
              hash[{{ivar.name.stringify}}] = __temp_{{ivar.name}}.as(Time)
            {% else %}
              # Check if it's an enum type
              {% resolved_type = ivar.type.union_types ? ivar.type.union_types.reject { |t| t == Nil }.first : ivar.type %}
              {% if resolved_type.ancestors.any? { |a| a.stringify == "Enum" } %}
                # Serialize enum to string (member name)
                hash[{{ivar.name.stringify}}] = __temp_{{ivar.name}}.to_s
              {% else %}
                # Standard types - pass through as DB::Any
                # Need to cast explicitly to avoid union type issues
                {% if type_str.includes?("String") %}
                  hash[{{ivar.name.stringify}}] = __temp_{{ivar.name}}.as(String)
                {% elsif type_str.includes?("Int64") %}
                  hash[{{ivar.name.stringify}}] = __temp_{{ivar.name}}.as(Int64)
                {% elsif type_str.includes?("Int32") %}
                  hash[{{ivar.name.stringify}}] = __temp_{{ivar.name}}.as(Int32)
                {% elsif type_str.includes?("Float64") %}
                  hash[{{ivar.name.stringify}}] = __temp_{{ivar.name}}.as(Float64)
                {% elsif type_str.includes?("Float32") %}
                  hash[{{ivar.name.stringify}}] = __temp_{{ivar.name}}.as(Float32)
                {% elsif type_str.includes?("Bool") %}
                  hash[{{ivar.name.stringify}}] = __temp_{{ivar.name}}.as(Bool)
                {% else %}
                  # Fallback - convert to string for safety
                  hash[{{ivar.name.stringify}}] = __temp_{{ivar.name}}.to_s
                {% end %}
              {% end %}
            {% end %}
          end
        {% end %}
      {% end %}
      hash
    end

    # Create a model instance from a result set
    #
    # This macro generates code to read columns from a DB::ResultSet and
    # populate a model instance. It includes optional strict validation
    # that checks the ResultSet columns match the model's expected columns.
    #
    # ## Schema Validation
    #
    # When `Ralph.settings.strict_resultset_validation` is enabled (default: true),
    # the generated code will:
    # 1. Compare ResultSet column names against model's `column_names_ordered`
    # 2. Raise `Ralph::SchemaMismatchError` if there's any mismatch
    #
    # This catches issues like:
    # - Model missing columns that exist in database
    # - Model has extra columns not in database
    # - Column order mismatch
    # - Schema drift after migrations
    #
    # ## Type Mismatch Handling
    #
    # Each column read is wrapped to catch `DB::ColumnTypeMismatchError` and
    # re-raise as `Ralph::TypeMismatchError` with additional context:
    # - Which model/column was being read
    # - Expected vs actual types
    # - Helpful hints for fixing the mismatch
    macro from_result_set(rs)
      %instance = allocate

      # Strict ResultSet validation (when enabled)
      # Compare actual columns from ResultSet to model's expected columns
      if Ralph.settings.strict_resultset_validation
        %actual_columns = [] of String
        {{rs}}.column_count.times do |i|
          %actual_columns << {{rs}}.column_name(i)
        end
        %expected_columns = \{{@type}}.column_names_ordered

        if %actual_columns != %expected_columns
          raise Ralph::SchemaMismatchError.new(
            model_name: \{{@type.name.stringify}},
            table_name: \{{@type}}.table_name,
            expected_columns: %expected_columns,
            actual_columns: %actual_columns
          )
        end
      end

      # Track column index for error reporting
      %column_index = 0

      # Read values and assign to instance variables via setters
      {% for ivar in @type.instance_vars %}
        {% unless ivar.name.starts_with?("_") %}
          {% type_str = ivar.type.stringify %}
          # Detect nilable types using consistent pattern
          {% nilable = type_str.ends_with?("?") ||
                       type_str.includes?("| Nil") ||
                       type_str.includes?("Nil |") ||
                       type_str.includes?("Nil)") ||
                       type_str.includes?("Nil,") ||
                       type_str.includes?("::Nil") ||
                       type_str == "Nil" %}

          # Wrap column read with error handling for better error messages
          begin
          {% if type_str.includes?("Int64") %}
            {% if nilable %}
              %instance.{{ivar.name}}={{rs}}.read(Int64 | Nil)
            {% else %}
              %instance.{{ivar.name}}={{rs}}.read(Int64)
            {% end %}
          {% elsif type_str.includes?("Int32") %}
            {% if nilable %}
              %instance.{{ivar.name}}={{rs}}.read(Int32 | Nil)
            {% else %}
              %instance.{{ivar.name}}={{rs}}.read(Int32)
            {% end %}
          {% elsif type_str.includes?("Float32") %}
            # Float32 - PostgreSQL REAL type or NUMERIC (which returns PG::Numeric)
            %raw_float32 = {{rs}}.read(Float32 | PG::Numeric | Nil)
            {% if nilable %}
              if %raw_float32.nil?
                %instance.{{ivar.name}} = nil
              elsif %raw_float32.is_a?(PG::Numeric)
                %instance.{{ivar.name}} = %raw_float32.to_f.to_f32
              else
                %instance.{{ivar.name}} = %raw_float32
              end
            {% else %}
              if %raw_float32.is_a?(PG::Numeric)
                %instance.{{ivar.name}} = %raw_float32.to_f.to_f32
              elsif %raw_float32
                %instance.{{ivar.name}} = %raw_float32
              else
                %instance.{{ivar.name}} = 0.0_f32
              end
            {% end %}
          {% elsif type_str.includes?("Float64") %}
            # Float64 - PostgreSQL NUMERIC/DECIMAL returns PG::Numeric
            %raw_float = {{rs}}.read(PG::Numeric | Float64 | Nil)
            {% if nilable %}
              if %raw_float.nil?
                %instance.{{ivar.name}} = nil
              elsif %raw_float.is_a?(PG::Numeric)
                %instance.{{ivar.name}} = %raw_float.to_f64
              else
                %instance.{{ivar.name}} = %raw_float
              end
            {% else %}
              if %raw_float.is_a?(PG::Numeric)
                %instance.{{ivar.name}} = %raw_float.to_f64
              elsif %raw_float
                %instance.{{ivar.name}} = %raw_float
              else
                %instance.{{ivar.name}} = 0.0
              end
            {% end %}
          {% elsif type_str.includes?("Time") %}
            {% if nilable %}
              %instance.{{ivar.name}}={{rs}}.read(Time | Nil)
            {% else %}
              %instance.{{ivar.name}}={{rs}}.read(Time)
            {% end %}
          {% elsif type_str.includes?("Bool") %}
            {% if nilable %}
              %instance.{{ivar.name}}={{rs}}.read(Bool | Nil)
            {% else %}
              %instance.{{ivar.name}}={{rs}}.read(Bool)
            {% end %}
          {% elsif type_str.includes?("JSON::Any") %}
            # JSON::Any - stored as TEXT in SQLite or JSONB in PostgreSQL
            # PostgreSQL returns JSON::PullParser for JSONB, SQLite returns String
            %raw_json = {{rs}}.read(JSON::PullParser | String | Nil)
            {% if nilable %}
              if %raw_json.nil?
                %instance.{{ivar.name}} = nil
              elsif %raw_json.is_a?(JSON::PullParser)
                begin
                  %instance.{{ivar.name}} = JSON::Any.new(%raw_json)
                rescue
                  %instance.{{ivar.name}} = nil
                end
              else
                begin
                  %instance.{{ivar.name}} = JSON.parse(%raw_json)
                rescue JSON::ParseException
                  %instance.{{ivar.name}} = nil
                end
              end
            {% else %}
              if %raw_json.is_a?(JSON::PullParser)
                begin
                  %instance.{{ivar.name}} = JSON::Any.new(%raw_json)
                rescue
                  %instance.{{ivar.name}} = JSON::Any.new(nil)
                end
              elsif %raw_json
                begin
                  %instance.{{ivar.name}} = JSON.parse(%raw_json)
                rescue JSON::ParseException
                  %instance.{{ivar.name}} = JSON::Any.new(nil)
                end
              else
                %instance.{{ivar.name}} = JSON::Any.new(nil)
              end
            {% end %}
          {% elsif type_str.includes?("UUID") %}
            # UUID - stored as CHAR(36) in SQLite or native UUID in PostgreSQL
            # PostgreSQL returns UUID type directly, SQLite returns String
            %raw_uuid = {{rs}}.read(UUID | String | Nil)
            {% if nilable %}
              if %raw_uuid.nil?
                %instance.{{ivar.name}} = nil
              elsif %raw_uuid.is_a?(UUID)
                %instance.{{ivar.name}} = %raw_uuid
              else
                begin
                  %instance.{{ivar.name}} = UUID.new(%raw_uuid)
                rescue ArgumentError
                  %instance.{{ivar.name}} = nil
                end
              end
            {% else %}
              if %raw_uuid.is_a?(UUID)
                %instance.{{ivar.name}} = %raw_uuid
              elsif %raw_uuid
                begin
                  %instance.{{ivar.name}} = UUID.new(%raw_uuid)
                rescue ArgumentError
                  %instance.{{ivar.name}} = UUID.empty
                end
              else
                %instance.{{ivar.name}} = UUID.empty
              end
            {% end %}
          {% elsif type_str.includes?("Array(") %}
            # Array types - stored as JSON in SQLite, native array in PostgreSQL
            %raw_array = {{rs}}.read(String | Nil)
            {% if nilable %}
              if %raw_array.nil?
                %instance.{{ivar.name}} = nil
              else
                begin
                  %parsed = JSON.parse(%raw_array)
                  if %arr = %parsed.as_a?
                    # Determine element type from the type string
                    {% element_type = type_str.gsub("Array(", "").gsub(")", "").gsub(" | Nil", "").strip %}
                    {% if element_type == "String" %}
                      %instance.{{ivar.name}} = %arr.map { |v| v.as_s? || v.raw.to_s }
                    {% elsif element_type == "Int32" %}
                      %instance.{{ivar.name}} = %arr.map { |v| v.as_i? || 0 }
                    {% elsif element_type == "Int64" %}
                      %instance.{{ivar.name}} = %arr.map { |v| v.as_i64? || v.as_i?.try(&.to_i64) || 0_i64 }
                    {% elsif element_type == "Float64" %}
                      %instance.{{ivar.name}} = %arr.map { |v| v.as_f? || v.as_i?.try(&.to_f64) || 0.0 }
                    {% elsif element_type == "Bool" %}
                      %instance.{{ivar.name}} = %arr.map { |v| v.as_bool? || false }
                    {% else %}
                      %instance.{{ivar.name}} = %arr.map { |v| v.as_s? || v.raw.to_s }
                    {% end %}
                  else
                    %instance.{{ivar.name}} = nil
                  end
                rescue JSON::ParseException
                  %instance.{{ivar.name}} = nil
                end
              end
            {% else %}
              if %raw_array
                begin
                  %parsed = JSON.parse(%raw_array)
                  if %arr = %parsed.as_a?
                    {% element_type = type_str.gsub("Array(", "").gsub(")", "").gsub(" | Nil", "").strip %}
                    {% if element_type == "String" %}
                      %instance.{{ivar.name}} = %arr.map { |v| v.as_s? || v.raw.to_s }
                    {% elsif element_type == "Int32" %}
                      %instance.{{ivar.name}} = %arr.map { |v| v.as_i? || 0 }
                    {% elsif element_type == "Int64" %}
                      %instance.{{ivar.name}} = %arr.map { |v| v.as_i64? || v.as_i?.try(&.to_i64) || 0_i64 }
                    {% elsif element_type == "Float64" %}
                      %instance.{{ivar.name}} = %arr.map { |v| v.as_f? || v.as_i?.try(&.to_f64) || 0.0 }
                    {% elsif element_type == "Bool" %}
                      %instance.{{ivar.name}} = %arr.map { |v| v.as_bool? || false }
                    {% else %}
                      %instance.{{ivar.name}} = %arr.map { |v| v.as_s? || v.raw.to_s }
                    {% end %}
                  else
                    {% element_type = type_str.gsub("Array(", "").gsub(")", "").gsub(" | Nil", "").strip %}
                    %instance.{{ivar.name}} = [] of {{element_type.id}}
                  end
                rescue JSON::ParseException
                  {% element_type = type_str.gsub("Array(", "").gsub(")", "").gsub(" | Nil", "").strip %}
                  %instance.{{ivar.name}} = [] of {{element_type.id}}
                end
              else
                {% element_type = type_str.gsub("Array(", "").gsub(")", "").gsub(" | Nil", "").strip %}
                %instance.{{ivar.name}} = [] of {{element_type.id}}
              end
            {% end %}
          {% elsif type_str.includes?("String") %}
            {% if nilable %}
              %instance.{{ivar.name}}={{rs}}.read(String | Nil)
            {% else %}
              %instance.{{ivar.name}}={{rs}}.read(String)
            {% end %}
          {% else %}
            # Check if it's an enum type (Crystal enums have a 'value' method)
            {% resolved_type = ivar.type.union_types ? ivar.type.union_types.reject { |t| t == Nil }.first : ivar.type %}
            {% if resolved_type.ancestors.any? { |a| a.stringify == "Enum" } %}
              # Enum type - try to read as string first, then integer
              %raw_enum = {{rs}}.read(String | Nil)
              {% if nilable %}
                if %raw_enum.nil?
                  %instance.{{ivar.name}} = nil
                else
                  %instance.{{ivar.name}} = {{resolved_type}}.parse?(%raw_enum) || {{resolved_type}}.from_value?(%raw_enum.to_i?) || nil
                end
              {% else %}
                if %raw_enum
                  %instance.{{ivar.name}} = {{resolved_type}}.parse?(%raw_enum) || {{resolved_type}}.from_value?(%raw_enum.to_i?) || {{resolved_type}}.values.first
                else
                  %instance.{{ivar.name}} = {{resolved_type}}.values.first
                end
              {% end %}
            {% else %}
              # Default: try to read as string
              %instance.{{ivar.name}}={{rs}}.read(String | Nil)
            {% end %}
          {% end %}

          # Rescue DB::ColumnTypeMismatchError and wrap with model context
          rescue ex : DB::ColumnTypeMismatchError
            # Get the actual column name from ResultSet if available
            %rs_column_name = if %column_index < {{rs}}.column_count
              {{rs}}.column_name(%column_index)
            else
              nil
            end

            raise Ralph::TypeMismatchError.new(
              model_name: \{{@type.name.stringify}},
              column_name: {{ivar.name.stringify}},
              column_index: %column_index,
              expected_type: {{type_str}},
              actual_type: ex.message.try { |m| m.match(/returned a (\w+)/).try(&.[1]) } || "unknown",
              resultset_column_name: %rs_column_name,
              cause: ex
            )
          end

          # Increment column index for next column
          %column_index += 1
        {% end %}
      {% end %}

      # Clear dirty tracking
      %instance.clear_changes_information

      # Mark as persisted since we loaded from database
      %instance.mark_persisted!

      %instance
    end

    # Runtime dynamic getter by string key name
    # This is a method (not macro) that can be called across class boundaries
    def _get_attribute(name : String) : DB::Any?
      {% for ivar in @type.instance_vars %}
        {% unless ivar.name.starts_with?("_") %}
          if name == {{ivar.name.stringify}}
            val = @{{ivar.name}}
            return val.as(DB::Any?) if val.nil? || val.is_a?(DB::Any)
            # Handle UUID by converting to string (UUID is stored as CHAR(36) in SQLite)
            return val.to_s if val.is_a?(UUID)
            return nil
          end
        {% end %}
      {% end %}
      nil
    end

    # Dynamic getter by string key name
    macro __get_by_key_name(name)
      %result = case {{name}}
      {% for ivar in @type.instance_vars %}
        {% unless ivar.name.starts_with?("_") %}
          when {{ivar.name.stringify}} then @{{ivar.name}}
        {% end %}
      {% end %}
      else
        nil
      end
      %result
    end

    # Dynamic setter by string key name
    # Handles advanced types (JSON, UUID, Array, Enum) with proper type coercion
    macro __set_by_key_name(name, value)
      case {{name}}
      {% for ivar in @type.instance_vars %}
        {% unless ivar.name.starts_with?("_") %}
          {% type_str = ivar.type.stringify %}
          # Detect nilable types using consistent pattern
          {% nilable = type_str.ends_with?("?") ||
                       type_str.includes?("| Nil") ||
                       type_str.includes?("Nil |") ||
                       type_str.includes?("Nil)") ||
                       type_str.includes?("Nil,") ||
                       type_str.includes?("::Nil") %}
          when {{ivar.name.stringify}}
            {% if type_str.includes?("Int64") %}
              {% if nilable %}
                %val = {{value}}
                if %val.nil?
                  self.{{ivar.name}} = nil
                elsif %val.is_a?(Int64)
                  self.{{ivar.name}} = %val.as(Int64)
                elsif %val.responds_to?(:to_i64)
                  self.{{ivar.name}} = %val.to_i64
                else
                  self.{{ivar.name}} = nil
                end
              {% else %}
                %val = {{value}}
                if %val.is_a?(Int64)
                  self.{{ivar.name}} = %val.as(Int64)
                elsif %val.responds_to?(:to_i64)
                  self.{{ivar.name}} = %val.to_i64
                else
                  self.{{ivar.name}} = 0_i64
                end
              {% end %}
            {% elsif type_str.includes?("Int32") %}
              {% if nilable %}
                %val = {{value}}
                if %val.nil?
                  self.{{ivar.name}} = nil
                elsif %val.is_a?(Int32)
                  self.{{ivar.name}} = %val.as(Int32)
                elsif %val.responds_to?(:to_i32)
                  self.{{ivar.name}} = %val.to_i32
                else
                  self.{{ivar.name}} = nil
                end
              {% else %}
                %val = {{value}}
                if %val.is_a?(Int32)
                  self.{{ivar.name}} = %val.as(Int32)
                elsif %val.responds_to?(:to_i32)
                  self.{{ivar.name}} = %val.to_i32
                else
                  self.{{ivar.name}} = 0_i32
                end
              {% end %}
            {% elsif type_str.includes?("Float32") %}
              {% if nilable %}
                %val = {{value}}
                if %val.nil?
                  self.{{ivar.name}} = nil
                elsif %val.is_a?(Float32)
                  self.{{ivar.name}} = %val.as(Float32)
                elsif %val.responds_to?(:to_f32)
                  self.{{ivar.name}} = %val.to_f32
                else
                  self.{{ivar.name}} = nil
                end
              {% else %}
                %val = {{value}}
                if %val.is_a?(Float32)
                  self.{{ivar.name}} = %val.as(Float32)
                elsif %val.responds_to?(:to_f32)
                  self.{{ivar.name}} = %val.to_f32
                else
                  self.{{ivar.name}} = 0.0_f32
                end
              {% end %}
            {% elsif type_str.includes?("Float64") %}
              {% if nilable %}
                %val = {{value}}
                if %val.nil?
                  self.{{ivar.name}} = nil
                elsif %val.is_a?(Float64)
                  self.{{ivar.name}} = %val.as(Float64)
                elsif %val.responds_to?(:to_f64)
                  self.{{ivar.name}} = %val.to_f64
                else
                  self.{{ivar.name}} = nil
                end
              {% else %}
                %val = {{value}}
                if %val.is_a?(Float64)
                  self.{{ivar.name}} = %val.as(Float64)
                elsif %val.responds_to?(:to_f64)
                  self.{{ivar.name}} = %val.to_f64
                else
                  self.{{ivar.name}} = 0.0
                end
              {% end %}
            {% elsif type_str.includes?("Time") %}
              {% if nilable %}
                %val = {{value}}
                if %val.nil?
                  self.{{ivar.name}} = nil
                elsif %val.is_a?(Time)
                  self.{{ivar.name}} = %val.as(Time)
                else
                  self.{{ivar.name}} = Time.unix(0)
                end
              {% else %}
                %val = {{value}}
                if %val.is_a?(Time)
                  self.{{ivar.name}} = %val.as(Time)
                else
                  self.{{ivar.name}} = Time.unix(0)
                end
              {% end %}
            {% elsif type_str.includes?("Bool") %}
              {% if nilable %}
                %val = {{value}}
                if %val.nil?
                  self.{{ivar.name}} = nil
                else
                  self.{{ivar.name}} = %val == true || (%val.to_s == "true")
                end
              {% else %}
                %val = {{value}}
                self.{{ivar.name}} = %val == true || (%val.to_s == "true")
              {% end %}
            {% elsif type_str.includes?("JSON::Any") %}
              # JSON::Any type
              %val = {{value}}
              {% if nilable %}
                if %val.nil?
                  self.{{ivar.name}} = nil
                elsif %val.is_a?(JSON::Any)
                  self.{{ivar.name}} = %val
                elsif %val.is_a?(String)
                  begin
                    self.{{ivar.name}} = JSON.parse(%val)
                  rescue JSON::ParseException
                    self.{{ivar.name}} = nil
                  end
                elsif %val.is_a?(Hash) || %val.is_a?(Array)
                  self.{{ivar.name}} = JSON.parse(%val.to_json)
                else
                  self.{{ivar.name}} = nil
                end
              {% else %}
                if %val.is_a?(JSON::Any)
                  self.{{ivar.name}} = %val
                elsif %val.is_a?(String)
                  begin
                    self.{{ivar.name}} = JSON.parse(%val)
                  rescue JSON::ParseException
                    self.{{ivar.name}} = JSON::Any.new(nil)
                  end
                elsif %val.is_a?(Hash) || %val.is_a?(Array)
                  self.{{ivar.name}} = JSON.parse(%val.to_json)
                else
                  self.{{ivar.name}} = JSON::Any.new(nil)
                end
              {% end %}
            {% elsif type_str.includes?("UUID") %}
              # UUID type
              %val = {{value}}
              {% if nilable %}
                if %val.nil?
                  self.{{ivar.name}} = nil
                elsif %val.is_a?(UUID)
                  self.{{ivar.name}} = %val
                elsif %val.is_a?(String)
                  begin
                    self.{{ivar.name}} = UUID.new(%val)
                  rescue ArgumentError
                    self.{{ivar.name}} = nil
                  end
                else
                  self.{{ivar.name}} = nil
                end
              {% else %}
                if %val.is_a?(UUID)
                  self.{{ivar.name}} = %val
                elsif %val.is_a?(String)
                  begin
                    self.{{ivar.name}} = UUID.new(%val)
                  rescue ArgumentError
                    self.{{ivar.name}} = UUID.empty
                  end
                else
                  self.{{ivar.name}} = UUID.empty
                end
              {% end %}
            {% elsif type_str.includes?("Array(") %}
              # Array type
              %val = {{value}}
              {% element_type = type_str.gsub("Array(", "").gsub(")", "").gsub(" | Nil", "").strip %}
              {% if nilable %}
                if %val.nil?
                  self.{{ivar.name}} = nil
                elsif %val.is_a?(Array)
                  self.{{ivar.name}} = %val.as(Array({{element_type.id}}))
                elsif %val.is_a?(String)
                  begin
                    %parsed = JSON.parse(%val)
                    if %arr = %parsed.as_a?
                      {% if element_type == "String" %}
                        self.{{ivar.name}} = %arr.map { |v| v.as_s? || v.raw.to_s }
                      {% elsif element_type == "Int32" %}
                        self.{{ivar.name}} = %arr.map { |v| v.as_i? || 0 }
                      {% elsif element_type == "Int64" %}
                        self.{{ivar.name}} = %arr.map { |v| v.as_i64? || v.as_i?.try(&.to_i64) || 0_i64 }
                      {% elsif element_type == "Float64" %}
                        self.{{ivar.name}} = %arr.map { |v| v.as_f? || v.as_i?.try(&.to_f64) || 0.0 }
                      {% elsif element_type == "Bool" %}
                        self.{{ivar.name}} = %arr.map { |v| v.as_bool? || false }
                      {% else %}
                        self.{{ivar.name}} = %arr.map { |v| v.as_s? || v.raw.to_s }
                      {% end %}
                    else
                      self.{{ivar.name}} = nil
                    end
                  rescue JSON::ParseException
                    self.{{ivar.name}} = nil
                  end
                else
                  self.{{ivar.name}} = nil
                end
              {% else %}
                if %val.is_a?(Array)
                  self.{{ivar.name}} = %val.as(Array({{element_type.id}}))
                elsif %val.is_a?(String)
                  begin
                    %parsed = JSON.parse(%val)
                    if %arr = %parsed.as_a?
                      {% if element_type == "String" %}
                        self.{{ivar.name}} = %arr.map { |v| v.as_s? || v.raw.to_s }
                      {% elsif element_type == "Int32" %}
                        self.{{ivar.name}} = %arr.map { |v| v.as_i? || 0 }
                      {% elsif element_type == "Int64" %}
                        self.{{ivar.name}} = %arr.map { |v| v.as_i64? || v.as_i?.try(&.to_i64) || 0_i64 }
                      {% elsif element_type == "Float64" %}
                        self.{{ivar.name}} = %arr.map { |v| v.as_f? || v.as_i?.try(&.to_f64) || 0.0 }
                      {% elsif element_type == "Bool" %}
                        self.{{ivar.name}} = %arr.map { |v| v.as_bool? || false }
                      {% else %}
                        self.{{ivar.name}} = %arr.map { |v| v.as_s? || v.raw.to_s }
                      {% end %}
                    else
                      self.{{ivar.name}} = [] of {{element_type.id}}
                    end
                  rescue JSON::ParseException
                    self.{{ivar.name}} = [] of {{element_type.id}}
                  end
                else
                  self.{{ivar.name}} = [] of {{element_type.id}}
                end
              {% end %}
            {% elsif type_str.includes?("String") %}
              {% if nilable %}
                %val = {{value}}
                if %val.nil?
                  self.{{ivar.name}} = nil
                else
                  self.{{ivar.name}} = %val.to_s
                end
              {% else %}
                self.{{ivar.name}} = {{value}}.to_s
              {% end %}
            {% else %}
              # Check for enum type and other complex types
              {% resolved_type = ivar.type.union_types ? ivar.type.union_types.reject { |t| t == Nil }.first : ivar.type %}
              {% if resolved_type.ancestors.any? { |a| a.stringify == "Enum" } %}
                # Enum type
                %val = {{value}}
                {% if nilable %}
                  if %val.nil?
                    self.{{ivar.name}} = nil
                  elsif %val.is_a?({{resolved_type}})
                    self.{{ivar.name}} = %val
                  elsif %val.is_a?(String)
                    self.{{ivar.name}} = {{resolved_type}}.parse?(%val)
                  elsif %val.is_a?(Int32) || %val.is_a?(Int64)
                    self.{{ivar.name}} = {{resolved_type}}.from_value?(%val.to_i)
                  else
                    self.{{ivar.name}} = nil
                  end
                {% else %}
                  if %val.is_a?({{resolved_type}})
                    self.{{ivar.name}} = %val
                  elsif %val.is_a?(String)
                    self.{{ivar.name}} = {{resolved_type}}.parse?(%val) || {{resolved_type}}.values.first
                  elsif %val.is_a?(Int32) || %val.is_a?(Int64)
                    self.{{ivar.name}} = {{resolved_type}}.from_value?(%val.to_i) || {{resolved_type}}.values.first
                  else
                    self.{{ivar.name}} = {{resolved_type}}.values.first
                  end
                {% end %}
              {% else %}
                # For other complex types, just assign directly
                self.{{ivar.name}} = {{value}}
              {% end %}
            {% end %}
        {% end %}
      {% end %}
      else
        # Unknown attribute, skip
      end
    end
  end
end

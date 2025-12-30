module Ralph
  # Metadata about a column
  class ColumnMetadata
    property name : String
    property type_name : String
    property primary : Bool
    property default : String | Int32 | Int64 | Float64 | Bool | Nil

    def initialize(@name : String, type : Class, @primary : Bool = false, @default : String | Int32 | Int64 | Float64 | Bool | Nil = nil)
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

          query = Query::Builder.new(self.class.table_name)
            .where("#{self.class.primary_key} = ?", primary_key_value)

          sql, args = query.build_delete
          Ralph.database.execute(sql, args: args)
          result = true

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
      end
    end

    @@table_name : String = ""
    @@columns : Hash(String, ColumnMetadata) = {} of String => ColumnMetadata
    @@primary_key : String = "id"

    # Dirty tracking instance variables
    @_changed_attributes : Set(String) = Set(String).new
    @_original_attributes : Hash(String, DB::Any) = {} of String => DB::Any

    # Preloaded associations tracking
    # Stores preloaded single records (belongs_to, has_one)
    @_preloaded_one : Hash(String, Model?) = Hash(String, Model?).new
    # Stores preloaded collections (has_many)
    @_preloaded_many : Hash(String, Array(Model)) = Hash(String, Array(Model)).new
    # Tracks which associations have been preloaded
    @_preloaded_associations : Set(String) = Set(String).new

    # Set the table name for this model
    macro table(name)
      @@table_name = {{name}}
    end

    # Define a column on the model
    macro column(name, type, primary = false, default = nil)
      {% if primary %}
        {% if name.is_a?(StringLiteral) %}
          @@primary_key = {{name.id}}
        {% else %}
          @@primary_key = {{name.stringify}}
        {% end %}
      {% end %}

      # Register column metadata
      {% unless @type.has_constant?("_ralph_column_{{name}}") %}
        @@columns[{{name.stringify}}] = Ralph::ColumnMetadata.new({{name.stringify}}, {{type}}, {{primary}}, {{default}})
      {% end %}

      # Define the property with nilable type to allow uninitialized state
      @{{name}} : {{type}} | Nil

      # Getter
      def {{name}}
        {% if default %}
          @{{name}} ||= {{default}}
        {% else %}
          @{{name}}
        {% end %}
      end

      # Setter
      def {{name}}=(value)
        @{{name}} = value
      end
    end

    # Get the table name for this model
    def self.table_name : String
      @@table_name
    end

    # Get the primary key field name
    def self.primary_key : String
      @@primary_key
    end

    # Get all column metadata
    def self.columns : Hash(String, ColumnMetadata)
      @@columns
    end

    # Find a record by ID
    def self.find(id)
      query = Query::Builder.new(self.table_name)
        .where("#{@@primary_key} = ?", id)

      result = Ralph.database.query_one(query.build_select, args: query.where_args)
      return nil unless result

      record = from_result_set(result)
      result.close
      record
    end

    # Find all records
    def self.all : Array(self)
      query = Query::Builder.new(self.table_name)
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
    def self.query : Query::Builder
      Query::Builder.new(self.table_name)
    end

    # Find records matching conditions
    # The block receives a Builder and should return the modified Builder
    # (since Builder is immutable, each method returns a new instance)
    def self.query(&block : Query::Builder -> Query::Builder) : Query::Builder
      query = Query::Builder.new(self.table_name)
      block.call(query)
    end

    # Find records matching conditions (alias for query)
    def self.with_query(&block : Query::Builder -> Query::Builder) : Query::Builder
      query(&block)
    end

    # ========================================
    # Query Scopes
    # ========================================

    # Define a named scope for this model
    #
    # Scopes are reusable query fragments that can be chained together.
    # They're defined as class methods that return Query::Builder instances.
    #
    # The block receives a Query::Builder and should return it after applying conditions.
    #
    # Example without arguments:
    # ```
    # class User < Ralph::Model
    #   table "users"
    #   column id, Int64, primary: true
    #   column active, Bool
    #   column age, Int32
    #
    #   scope :active, ->(q : Query::Builder) { q.where("active = ?", true) }
    #   scope :adults, ->(q : Query::Builder) { q.where("age >= ?", 18) }
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
    #   scope :older_than, ->(q : Query::Builder, age : Int32) { q.where("age > ?", age) }
    #   scope :with_role, ->(q : Query::Builder, role : String) { q.where("role = ?", role) }
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
        def self.{{name.id}} : Query::Builder
          {{query_var_name.id}} = Query::Builder.new(self.table_name)
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
        ) : Query::Builder
          {{query_var_name.id}} = Query::Builder.new(self.table_name)
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
    def self.scoped(&block : Query::Builder -> Query::Builder) : Query::Builder
      query = Query::Builder.new(self.table_name)
      block.call(query)
    end

    # Build a query with GROUP BY clause
    def self.group_by(*columns : String) : Query::Builder
      Query::Builder.new(self.table_name).group(*columns)
    end

    # Build a query with GROUP BY clause and block
    # The block receives a Builder and should return the modified Builder
    def self.group_by(*columns : String, &block : Query::Builder -> Query::Builder) : Query::Builder
      query = Query::Builder.new(self.table_name).group(*columns)
      block.call(query)
    end

    # Build a query with DISTINCT
    def self.distinct : Query::Builder
      Query::Builder.new(self.table_name).distinct
    end

    # Build a query with DISTINCT and block
    # The block receives a Builder and should return the modified Builder
    def self.distinct(&block : Query::Builder -> Query::Builder) : Query::Builder
      query = Query::Builder.new(self.table_name).distinct
      block.call(query)
    end

    # Build a query with DISTINCT on specific columns
    def self.distinct(*columns : String) : Query::Builder
      Query::Builder.new(self.table_name).distinct(*columns)
    end

    # Build a query with DISTINCT on specific columns and block
    # The block receives a Builder and should return the modified Builder
    def self.distinct(*columns : String, &block : Query::Builder -> Query::Builder) : Query::Builder
      query = Query::Builder.new(self.table_name).distinct(*columns)
      block.call(query)
    end

    # Join an association by name
    #
    # This method looks up the association metadata and automatically
    # generates the appropriate join condition.
    #
    # Example:
    # ```
    # User.join_assoc(:posts)         # INNER JOIN posts ON posts.user_id = users.id
    # Post.join_assoc(:author, :left) # LEFT JOIN users ON users.id = posts.user_id
    # User.join_assoc(:posts, :inner, "p") # INNER JOIN posts AS p ON p.user_id = users.id
    # ```
    def self.join_assoc(association_name : Symbol, join_type : Symbol = :inner, alias as_alias : String? = nil) : Query::Builder
      query = Query::Builder.new(self.table_name)

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
    # authors.each { |a| a.posts }  # Already loaded, no additional queries
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
    def self._preload_fetch_all(query : Query::Builder) : Array(self)
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
      query = Query::Builder.new(self.table_name)
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
      query = Query::Builder.new(self.table_name)
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
      query = Query::Builder.new(self.table_name)
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
      query = Query::Builder.new(self.table_name)
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
      query = Query::Builder.new(self.table_name)
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
      query = Query::Builder.new(self.table_name)
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
    def self.find_all_with_query(query : Query::Builder) : Array(self)
      results = Ralph.database.query_all(query.build_select, args: query.where_args)
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
    def self.count_with_query(query : Query::Builder) : Int32
      result = Ralph.database.scalar(query.build_count, args: query.where_args)
      return 0 unless result

      case result
      when Int32 then result
      when Int64 then result.to_i32
      else 0
      end
    end

    # Count all records
    def self.count : Int64
      query = Query::Builder.new(self.table_name)
      result = Ralph.database.scalar(query.build_count)
      return 0_i64 unless result

      case result
      when Int32 then result.to_i64
      when Int64 then result.as(Int64)
      else 0_i64
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
      query = Query::Builder.new(self.table_name)
        .where("#{column} = ?", value)

      result = Ralph.database.scalar(query.build_count, args: query.where_args)
      return 0_i64 unless result

      case result
      when Int32 then result.to_i64
      when Int64 then result.as(Int64)
      else 0_i64
      end
    end

    # Get the sum of a column
    #
    # Example:
    # ```
    # User.sum(:age)
    # ```
    def self.sum(column : String) : Float64?
      query = Query::Builder.new(self.table_name)
      result = Ralph.database.scalar(query.build_sum(column))
      return nil unless result

      case result
      when Int32, Int64 then result.to_f64
      when Float32, Float64 then result.as(Float64)
      else nil
      end
    end

    # Get the average of a column
    #
    # Example:
    # ```
    # User.average(:age)
    # ```
    def self.average(column : String) : Float64?
      query = Query::Builder.new(self.table_name)
      result = Ralph.database.scalar(query.build_avg(column))
      return nil unless result

      case result
      when Int32, Int64 then result.to_f64
      when Float32, Float64 then result.as(Float64)
      else nil
      end
    end

    # Get the minimum value of a column
    #
    # Example:
    # ```
    # User.minimum(:age)
    # ```
    def self.minimum(column : String) : DB::Any?
      query = Query::Builder.new(self.table_name)
      Ralph.database.scalar(query.build_min(column))
    end

    # Get the maximum value of a column
    #
    # Example:
    # ```
    # User.maximum(:age)
    # ```
    def self.maximum(column : String) : DB::Any?
      query = Query::Builder.new(self.table_name)
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

      query = Query::Builder.new(self.class.table_name)
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
      # Read values and assign to instance variables via setters
      {% for ivar in @type.instance_vars %}
        {% unless ivar.name.starts_with?("_") %}
          {% type_str = ivar.type.stringify %}
          {% nilable = type_str.includes?(" | Nil") || type_str.includes?("Nil)") %}
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
          {% elsif type_str.includes?("Float64") %}
            {% if nilable %}
              self.{{ivar.name}}=rs.read(Float64 | Nil)
            {% else %}
              self.{{ivar.name}}=rs.read(Float64)
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
        {% end %}
      {% end %}

      clear_changes_information
    end

    # Check if this is a new record (not persisted)
    def new_record? : Bool
      !persisted?
    end

    # Check if this record has been persisted
    def persisted? : Bool
      !!primary_key_value
    end

    # Get the primary key value
    private def primary_key_value
      __get_by_key_name(self.class.primary_key)
    end

    # Insert a new record
    private def insert
      query = Query::Builder.new(self.class.table_name)
      data = to_h
      data.delete(self.class.primary_key) if data[self.class.primary_key]?.nil?

      sql, args = query.build_insert(data)
      id = Ralph.database.insert(sql, args: args)
      __set_by_key_name(self.class.primary_key, id)
      clear_changes_information
      true
    end

    # Update an existing record
    private def update_record
      query = Query::Builder.new(self.class.table_name)
        .where("#{self.class.primary_key} = ?", primary_key_value)

      data = to_h
      data.delete(self.class.primary_key)

      sql, args = query.build_update(data)
      Ralph.database.execute(sql, args: args)
      clear_changes_information
      true
    end

    # Convert model to hash for database operations
    # Handles serialization of advanced types (JSON, UUID, Array, Enum)
    def to_h : Hash(String, DB::Any)
      hash = {} of String => DB::Any
      {% for ivar in @type.instance_vars %}
        {% unless ivar.name.starts_with?("_") %}
          {% type_str = ivar.type.stringify %}
          # Use getter to get default values if set
          %value = {{ivar.name}}
          unless %value.nil?
            {% if type_str.includes?("JSON::Any") %}
              # Serialize JSON::Any to string
              hash[{{ivar.name.stringify}}] = %value.to_json
            {% elsif type_str.includes?("UUID") %}
              # Serialize UUID to string
              hash[{{ivar.name.stringify}}] = %value.to_s
            {% elsif type_str.includes?("Array(") %}
              # Serialize Array to JSON string
              hash[{{ivar.name.stringify}}] = %value.to_json
            {% else %}
              # Check if it's an enum type
              {% resolved_type = ivar.type.union_types ? ivar.type.union_types.reject { |t| t == Nil }.first : ivar.type %}
              {% if resolved_type.ancestors.any? { |a| a.stringify == "Enum" } %}
                # Serialize enum to string (member name)
                hash[{{ivar.name.stringify}}] = %value.to_s
              {% else %}
                # Standard types - pass through as DB::Any
                hash[{{ivar.name.stringify}}] = %value
              {% end %}
            {% end %}
          end
        {% end %}
      {% end %}
      hash
    end

    # Create a model instance from a result set
    macro from_result_set(rs)
      %instance = allocate

      # Read values and assign to instance variables via setters
      {% for ivar in @type.instance_vars %}
        {% unless ivar.name.starts_with?("_") %}
          {% type_str = ivar.type.stringify %}
          {% nilable = type_str.includes?(" | Nil") || type_str.includes?("Nil)") %}
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
          {% elsif type_str.includes?("Float64") %}
            {% if nilable %}
              %instance.{{ivar.name}}={{rs}}.read(Float64 | Nil)
            {% else %}
              %instance.{{ivar.name}}={{rs}}.read(Float64)
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
            # JSON::Any - stored as TEXT in database, parse on load
            %raw_json = {{rs}}.read(String | Nil)
            {% if nilable %}
              if %raw_json.nil?
                %instance.{{ivar.name}} = nil
              else
                begin
                  %instance.{{ivar.name}} = JSON.parse(%raw_json)
                rescue JSON::ParseException
                  %instance.{{ivar.name}} = nil
                end
              end
            {% else %}
              if %raw_json
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
            # UUID - stored as CHAR(36) or UUID in database
            %raw_uuid = {{rs}}.read(String | Nil)
            {% if nilable %}
              if %raw_uuid.nil?
                %instance.{{ivar.name}} = nil
              else
                begin
                  %instance.{{ivar.name}} = UUID.new(%raw_uuid)
                rescue ArgumentError
                  %instance.{{ivar.name}} = nil
                end
              end
            {% else %}
              if %raw_uuid
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
        {% end %}
      {% end %}

      # Clear dirty tracking
      %instance.clear_changes_information

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
          {% nilable = type_str.includes?(" | Nil") || type_str.includes?("Nil)") %}
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

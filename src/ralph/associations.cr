module Ralph
  # Exception raised when trying to destroy a record with dependent: :restrict_with_exception
  class DeleteRestrictionError < Exception
    def initialize(association_name : String)
      super("Cannot delete record because dependent #{association_name} exist")
    end
  end

  # Dependent behavior options for associations
  enum DependentBehavior
    None               # Default: do nothing
    Destroy            # Destroy associated records (runs callbacks)
    Delete             # Delete associated records (skips callbacks)
    Nullify            # Set foreign key to NULL
    RestrictWithError  # Prevent destruction if associations exist (adds error)
    RestrictWithException # Prevent destruction if associations exist (raises exception)
  end

  # Association metadata storage
  class AssociationMetadata
    property name : String
    property class_name : String
    property foreign_key : String
    property primary_key : String
    property type : Symbol # :belongs_to, :has_one, :has_many
    property through : String?
    property source : String?       # For through associations: the association name on the through model
    property table_name : String
    property dependent : DependentBehavior
    property class_name_override : Bool # True if class_name was explicitly set
    property foreign_key_override : Bool # True if foreign_key was explicitly set
    property primary_key_override : Bool # True if primary_key was explicitly set
    property polymorphic : Bool          # True if this is a polymorphic belongs_to
    property as_name : String?           # For has_many/has_one, the polymorphic interface name
    property counter_cache : String?     # Column name for counter cache on parent, or nil if disabled
    property touch : String?             # Timestamp column to update on parent, or nil if disabled
    property inverse_of : String?        # Name of the inverse association

    def initialize(
      @name : String,
      @class_name : String,
      @foreign_key : String,
      @type : Symbol,
      @table_name : String,
      @through : String? = nil,
      @source : String? = nil,
      @primary_key : String = "id",
      @dependent : DependentBehavior = DependentBehavior::None,
      @class_name_override : Bool = false,
      @foreign_key_override : Bool = false,
      @primary_key_override : Bool = false,
      @polymorphic : Bool = false,
      @as_name : String? = nil,
      @counter_cache : String? = nil,
      @touch : String? = nil,
      @inverse_of : String? = nil
    )
    end
  end

  # Associations module for defining model relationships
  #
  # This module provides macros for defining common database associations:
  # - `belongs_to` - Many-to-one relationship (e.g., a post belongs to a user)
  # - `has_one` - One-to-one relationship (e.g., a user has one profile)
  # - `has_many` - One-to-many relationship (e.g., a user has many posts)
  #
  # Polymorphic associations are also supported:
  # - `belongs_to :commentable, polymorphic: true` - Can belong to multiple model types
  # - `has_many :comments, as: :commentable` - Parent side of polymorphic relationship
  #
  # New in Phase 3.3:
  # - `counter_cache: true` - Maintain a count column on parent for has_many associations
  # - `touch: true` - Update parent timestamp when association changes
  # - Association scoping with lambda blocks
  # - Through associations: `has_many :tags, through: :posts`
  #
  # Example:
  # ```
  # class Post < Ralph::Model
  #   column id, Int64, primary: true
  #   column title, String
  #   column user_id, Int64
  #
  #   belongs_to user, touch: true
  # end
  #
  # class User < Ralph::Model
  #   column id, Int64, primary: true
  #   column name, String
  #   column posts_count, Int32, default: 0
  #   column updated_at, Time?
  #
  #   has_one profile
  #   has_many posts, counter_cache: true
  #   has_many tags, through: :posts
  # end
  # ```
  module Associations
    # Store association metadata for each model class
    @@associations : Hash(String, Hash(String, AssociationMetadata)) = Hash(String, Hash(String, AssociationMetadata)).new

    # Registry for polymorphic model lookup by class name string
    # Required because Crystal doesn't have Object.const_get like Ruby
    @@polymorphic_registry : Hash(String, Proc(Int64, Ralph::Model?)) = Hash(String, Proc(Int64, Ralph::Model?)).new

    # Registry for counter cache relationships: child_class => [{parent_class, association_name, counter_column, foreign_key}]
    @@counter_cache_registry : Hash(String, Array(NamedTuple(parent_class: String, association_name: String, counter_column: String, foreign_key: String))) = Hash(String, Array(NamedTuple(parent_class: String, association_name: String, counter_column: String, foreign_key: String))).new

    # Registry for touch relationships: child_class => [{parent_class, association_name, touch_column, foreign_key}]
    @@touch_registry : Hash(String, Array(NamedTuple(parent_class: String, association_name: String, touch_column: String, foreign_key: String))) = Hash(String, Array(NamedTuple(parent_class: String, association_name: String, touch_column: String, foreign_key: String))).new

    def self.associations : Hash(String, Hash(String, AssociationMetadata))
      @@associations
    end

    # Get the polymorphic registry
    def self.polymorphic_registry : Hash(String, Proc(Int64, Ralph::Model?))
      @@polymorphic_registry
    end

    # Get the counter cache registry
    def self.counter_cache_registry : Hash(String, Array(NamedTuple(parent_class: String, association_name: String, counter_column: String, foreign_key: String)))
      @@counter_cache_registry
    end

    # Get the touch registry
    def self.touch_registry : Hash(String, Array(NamedTuple(parent_class: String, association_name: String, touch_column: String, foreign_key: String)))
      @@touch_registry
    end

    # Register a model class for polymorphic lookup
    # This is called at runtime when models with `as:` option are loaded
    def self.register_polymorphic_type(class_name : String, finder : Proc(Int64, Ralph::Model?))
      @@polymorphic_registry[class_name] = finder
    end

    # Lookup and find a polymorphic record by class name and id
    def self.find_polymorphic(class_name : String, id : Int64) : Ralph::Model?
      finder = @@polymorphic_registry[class_name]?
      return nil if finder.nil?
      finder.call(id)
    end

    # Register a counter cache relationship
    def self.register_counter_cache(child_class : String, parent_class : String, association_name : String, counter_column : String, foreign_key : String)
      @@counter_cache_registry[child_class] ||= [] of NamedTuple(parent_class: String, association_name: String, counter_column: String, foreign_key: String)
      @@counter_cache_registry[child_class] << {parent_class: parent_class, association_name: association_name, counter_column: counter_column, foreign_key: foreign_key}
    end

    # Get counter caches for a child class
    def self.counter_caches_for(child_class : String) : Array(NamedTuple(parent_class: String, association_name: String, counter_column: String, foreign_key: String))?
      @@counter_cache_registry[child_class]?
    end

    # Register a touch relationship
    def self.register_touch(child_class : String, parent_class : String, association_name : String, touch_column : String, foreign_key : String)
      @@touch_registry[child_class] ||= [] of NamedTuple(parent_class: String, association_name: String, touch_column: String, foreign_key: String)
      @@touch_registry[child_class] << {parent_class: parent_class, association_name: association_name, touch_column: touch_column, foreign_key: foreign_key}
    end

    # Get touch relationships for a child class
    def self.touches_for(child_class : String) : Array(NamedTuple(parent_class: String, association_name: String, touch_column: String, foreign_key: String))?
      @@touch_registry[child_class]?
    end

    # Define a belongs_to association
    #
    # Options:
    # - class_name: Specify the class of the association (e.g., "User" instead of inferring from name)
    # - foreign_key: Specify a custom foreign key column (e.g., "author_id" instead of "user_id")
    # - primary_key: Specify the primary key on the associated model (defaults to "id")
    # - polymorphic: If true, this association can belong to multiple model types
    # - touch: If true, updates parent's updated_at on save; can also be a column name
    # - counter_cache: If true, maintains a count column on the parent model
    #   - true: Uses default column name (e.g., `posts_count` for `belongs_to :post`)
    #   - String: Uses custom column name (e.g., `counter_cache: "comment_count"`)
    # - optional: If true, the foreign key can be nil (default: false)
    #
    # Usage:
    # ```crystal
    # belongs_to user
    # belongs_to author, class_name: "User"
    # belongs_to author, class_name: "User", foreign_key: "writer_id"
    # belongs_to author, class_name: "User", primary_key: "uuid"
    # belongs_to commentable, polymorphic: true  # Creates commentable_id and commentable_type columns
    # belongs_to user, touch: true               # Updates user.updated_at on save
    # belongs_to user, touch: :last_post_at      # Updates user.last_post_at on save
    # belongs_to publisher, counter_cache: true  # Maintains publisher.books_count (inferred from child table)
    # belongs_to publisher, counter_cache: "total_books"  # Uses custom column name
    # ```
    macro belongs_to(name, **options)
      {%
        name_str = name.id.stringify

        # Handle polymorphic option
        polymorphic_opt = options[:polymorphic]
        is_polymorphic = polymorphic_opt == true

        # Handle class_name option
        class_name_opt = options[:class_name]
        class_name_override = class_name_opt != nil
        class_name = class_name_opt ? class_name_opt.id.stringify : name_str.camelcase

        # Handle foreign_key option
        foreign_key_opt = options[:foreign_key]
        foreign_key_override = foreign_key_opt != nil
        foreign_key = foreign_key_opt ? foreign_key_opt.id : "#{name.id}_id".id
        foreign_key_str = foreign_key.id.stringify

        # For polymorphic, we also need a type column
        type_column = "#{name.id}_type".id
        type_column_str = type_column.id.stringify

        # Handle primary_key option
        primary_key_opt = options[:primary_key]
        primary_key_override = primary_key_opt != nil
        primary_key = primary_key_opt ? primary_key_opt.id.stringify : "id"

        # Handle touch option
        touch_opt = options[:touch]
        touch_column = if touch_opt == true
                         "updated_at"
                       elsif touch_opt
                         touch_opt.id.stringify
                       else
                         nil
                       end

        # Handle counter_cache option
        # When true, infers column name from the child's table name (e.g., books -> books_count)
        # When a string, uses that as the column name
        counter_cache_opt = options[:counter_cache]
        # Get the child table name (this class) for inferring the counter column
        # We need to get it from @type which represents the current class being defined
        child_table_name = @type.name.stringify.split("::").last.underscore + "s"
        counter_cache_col = if counter_cache_opt == true
                               child_table_name + "_count"
                             elsif counter_cache_opt
                               counter_cache_opt.id.stringify
                             else
                               nil
                             end

        # Handle optional option
        optional_opt = options[:optional]
        is_optional = optional_opt == true

        type_str = @type.stringify

        # Table name derived from class_name (not used for polymorphic)
        table_name = is_polymorphic ? "" : class_name.underscore
      %}

      # Register the association metadata
      {% if @type.has_constant?("_ralph_associations") %}
        @@_ralph_associations[{{name_str}}] = Ralph::AssociationMetadata.new(
          {{name_str}},
          {% if is_polymorphic %}"Ralph::Model"{% else %}{{class_name}}{% end %},
          {{foreign_key_str}},
          :belongs_to,
          {{table_name}},
          nil,
          nil,
          {{primary_key}},
          Ralph::DependentBehavior::None,
          {{class_name_override}},
          {{foreign_key_override}},
          {{primary_key_override}},
          {{is_polymorphic}},
          nil,
          nil,
          {{touch_column}},
          nil
        )
      {% else %}
        @@_ralph_associations = Hash(String, Ralph::AssociationMetadata).new
        @@_ralph_associations[{{name_str}}] = Ralph::AssociationMetadata.new(
          {{name_str}},
          {% if is_polymorphic %}"Ralph::Model"{% else %}{{class_name}}{% end %},
          {{foreign_key_str}},
          :belongs_to,
          {{table_name}},
          nil,
          nil,
          {{primary_key}},
          Ralph::DependentBehavior::None,
          {{class_name_override}},
          {{foreign_key_override}},
          {{primary_key_override}},
          {{is_polymorphic}},
          nil,
          nil,
          {{touch_column}},
          nil
        )
        Ralph::Associations.associations[{{type_str}}] = @@_ralph_associations
      {% end %}

      {% if is_polymorphic %}
        # Polymorphic belongs_to: define both ID and type columns
        column {{foreign_key}}, Int64?
        column {{type_column}}, String?

        # Polymorphic getter - returns the associated record (any model type)
        def {{name}} : Ralph::Model?
          # Check if preloaded first
          if _has_preloaded?({{name_str}})
            return _get_preloaded_one({{name_str}})
          end

          # Track N+1 queries if enabled
          Ralph::EagerLoading.track_query(self.class.to_s, {{name_str}})

          foreign_key_value = @{{foreign_key}}
          type_value = @{{type_column}}

          return nil if foreign_key_value.nil? || type_value.nil?

          # Use the polymorphic registry to find the record
          Ralph::Associations.find_polymorphic(type_value.not_nil!, foreign_key_value.not_nil!)
        end

        # Polymorphic setter - accepts any Ralph::Model
        def {{name}}=(record : Ralph::Model?)
          _old_fk = @{{foreign_key}}
          _old_type = @{{type_column}}

          if record
            @{{type_column}} = record.class.to_s
            @{{foreign_key}} = record.id
          else
            @{{type_column}} = nil
            @{{foreign_key}} = nil
          end

          # Track change for dirty tracking
          if _old_fk != @{{foreign_key}} || _old_type != @{{type_column}}
            @_changed_attributes.add({{foreign_key_str}})
            @_changed_attributes.add({{type_column_str}})
          end
        end
      {% else %}
        # Regular belongs_to: define the foreign key column
        {% if is_optional %}
          column {{foreign_key}}, Int64?
        {% else %}
          column {{foreign_key}}, Int64
        {% end %}

        # Getter for the associated record
        def {{name}} : {{class_name.id}}?
          # Check if preloaded first
          if _has_preloaded?({{name_str}})
            return _get_preloaded_one({{name_str}}).as({{class_name.id}}?)
          end

          # Track N+1 queries if enabled
          Ralph::EagerLoading.track_query(self.class.to_s, {{name_str}})

          # Get the foreign key value
          foreign_key_value = @{{foreign_key}}

          return nil if foreign_key_value.nil?

          # Find the associated record using the configured primary key
          {% if primary_key == "id" %}
            {{class_name.id}}.find(foreign_key_value)
          {% else %}
            {{class_name.id}}.find_by({{primary_key}}, foreign_key_value)
          {% end %}
        end

        # Setter for the associated record
        def {{name}}=(record : {{class_name.id}}?)
          _old_fk = @{{foreign_key}}

          if record
            # Use the configured primary key from the associated record
            {% if primary_key == "id" %}
              @{{foreign_key}} = record.id
            {% else %}
              pk_value = record.__get_by_key_name({{primary_key}})
              @{{foreign_key}} = pk_value.as(Int64) if pk_value.is_a?(Int64)
            {% end %}
          else
            @{{foreign_key}} = nil
          end

          # Track change for dirty tracking
          if _old_fk != @{{foreign_key}}
            @_changed_attributes.add({{foreign_key_str}})
          end
        end

        # Check if the foreign key has changed
        def {{foreign_key}}_changed? : Bool
          @_changed_attributes.includes?({{foreign_key_str}})
        end

        # Get the previous foreign key value before changes
        def {{foreign_key}}_was : Int64?
          if @_original_attributes.has_key?({{foreign_key_str}})
            val = @_original_attributes[{{foreign_key_str}}]
            val.as(Int64) if val.is_a?(Int64)
          else
            @{{foreign_key}}
          end
        end

        # Build a new associated record
        def build_{{name}}(**attrs) : {{class_name.id}}
          record = {{class_name.id}}.new(**attrs)
          record
        end

        # Create a new associated record and save it
        def create_{{name}}(**attrs) : {{class_name.id}}
          record = {{class_name.id}}.new(**attrs)
          record.save
          {% if primary_key == "id" %}
            @{{foreign_key}} = record.id
          {% else %}
            pk_value = record.__get_by_key_name({{primary_key}})
            @{{foreign_key}} = pk_value.as(Int64) if pk_value.is_a?(Int64)
          {% end %}
          @_changed_attributes.add({{foreign_key_str}})
          record
        end

        # Touch the parent association (update timestamp)
        {% if touch_column %}
          def _touch_{{name}}_association!
            parent_record = {{name}}
            return unless parent_record

            parent_table = {{class_name.id}}.table_name
            parent_pk = parent_record.id
            return if parent_pk.nil?

            sql = "UPDATE \"#{parent_table}\" SET \"#{{{touch_column}}}\" = ? WHERE \"#{{{class_name.id}}.primary_key}\" = ?"
            Ralph.database.execute(sql, args: [Time.utc, parent_pk])
          end
        {% end %}

        # Counter cache callbacks
        # These methods are automatically called by setup_callbacks via annotations
        {% if counter_cache_col %}
          # Increment the parent's counter cache after this record is created
          @[Ralph::Callbacks::AfterCreate]
          def _increment_{{name}}_counter_cache
            fk_value = @{{foreign_key}}
            return if fk_value.nil?

            parent_table = {{class_name.id}}.table_name
            col = {{counter_cache_col}}
            sql = "UPDATE \"#{parent_table}\" SET \"#{col}\" = \"#{col}\" + 1 WHERE \"#{{{class_name.id}}.primary_key}\" = ?"
            Ralph.database.execute(sql, args: [fk_value])
          end

          # Decrement the parent's counter cache after this record is destroyed
          @[Ralph::Callbacks::AfterDestroy]
          def _decrement_{{name}}_counter_cache
            fk_value = @{{foreign_key}}
            return if fk_value.nil?

            parent_table = {{class_name.id}}.table_name
            col = {{counter_cache_col}}
            sql = "UPDATE \"#{parent_table}\" SET \"#{col}\" = \"#{col}\" - 1 WHERE \"#{{{class_name.id}}.primary_key}\" = ? AND \"#{col}\" > 0"
            Ralph.database.execute(sql, args: [fk_value])
          end

          # Handle counter cache updates when the foreign key changes (re-parenting)
          # This decrements the old parent's counter and increments the new parent's counter
          @[Ralph::Callbacks::BeforeUpdate]
          def _update_{{name}}_counter_cache_on_reassignment
            return unless {{foreign_key}}_changed?

            old_fk = {{foreign_key}}_was
            new_fk = @{{foreign_key}}
            parent_table = {{class_name.id}}.table_name
            col = {{counter_cache_col}}

            # Decrement old parent's counter
            if old_fk
              sql = "UPDATE \"#{parent_table}\" SET \"#{col}\" = \"#{col}\" - 1 WHERE \"#{{{class_name.id}}.primary_key}\" = ? AND \"#{col}\" > 0"
              Ralph.database.execute(sql, args: [old_fk])
            end

            # Increment new parent's counter
            if new_fk
              sql = "UPDATE \"#{parent_table}\" SET \"#{col}\" = \"#{col}\" + 1 WHERE \"#{{{class_name.id}}.primary_key}\" = ?"
              Ralph.database.execute(sql, args: [new_fk])
            end
          end

          # Register the counter cache so the parent model can provide reset methods
          def self.__register_counter_cache_{{name}}
            Ralph::Associations.register_counter_cache(
              {{type_str}},
              {{class_name}},
              {{name_str}},
              {{counter_cache_col}},
              {{foreign_key_str}}
            )
          end

          __register_counter_cache_{{name}}
        {% end %}

        # Generate preload method for this belongs_to association
        {% if is_polymorphic %}
          def self._preload_{{name}}(models : Array(self)) : Nil
            # For polymorphic belongs_to, we can't preload easily since types vary
            # Mark as preloaded but with nil to prevent N+1 tracking
            models.each { |m| m._set_preloaded_one({{name_str}}, nil) }
          end
        {% else %}
          def self._preload_{{name}}(models : Array(self)) : Nil
            return if models.empty?

            # Collect all foreign key values
            fk_values = models.compact_map do |model|
              model.{{foreign_key}}.as(Int64?)
            end.uniq

            return if fk_values.empty?

            # Fetch all associated records
            query = Ralph::Query::Builder.new({{class_name.id}}.table_name)
              .where_in({{primary_key}}, fk_values.map(&.as(Ralph::Query::DBValue)))

            records = {{class_name.id}}._preload_fetch_all(query)
            records_by_pk = Hash(Int64, {{class_name.id}}).new

            records.each do |record|
              if pk = record.id
                records_by_pk[pk] = record
              end
            end

            # Assign to models
            models.each do |model|
              fk_value = model.{{foreign_key}}.as(Int64?)
              if fk_value && (record = records_by_pk[fk_value]?)
                model._set_preloaded_one({{name_str}}, record)
              else
                model._set_preloaded_one({{name_str}}, nil)
              end
            end
          end
        {% end %}
      {% end %}
    end

    # Define a has_one association
    #
    # Options:
    # - class_name: Specify the class of the association (e.g., "Profile" instead of inferring from name)
    # - foreign_key: Specify a custom foreign key on the associated model (e.g., "owner_id" instead of "user_id")
    # - primary_key: Specify the primary key on this model (defaults to "id")
    # - as: For polymorphic associations, specify the name of the polymorphic interface
    # - dependent: Specify what happens to associated records when this record is destroyed
    #   - :destroy - Destroy associated records (runs callbacks)
    #   - :delete - Delete associated records (skips callbacks)
    #   - :nullify - Set foreign key to NULL
    #   - :restrict_with_error - Prevent destruction if associations exist (adds error)
    #   - :restrict_with_exception - Prevent destruction if associations exist (raises exception)
    #
    # Usage:
    # ```crystal
    # has_one profile
    # has_one avatar, class_name: "UserAvatar"
    # has_one avatar, class_name: "UserAvatar", foreign_key: "owner_id"
    # has_one profile, dependent: :destroy
    # has_one profile, as: :profileable  # Polymorphic association
    # ```
    macro has_one(name, **options)
      {%
        name_str = name.id.stringify

        # Handle class_name option
        class_name_opt = options[:class_name]
        class_name_override = class_name_opt != nil
        class_name = class_name_opt ? class_name_opt.id.stringify : name_str.camelcase

        # Get just the class name without namespace for the default foreign key
        type_name = @type.name.stringify.split("::").last.underscore

        # Handle 'as' option for polymorphic associations
        as_opt = options[:as]
        is_polymorphic = as_opt != nil
        as_name = as_opt ? as_opt.id.stringify : nil

        # Handle foreign_key option
        # For polymorphic, default to {as_name}_id
        foreign_key_opt = options[:foreign_key]
        foreign_key_override = foreign_key_opt != nil
        foreign_key = if foreign_key_opt
                        foreign_key_opt.id
                      elsif is_polymorphic && as_name
                        "#{as_name.id}_id".id
                      else
                        "#{type_name.id}_id".id
                      end
        foreign_key_str = foreign_key.id.stringify

        # Handle primary_key option
        primary_key_opt = options[:primary_key]
        primary_key_override = primary_key_opt != nil
        primary_key = primary_key_opt ? primary_key_opt.id.stringify : "id"

        # Handle dependent option
        dependent_opt = options[:dependent]
        dependent_sym = dependent_opt ? dependent_opt.id.stringify : "none"

        type_str = @type.stringify

        # Table name is the underscored class name
        table_name = class_name.underscore
      %}

      # Register the association metadata
      {% if @type.has_constant?("_ralph_associations") %}
        @@_ralph_associations[{{name_str}}] = Ralph::AssociationMetadata.new(
          {{name_str}},
          {{class_name}},
          {{foreign_key_str}},
          :has_one,
          {{table_name}},
          nil,
          nil,
          {{primary_key}},
          {% if dependent_sym == "destroy" %}
            Ralph::DependentBehavior::Destroy,
          {% elsif dependent_sym == "delete" %}
            Ralph::DependentBehavior::Delete,
          {% elsif dependent_sym == "nullify" %}
            Ralph::DependentBehavior::Nullify,
          {% elsif dependent_sym == "restrict_with_error" %}
            Ralph::DependentBehavior::RestrictWithError,
          {% elsif dependent_sym == "restrict_with_exception" %}
            Ralph::DependentBehavior::RestrictWithException,
          {% else %}
            Ralph::DependentBehavior::None,
          {% end %}
          {{class_name_override}},
          {{foreign_key_override}},
          {{primary_key_override}},
          false,
          {{as_name}},
          nil,
          nil,
          nil
        )
      {% else %}
        @@_ralph_associations = Hash(String, Ralph::AssociationMetadata).new
        @@_ralph_associations[{{name_str}}] = Ralph::AssociationMetadata.new(
          {{name_str}},
          {{class_name}},
          {{foreign_key_str}},
          :has_one,
          {{table_name}},
          nil,
          nil,
          {{primary_key}},
          {% if dependent_sym == "destroy" %}
            Ralph::DependentBehavior::Destroy,
          {% elsif dependent_sym == "delete" %}
            Ralph::DependentBehavior::Delete,
          {% elsif dependent_sym == "nullify" %}
            Ralph::DependentBehavior::Nullify,
          {% elsif dependent_sym == "restrict_with_error" %}
            Ralph::DependentBehavior::RestrictWithError,
          {% elsif dependent_sym == "restrict_with_exception" %}
            Ralph::DependentBehavior::RestrictWithException,
          {% else %}
            Ralph::DependentBehavior::None,
          {% end %}
          {{class_name_override}},
          {{foreign_key_override}},
          {{primary_key_override}},
          false,
          {{as_name}},
          nil,
          nil,
          nil
        )
        Ralph::Associations.associations[{{type_str}}] = @@_ralph_associations
      {% end %}

      # Register this model as a polymorphic parent if as: is specified
      {% if is_polymorphic %}
        # Register at class load time using a class method
        def self.__register_polymorphic_type_{{name}}
          Ralph::Associations.register_polymorphic_type(
            {{type_str}},
            ->(id : Int64) { {{@type}}.find(id).as(Ralph::Model?) }
          )
        end

        # Call registration immediately
        __register_polymorphic_type_{{name}}
      {% end %}

      {% if is_polymorphic %}
        # Polymorphic has_one: filter by type AND id
        def {{name}} : {{class_name.id}}?
          # Check if preloaded first
          if _has_preloaded?({{name_str}})
            return _get_preloaded_one({{name_str}}).as({{class_name.id}}?)
          end

          # Track N+1 queries if enabled
          Ralph::EagerLoading.track_query(self.class.to_s, {{name_str}})

          pk_value = self.id
          return nil if pk_value.nil?

          type_column = {{as_name}}.not_nil! + "_type"
          id_column = {{as_name}}.not_nil! + "_id"
          type_value = {{type_str}}

          # Use the find_by_conditions helper
          conditions = {
            type_column => type_value.as(DB::Any),
            id_column => pk_value.as(DB::Any)
          }
          {{class_name.id}}.find_by_conditions(conditions)
        end
      {% else %}
        # Regular has_one: Getter for the associated record
        def {{name}} : {{class_name.id}}?
          # Check if preloaded first
          if _has_preloaded?({{name_str}})
            return _get_preloaded_one({{name_str}}).as({{class_name.id}}?)
          end

          # Track N+1 queries if enabled
          Ralph::EagerLoading.track_query(self.class.to_s, {{name_str}})

          # Get the primary key value from this record
          {% if primary_key == "id" %}
            pk_value = self.id
          {% else %}
            pk_value = self.__get_by_key_name({{primary_key}})
          {% end %}
          return nil if pk_value.nil?

          # Find the associated record by foreign key
          {{class_name.id}}.find_by({{foreign_key_str}}, pk_value)
        end
      {% end %}

      {% if is_polymorphic %}
        {%
          # Compute column names at compile time
          poly_type_col = "#{as_name.id}_type".id
          poly_id_col = "#{as_name.id}_id".id
        %}

        # Setter for the associated record (polymorphic)
        def {{name}}=(record : {{class_name.id}}?)
          if record
            record.{{poly_type_col}} = {{type_str}}
            record.{{poly_id_col}} = self.id
            record.save
          end
        end

        # Build a new associated record (polymorphic)
        def build_{{name}}(**attrs) : {{class_name.id}}
          record = {{class_name.id}}.new(**attrs)
          record.{{poly_type_col}} = {{type_str}}
          record.{{poly_id_col}} = self.id
          record
        end

        # Create a new associated record and save it (polymorphic)
        def create_{{name}}(**attrs) : {{class_name.id}}
          record = {{class_name.id}}.new(**attrs)
          record.{{poly_type_col}} = {{type_str}}
          record.{{poly_id_col}} = self.id
          record.save
          record
        end
      {% else %}
        # Setter for the associated record
        def {{name}}=(record : {{class_name.id}}?)
          if record
            {% if primary_key == "id" %}
              record.{{foreign_key}} = self.id
            {% else %}
              pk_value = self.__get_by_key_name({{primary_key}})
              record.{{foreign_key}} = pk_value.as(Int64) if pk_value.is_a?(Int64)
            {% end %}
            record.save
          end
        end

        # Build a new associated record
        def build_{{name}}(**attrs) : {{class_name.id}}
          record = {{class_name.id}}.new(**attrs)
          {% if primary_key == "id" %}
            record.{{foreign_key}} = self.id
          {% else %}
            pk_value = self.__get_by_key_name({{primary_key}})
            record.{{foreign_key}} = pk_value.as(Int64) if pk_value.is_a?(Int64)
          {% end %}
          record
        end

        # Create a new associated record and save it
        def create_{{name}}(**attrs) : {{class_name.id}}
          record = {{class_name.id}}.new(**attrs)
          {% if primary_key == "id" %}
            record.{{foreign_key}} = self.id
          {% else %}
            pk_value = self.__get_by_key_name({{primary_key}})
            record.{{foreign_key}} = pk_value.as(Int64) if pk_value.is_a?(Int64)
          {% end %}
          record.save
          record
        end
      {% end %}

      # Handle dependent behavior for has_one
      {% if dependent_sym != "none" %}
        def _handle_dependent_{{name}} : Bool
          associated = {{name}}
          return true if associated.nil?

          {% if dependent_sym == "destroy" %}
            associated.destroy
          {% elsif dependent_sym == "delete" %}
            # Direct SQL delete without callbacks
            query = Ralph::Query::Builder.new({{class_name.id}}.table_name)
              .where("#{{{class_name.id}}.primary_key} = ?", associated.id)
            sql, args = query.build_delete
            Ralph.database.execute(sql, args: args)
            true
          {% elsif dependent_sym == "nullify" %}
            {% if is_polymorphic %}
              # Set both polymorphic columns to NULL
              type_column = {{as_name}}.not_nil! + "_type"
              id_column = {{as_name}}.not_nil! + "_id"
              sql = "UPDATE \"#{{{class_name.id}}.table_name}\" SET \"#{id_column}\" = NULL, \"#{type_column}\" = NULL WHERE \"#{{{class_name.id}}.primary_key}\" = ?"
              Ralph.database.execute(sql, args: [associated.id])
            {% else %}
              # Set foreign key to NULL
              sql = "UPDATE \"#{{{class_name.id}}.table_name}\" SET \"#{{{foreign_key_str}}}\" = NULL WHERE \"#{{{class_name.id}}.primary_key}\" = ?"
              Ralph.database.execute(sql, args: [associated.id])
            {% end %}
            true
          {% elsif dependent_sym == "restrict_with_error" %}
              errors.add({{name_str}}, "cannot be deleted because dependent #{{{name_str}}} exists")
            false
          {% elsif dependent_sym == "restrict_with_exception" %}
            raise Ralph::DeleteRestrictionError.new({{name_str}})
          {% else %}
            true
          {% end %}
        end
      {% end %}

      # Generate preload method for this has_one association
      def self._preload_{{name}}(models : Array(self)) : Nil
        return if models.empty?

        pk_values = models.compact_map(&.id).uniq
        return if pk_values.empty?

        {% if is_polymorphic %}
          type_column = {{as_name}}.not_nil! + "_type"
          id_column = {{as_name}}.not_nil! + "_id"
          model_type = {{type_str}}

          query = Ralph::Query::Builder.new({{class_name.id}}.table_name)
            .where("\"#{type_column}\" = ?", model_type)
            .where_in(id_column, pk_values.map(&.as(Ralph::Query::DBValue)))
        {% else %}
          query = Ralph::Query::Builder.new({{class_name.id}}.table_name)
            .where_in({{foreign_key_str}}, pk_values.map(&.as(Ralph::Query::DBValue)))
        {% end %}

        records = {{class_name.id}}._preload_fetch_all(query)
        records_by_fk = Hash(Int64, {{class_name.id}}).new

        records.each do |record|
          {% if is_polymorphic %}
            fk_attr = record._get_attribute({{as_name}}.not_nil! + "_id")
          {% else %}
            fk_attr = record._get_attribute({{foreign_key_str}})
          {% end %}
          fk_value = fk_attr.as(Int64?) if fk_attr.is_a?(Int64 | Nil)
          if fk_value
            records_by_fk[fk_value] = record
          end
        end

        models.each do |model|
          pk_value = model.id
          if pk_value && (record = records_by_fk[pk_value]?)
            model._set_preloaded_one({{name_str}}, record)
          else
            model._set_preloaded_one({{name_str}}, nil)
          end
        end
      end
    end

    # Define a has_many association
    #
    # Options:
    # - class_name: Specify the class of the association (e.g., "Post" instead of inferring from name)
    # - foreign_key: Specify a custom foreign key on the associated model (e.g., "owner_id" instead of "user_id")
    # - primary_key: Specify the primary key on this model (defaults to "id")
    # - as: For polymorphic associations, specify the name of the polymorphic interface
    # - through: For through associations, specify the intermediate association name
    # - source: For through associations, specify the source association on the through model
    # - dependent: Specify what happens to associated records when this record is destroyed
    #   - :destroy - Destroy associated records (runs callbacks)
    #   - :delete_all - Delete associated records (skips callbacks)
    #   - :nullify - Set foreign key to NULL
    #   - :restrict_with_error - Prevent destruction if associations exist (adds error)
    #   - :restrict_with_exception - Prevent destruction if associations exist (raises exception)
    #
    # Note: For counter caching, use `counter_cache: true` on the `belongs_to` side of the association.
    # This automatically generates increment/decrement/update callbacks on the child model.
    #
    # Usage:
    # ```crystal
    # has_many posts
    # has_many articles, class_name: "BlogPost"
    # has_many articles, class_name: "BlogPost", foreign_key: "writer_id"
    # has_many posts, dependent: :destroy
    # has_many posts, dependent: :delete_all
    # has_many comments, as: :commentable  # Polymorphic association
    # has_many tags, through: :post_tags   # Through association
    # has_many tags, through: :post_tags, source: :tag  # Through with custom source
    # ```
    macro has_many(name, scope_block = nil, **options)
      {%
        # Singularize the class name (e.g., "posts" -> "Post")
        name_str = name.id.stringify
        singular_name = name_str[0...-1] # Remove trailing 's'

        # Handle class_name option
        class_name_opt = options[:class_name]
        class_name_override = class_name_opt != nil
        class_name = class_name_opt ? class_name_opt.id.stringify : singular_name.camelcase

        # Get just the class name without namespace for the default foreign key
        type_name = @type.name.stringify.split("::").last.underscore

        # Handle 'as' option for polymorphic associations
        as_opt = options[:as]
        is_polymorphic = as_opt != nil
        as_name = as_opt ? as_opt.id.stringify : nil

        # Handle 'through' option for through associations
        through_opt = options[:through]
        is_through = through_opt != nil
        through_name = through_opt ? through_opt.id.stringify : nil

        # Handle 'source' option for through associations
        source_opt = options[:source]
        source_name = source_opt ? source_opt.id.stringify : singular_name

        # Handle foreign_key option
        # For polymorphic, default to {as_name}_id
        foreign_key_opt = options[:foreign_key]
        foreign_key_override = foreign_key_opt != nil
        foreign_key = if foreign_key_opt
                        foreign_key_opt.id
                      elsif is_polymorphic && as_name
                        "#{as_name.id}_id".id
                      elsif is_through
                        # For through associations, FK doesn't apply directly
                        "".id
                      else
                        "#{type_name.id}_id".id
                      end
        foreign_key_str = foreign_key.id.stringify

        # Handle primary_key option
        primary_key_opt = options[:primary_key]
        primary_key_override = primary_key_opt != nil
        primary_key = primary_key_opt ? primary_key_opt.id.stringify : "id"

        # Handle dependent option
        # Note: has_many uses :delete_all instead of :delete for consistency with Rails
        dependent_opt = options[:dependent]
        dependent_sym = dependent_opt ? dependent_opt.id.stringify : "none"

        type_str = @type.stringify

        # Table name is the underscored class name (usually plural, matching the association name)
        table_name = name_str

        # Check if we have a scope block
        has_scope = scope_block != nil
      %}

      # Register the association metadata
      {% if @type.has_constant?("_ralph_associations") %}
        @@_ralph_associations[{{name_str}}] = Ralph::AssociationMetadata.new(
          {{name_str}},
          {{class_name}},
          {{foreign_key_str}},
          :has_many,
          {{table_name}},
          {{through_name}},
          {{source_name}},
          {{primary_key}},
          {% if dependent_sym == "destroy" %}
            Ralph::DependentBehavior::Destroy,
          {% elsif dependent_sym == "delete_all" || dependent_sym == "delete" %}
            Ralph::DependentBehavior::Delete,
          {% elsif dependent_sym == "nullify" %}
            Ralph::DependentBehavior::Nullify,
          {% elsif dependent_sym == "restrict_with_error" %}
            Ralph::DependentBehavior::RestrictWithError,
          {% elsif dependent_sym == "restrict_with_exception" %}
            Ralph::DependentBehavior::RestrictWithException,
          {% else %}
            Ralph::DependentBehavior::None,
          {% end %}
          {{class_name_override}},
          {{foreign_key_override}},
          {{primary_key_override}},
          false,
          {{as_name}},
          nil,
          nil,
          nil
        )
      {% else %}
        @@_ralph_associations = Hash(String, Ralph::AssociationMetadata).new
        @@_ralph_associations[{{name_str}}] = Ralph::AssociationMetadata.new(
          {{name_str}},
          {{class_name}},
          {{foreign_key_str}},
          :has_many,
          {{table_name}},
          {{through_name}},
          {{source_name}},
          {{primary_key}},
          {% if dependent_sym == "destroy" %}
            Ralph::DependentBehavior::Destroy,
          {% elsif dependent_sym == "delete_all" || dependent_sym == "delete" %}
            Ralph::DependentBehavior::Delete,
          {% elsif dependent_sym == "nullify" %}
            Ralph::DependentBehavior::Nullify,
          {% elsif dependent_sym == "restrict_with_error" %}
            Ralph::DependentBehavior::RestrictWithError,
          {% elsif dependent_sym == "restrict_with_exception" %}
            Ralph::DependentBehavior::RestrictWithException,
          {% else %}
            Ralph::DependentBehavior::None,
          {% end %}
          {{class_name_override}},
          {{foreign_key_override}},
          {{primary_key_override}},
          false,
          {{as_name}},
          nil,
          nil,
          nil
        )
        Ralph::Associations.associations[{{type_str}}] = @@_ralph_associations
      {% end %}

      # Register this model as a polymorphic parent if as: is specified
      {% if is_polymorphic %}
        # Register at class load time using a class method
        def self.__register_polymorphic_type
          Ralph::Associations.register_polymorphic_type(
            {{type_str}},
            ->(id : Int64) { {{@type}}.find(id).as(Ralph::Model?) }
          )
        end

        # Call registration immediately
        __register_polymorphic_type
      {% end %}

      {% if is_through %}
        # Through association getter - follows the chain: self -> through -> source
        def {{name}} : Array({{class_name.id}})
          # Check if preloaded first
          if _has_preloaded?({{name_str}})
            preloaded = _get_preloaded_many({{name_str}})
            return preloaded.map(&.as({{class_name.id}})) if preloaded
          end

          # Track N+1 queries if enabled
          Ralph::EagerLoading.track_query(self.class.to_s, {{name_str}})

          # Get the primary key value from this record
          {% if primary_key == "id" %}
            pk_value = self.id
          {% else %}
            pk_value = self.__get_by_key_name({{primary_key}})
          {% end %}
          return [] of {{class_name.id}} if pk_value.nil?

          # Get the through records first
          through_records = {{through_name.id}}
          return [] of {{class_name.id}} if through_records.empty?

          # Collect IDs from source association on each through record
          source_ids = [] of Int64
          through_records.each do |through_record|
            # Access the source association on the through record
            source_assoc = through_record.{{source_name.id}}
            if source_assoc
              source_id = source_assoc.id
              source_ids << source_id if source_id
            end
          end

          return [] of {{class_name.id}} if source_ids.empty?

          # Build query with IN clause for all source IDs
          query = Ralph::Query::Builder.new({{class_name.id}}.table_name)
            .where_in("id", source_ids)

          {% if has_scope %}
            # Apply the scope block (must return the modified query)
            query = {{scope_block}}.call(query)
          {% end %}

          {{class_name.id}}.find_all_with_query(query)
        end

        # Unscoped through association getter
        def {{name}}_unscoped : Array({{class_name.id}})
          {% if primary_key == "id" %}
            pk_value = self.id
          {% else %}
            pk_value = self.__get_by_key_name({{primary_key}})
          {% end %}
          return [] of {{class_name.id}} if pk_value.nil?

          through_records = {{through_name.id}}
          return [] of {{class_name.id}} if through_records.empty?

          source_ids = [] of Int64
          through_records.each do |through_record|
            source_assoc = through_record.{{source_name.id}}
            if source_assoc
              source_id = source_assoc.id
              source_ids << source_id if source_id
            end
          end

          return [] of {{class_name.id}} if source_ids.empty?

          query = Ralph::Query::Builder.new({{class_name.id}}.table_name)
            .where_in("id", source_ids)

          {{class_name.id}}.find_all_with_query(query)
        end
      {% elsif is_polymorphic %}
        # Polymorphic has_many: filter by type AND id
        def {{name}} : Array({{class_name.id}})
          # Check if preloaded first
          if _has_preloaded?({{name_str}})
            preloaded = _get_preloaded_many({{name_str}})
            return preloaded.map(&.as({{class_name.id}})) if preloaded
          end

          # Track N+1 queries if enabled
          Ralph::EagerLoading.track_query(self.class.to_s, {{name_str}})

          pk_value = self.id
          return [] of {{class_name.id}} if pk_value.nil?

          type_column = {{as_name}}.not_nil! + "_type"
          id_column = {{as_name}}.not_nil! + "_id"
          type_value = {{type_str}}

          {% if has_scope %}
            # Build query with scope
            query = Ralph::Query::Builder.new({{class_name.id}}.table_name)
              .where("\"#{type_column}\" = ?", type_value)
              .where("\"#{id_column}\" = ?", pk_value)

            # Apply the scope block (must return the modified query)
            query = {{scope_block}}.call(query)

            {{class_name.id}}.find_all_with_query(query)
          {% else %}
            # Use the find_all_by_conditions helper
            conditions = {
              type_column => type_value.as(DB::Any),
              id_column => pk_value.as(DB::Any)
            }
            {{class_name.id}}.find_all_by_conditions(conditions)
          {% end %}
        end

        # Unscoped polymorphic getter
        def {{name}}_unscoped : Array({{class_name.id}})
          pk_value = self.id
          return [] of {{class_name.id}} if pk_value.nil?

          type_column = {{as_name}}.not_nil! + "_type"
          id_column = {{as_name}}.not_nil! + "_id"
          type_value = {{type_str}}

          conditions = {
            type_column => type_value.as(DB::Any),
            id_column => pk_value.as(DB::Any)
          }
          {{class_name.id}}.find_all_by_conditions(conditions)
        end
      {% else %}
        # Regular has_many: Getter for the associated records collection
        def {{name}} : Array({{class_name.id}})
          # Check if preloaded first
          if _has_preloaded?({{name_str}})
            preloaded = _get_preloaded_many({{name_str}})
            return preloaded.map(&.as({{class_name.id}})) if preloaded
          end

          # Track N+1 queries if enabled
          Ralph::EagerLoading.track_query(self.class.to_s, {{name_str}})

          # Get the primary key value from this record
          {% if primary_key == "id" %}
            pk_value = self.id
          {% else %}
            pk_value = self.__get_by_key_name({{primary_key}})
          {% end %}
          return [] of {{class_name.id}} if pk_value.nil?

          {% if has_scope %}
            # Build query with scope
            query = Ralph::Query::Builder.new({{class_name.id}}.table_name)
              .where("\"#{{{foreign_key_str}}}\" = ?", pk_value)

            # Apply the scope block (must return the modified query)
            query = {{scope_block}}.call(query)

            {{class_name.id}}.find_all_with_query(query)
          {% else %}
            # Find associated records by foreign key
            {{class_name.id}}.find_all_by({{foreign_key_str}}, pk_value)
          {% end %}
        end

        # Unscoped getter - bypasses any association scope
        def {{name}}_unscoped : Array({{class_name.id}})
          {% if primary_key == "id" %}
            pk_value = self.id
          {% else %}
            pk_value = self.__get_by_key_name({{primary_key}})
          {% end %}
          return [] of {{class_name.id}} if pk_value.nil?

          {{class_name.id}}.find_all_by({{foreign_key_str}}, pk_value)
        end

      {% end %}

      # Check if any associated records exist
      def {{name}}_any? : Bool
        !{{name}}.empty?
      end

      # Check if no associated records exist
      def {{name}}_empty? : Bool
        {{name}}.empty?
      end

      {% if is_through %}
        # Build a new source record (through association)
        # Note: This just builds the final record, not the through record
        def build_{{singular_name.id}}(**attrs) : {{class_name.id}}
          {{class_name.id}}.new(**attrs)
        end

        # Create a source record (through association)
        # Note: You still need to create the through record to link them
        def create_{{singular_name.id}}(**attrs) : {{class_name.id}}
          record = {{class_name.id}}.new(**attrs)
          record.save
          record
        end
      {% elsif is_polymorphic %}
        {%
          # Compute column names at compile time
          poly_type_col = "#{as_name.id}_type".id
          poly_id_col = "#{as_name.id}_id".id
        %}

        # Build a new associated record (polymorphic)
        def build_{{singular_name.id}}(**attrs) : {{class_name.id}}
          record = {{class_name.id}}.new(**attrs)
          # Set the polymorphic columns using compile-time computed names
          record.{{poly_type_col}} = {{type_str}}
          record.{{poly_id_col}} = self.id
          record
        end

        # Create a new associated record and save it (polymorphic)
        def create_{{singular_name.id}}(**attrs) : {{class_name.id}}
          record = {{class_name.id}}.new(**attrs)
          # Set the polymorphic columns using compile-time computed names
          record.{{poly_type_col}} = {{type_str}}
          record.{{poly_id_col}} = self.id
          record.save
          record
        end
      {% else %}
        # Build a new associated record
        def build_{{singular_name.id}}(**attrs) : {{class_name.id}}
          record = {{class_name.id}}.new(**attrs)
          {% if primary_key == "id" %}
            record.{{foreign_key}} = self.id
          {% else %}
            pk_value = self.__get_by_key_name({{primary_key}})
            record.{{foreign_key}} = pk_value.as(Int64) if pk_value.is_a?(Int64)
          {% end %}
          record
        end

        # Create a new associated record and save it
        def create_{{singular_name.id}}(**attrs) : {{class_name.id}}
          record = {{class_name.id}}.new(**attrs)
          {% if primary_key == "id" %}
            record.{{foreign_key}} = self.id
          {% else %}
            pk_value = self.__get_by_key_name({{primary_key}})
            record.{{foreign_key}} = pk_value.as(Int64) if pk_value.is_a?(Int64)
          {% end %}
          record.save
          record
        end
      {% end %}

      # Handle dependent behavior for has_many
      {% if dependent_sym != "none" && !is_through %}
        def _handle_dependent_{{name}} : Bool
          {% if dependent_sym == "restrict_with_error" %}
            if {{name}}_any?
              errors.add({{name_str}}, "cannot be deleted because dependent #{{{name_str}}} exist")
              return false
            end
            true
          {% elsif dependent_sym == "restrict_with_exception" %}
            if {{name}}_any?
              raise Ralph::DeleteRestrictionError.new({{name_str}})
            end
            true
          {% elsif dependent_sym == "destroy" %}
            {{name}}.each do |record|
              record.destroy
            end
            true
          {% elsif dependent_sym == "delete_all" || dependent_sym == "delete" %}
            # Direct SQL delete without callbacks
            {% if is_polymorphic %}
              pk_value = self.id
              return true if pk_value.nil?

              type_column = {{as_name}}.not_nil! + "_type"
              id_column = {{as_name}}.not_nil! + "_id"
              type_value = {{type_str}}

              sql = "DELETE FROM \"#{{{class_name.id}}.table_name}\" WHERE \"#{type_column}\" = ? AND \"#{id_column}\" = ?"
              Ralph.database.execute(sql, args: [type_value, pk_value])
            {% else %}
              {% if primary_key == "id" %}
                pk_value = self.id
              {% else %}
                pk_value = self.__get_by_key_name({{primary_key}})
              {% end %}
              return true if pk_value.nil?

              sql = "DELETE FROM \"#{{{class_name.id}}.table_name}\" WHERE \"#{{{foreign_key_str}}}\" = ?"
              Ralph.database.execute(sql, args: [pk_value])
            {% end %}
            true
          {% elsif dependent_sym == "nullify" %}
            # Set foreign key to NULL
            {% if is_polymorphic %}
              pk_value = self.id
              return true if pk_value.nil?

              type_column = {{as_name}}.not_nil! + "_type"
              id_column = {{as_name}}.not_nil! + "_id"
              type_value = {{type_str}}

              sql = "UPDATE \"#{{{class_name.id}}.table_name}\" SET \"#{id_column}\" = NULL, \"#{type_column}\" = NULL WHERE \"#{type_column}\" = ? AND \"#{id_column}\" = ?"
              Ralph.database.execute(sql, args: [type_value, pk_value])
            {% else %}
              {% if primary_key == "id" %}
                pk_value = self.id
              {% else %}
                pk_value = self.__get_by_key_name({{primary_key}})
              {% end %}
              return true if pk_value.nil?

              sql = "UPDATE \"#{{{class_name.id}}.table_name}\" SET \"#{{{foreign_key_str}}}\" = NULL WHERE \"#{{{foreign_key_str}}}\" = ?"
              Ralph.database.execute(sql, args: [pk_value])
            {% end %}
            true
          {% else %}
            true
          {% end %}
        end
      {% end %}

      # Generate preload method for this has_many association
      {% unless is_through %}
        def self._preload_{{name}}(models : Array(self)) : Nil
          return if models.empty?

          pk_values = models.compact_map(&.id).uniq
          return if pk_values.empty?

          {% if is_polymorphic %}
            type_column = {{as_name}}.not_nil! + "_type"
            id_column = {{as_name}}.not_nil! + "_id"
            model_type = {{type_str}}

            query = Ralph::Query::Builder.new({{class_name.id}}.table_name)
              .where("\"#{type_column}\" = ?", model_type)
              .where_in(id_column, pk_values.map(&.as(Ralph::Query::DBValue)))
          {% else %}
            query = Ralph::Query::Builder.new({{class_name.id}}.table_name)
              .where_in({{foreign_key_str}}, pk_values.map(&.as(Ralph::Query::DBValue)))
          {% end %}

          # Fetch records and group by foreign key
          records = {{class_name.id}}._preload_fetch_all(query)
          records_by_fk = Hash(Int64, Array({{class_name.id}})).new

          records.each do |record|
            {% if is_polymorphic %}
              fk_attr = record._get_attribute({{as_name}}.not_nil! + "_id")
            {% else %}
              fk_attr = record._get_attribute({{foreign_key_str}})
            {% end %}
            fk_value = fk_attr.as(Int64?) if fk_attr.is_a?(Int64 | Nil)
            if fk_value
              records_by_fk[fk_value] ||= [] of {{class_name.id}}
              records_by_fk[fk_value] << record
            end
          end

          models.each do |model|
            pk_value = model.id
            if pk_value
              fetched_records = records_by_fk[pk_value]? || [] of {{class_name.id}}
              model._set_preloaded_many({{name_str}}, fetched_records.map(&.as(Ralph::Model)))
            else
              model._set_preloaded_many({{name_str}}, [] of Ralph::Model)
            end
          end
        end
      {% end %}
    end
  end

  # Join macros - generate join methods for associations
  #
  # Include this module after defining associations to generate
  # convenience join methods like `join_posts`, `join_author`, etc.
  #
  # Example:
  # ```
  # class User < Ralph::Model
  #   has_many posts
  #   include Ralph::JoinMacros
  # end
  #
  # # Now you can use:
  # User.query.join_posts.where("posts.published = ?", true)
  # ```
  module JoinMacros
    # Generate join methods for all associations defined in the class
    macro generate_join_methods
      {%
        type_str = @type.stringify
        associations = Ralph::Associations.associations[type_str]?

        if associations
          associations.each do |name, meta|
            # For each association, generate a join method
            table_name = meta.class_name.underscore
            foreign_key = meta.foreign_key

            # Determine the ON clause based on association type
            if meta.type == :belongs_to
              on_clause = "\"#{table_name}\".\"id\" = \"TABLE\".\"#{foreign_key}\""
            else
              on_clause = "\"#{table_name}\".\"#{foreign_key}\" = \"TABLE\".\"id\""
            end
          end
        end
      %}
    end
  end
end

# Extend Query::Builder with association join support
module Ralph
  module Query
    class Builder
      @table : String

      # Join an association dynamically by name
      #
      # This method is similar to Model.join_assoc but can be chained
      # on an existing query builder.
      #
      # Example:
      # ```
      # User.query.join_assoc(:posts, :left).where("posts.title = ?", "Hello")
      # ```
      def join_assoc(association_name : Symbol, join_type : Symbol = :inner, alias as_alias : String? = nil) : self
        # Get the model class from the table name
        # We need to reverse-lookup the model class from the table name
        # For now, we'll use the convention that table_name is the underscored class name

        # Since we don't have direct access to the model class from the builder,
        # we'll need to look up the associations differently
        # For now, raise an error instructing to use Model.join_assoc instead
        raise "Use Model.join_assoc(:#{association_name}) instead of query.join_assoc"
      end
    end
  end
end

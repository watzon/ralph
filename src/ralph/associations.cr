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
    property table_name : String
    property dependent : DependentBehavior
    property class_name_override : Bool # True if class_name was explicitly set
    property foreign_key_override : Bool # True if foreign_key was explicitly set
    property primary_key_override : Bool # True if primary_key was explicitly set

    def initialize(
      @name : String,
      @class_name : String,
      @foreign_key : String,
      @type : Symbol,
      @table_name : String,
      @through : String? = nil,
      @primary_key : String = "id",
      @dependent : DependentBehavior = DependentBehavior::None,
      @class_name_override : Bool = false,
      @foreign_key_override : Bool = false,
      @primary_key_override : Bool = false
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
  # Example:
  # ```
  # class Post < Ralph::Model
  #   column id, Int64, primary: true
  #   column title, String
  #   column user_id, Int64
  #
  #   belongs_to user
  # end
  #
  # class User < Ralph::Model
  #   column id, Int64, primary: true
  #   column name, String
  #
  #   has_one profile
  #   has_many posts
  # end
  # ```
  module Associations
    # Store association metadata for each model class
    @@associations : Hash(String, Hash(String, AssociationMetadata)) = Hash(String, Hash(String, AssociationMetadata)).new

    def self.associations : Hash(String, Hash(String, AssociationMetadata))
      @@associations
    end

    # Define a belongs_to association
    #
    # Options:
    # - class_name: Specify the class of the association (e.g., "User" instead of inferring from name)
    # - foreign_key: Specify a custom foreign key column (e.g., "author_id" instead of "user_id")
    # - primary_key: Specify the primary key on the associated model (defaults to "id")
    #
    # Usage:
    # ```crystal
    # belongs_to user
    # belongs_to author, class_name: "User"
    # belongs_to author, class_name: "User", foreign_key: "writer_id"
    # belongs_to author, class_name: "User", primary_key: "uuid"
    # ```
    macro belongs_to(name, **options)
      {%
        name_str = name.id.stringify

        # Handle class_name option
        class_name_opt = options[:class_name]
        class_name_override = class_name_opt != nil
        class_name = class_name_opt ? class_name_opt.id.stringify : name_str.camelcase

        # Handle foreign_key option
        foreign_key_opt = options[:foreign_key]
        foreign_key_override = foreign_key_opt != nil
        foreign_key = foreign_key_opt ? foreign_key_opt.id : "#{name.id}_id".id
        foreign_key_str = foreign_key.id.stringify

        # Handle primary_key option
        primary_key_opt = options[:primary_key]
        primary_key_override = primary_key_opt != nil
        primary_key = primary_key_opt ? primary_key_opt.id.stringify : "id"

        type_str = @type.stringify

        # Table name derived from class_name
        table_name = class_name.underscore
      %}

      # Register the association metadata
      {% if @type.has_constant?("_ralph_associations") %}
        @@_ralph_associations[{{name_str}}] = AssociationMetadata.new(
          {{name_str}},
          {{class_name}},
          {{foreign_key_str}},
          :belongs_to,
          {{table_name}},
          nil,
          {{primary_key}},
          DependentBehavior::None,
          {{class_name_override}},
          {{foreign_key_override}},
          {{primary_key_override}}
        )
      {% else %}
        @@_ralph_associations = Hash(String, AssociationMetadata).new
        @@_ralph_associations[{{name_str}}] = AssociationMetadata.new(
          {{name_str}},
          {{class_name}},
          {{foreign_key_str}},
          :belongs_to,
          {{table_name}},
          nil,
          {{primary_key}},
          DependentBehavior::None,
          {{class_name_override}},
          {{foreign_key_override}},
          {{primary_key_override}}
        )
        Ralph::Associations.associations[{{type_str}}] = @@_ralph_associations
      {% end %}

      # Define the foreign key column if not already defined
      column {{foreign_key}}, Int64

      # Getter for the associated record
      def {{name}} : {{class_name.id}}?
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
        record
      end
    end

    # Define a has_one association
    #
    # Options:
    # - class_name: Specify the class of the association (e.g., "Profile" instead of inferring from name)
    # - foreign_key: Specify a custom foreign key on the associated model (e.g., "owner_id" instead of "user_id")
    # - primary_key: Specify the primary key on this model (defaults to "id")
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

        # Handle foreign_key option
        foreign_key_opt = options[:foreign_key]
        foreign_key_override = foreign_key_opt != nil
        foreign_key = foreign_key_opt ? foreign_key_opt.id : "#{type_name.id}_id".id
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
        @@_ralph_associations[{{name_str}}] = AssociationMetadata.new(
          {{name_str}},
          {{class_name}},
          {{foreign_key_str}},
          :has_one,
          {{table_name}},
          nil,
          {{primary_key}},
          {% if dependent_sym == "destroy" %}
            DependentBehavior::Destroy,
          {% elsif dependent_sym == "delete" %}
            DependentBehavior::Delete,
          {% elsif dependent_sym == "nullify" %}
            DependentBehavior::Nullify,
          {% elsif dependent_sym == "restrict_with_error" %}
            DependentBehavior::RestrictWithError,
          {% elsif dependent_sym == "restrict_with_exception" %}
            DependentBehavior::RestrictWithException,
          {% else %}
            DependentBehavior::None,
          {% end %}
          {{class_name_override}},
          {{foreign_key_override}},
          {{primary_key_override}}
        )
      {% else %}
        @@_ralph_associations = Hash(String, AssociationMetadata).new
        @@_ralph_associations[{{name_str}}] = AssociationMetadata.new(
          {{name_str}},
          {{class_name}},
          {{foreign_key_str}},
          :has_one,
          {{table_name}},
          nil,
          {{primary_key}},
          {% if dependent_sym == "destroy" %}
            DependentBehavior::Destroy,
          {% elsif dependent_sym == "delete" %}
            DependentBehavior::Delete,
          {% elsif dependent_sym == "nullify" %}
            DependentBehavior::Nullify,
          {% elsif dependent_sym == "restrict_with_error" %}
            DependentBehavior::RestrictWithError,
          {% elsif dependent_sym == "restrict_with_exception" %}
            DependentBehavior::RestrictWithException,
          {% else %}
            DependentBehavior::None,
          {% end %}
          {{class_name_override}},
          {{foreign_key_override}},
          {{primary_key_override}}
        )
        Ralph::Associations.associations[{{type_str}}] = @@_ralph_associations
      {% end %}

      # Getter for the associated record
      def {{name}} : {{class_name.id}}?
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
            query.where("#{{{class_name.id}}.primary_key} = ?", associated.id)
            sql, args = query.build_delete
            Ralph.database.execute(sql, args: args)
            true
          {% elsif dependent_sym == "nullify" %}
            # Set foreign key to NULL
            sql = "UPDATE \"#{{{class_name.id}}.table_name}\" SET \"#{{{foreign_key_str}}}\" = NULL WHERE \"#{{{class_name.id}}.primary_key}\" = ?"
            Ralph.database.execute(sql, args: [associated.id])
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
    end

    # Define a has_many association
    #
    # Options:
    # - class_name: Specify the class of the association (e.g., "Post" instead of inferring from name)
    # - foreign_key: Specify a custom foreign key on the associated model (e.g., "owner_id" instead of "user_id")
    # - primary_key: Specify the primary key on this model (defaults to "id")
    # - dependent: Specify what happens to associated records when this record is destroyed
    #   - :destroy - Destroy associated records (runs callbacks)
    #   - :delete_all - Delete associated records (skips callbacks)
    #   - :nullify - Set foreign key to NULL
    #   - :restrict_with_error - Prevent destruction if associations exist (adds error)
    #   - :restrict_with_exception - Prevent destruction if associations exist (raises exception)
    #
    # Usage:
    # ```crystal
    # has_many posts
    # has_many articles, class_name: "BlogPost"
    # has_many articles, class_name: "BlogPost", foreign_key: "writer_id"
    # has_many posts, dependent: :destroy
    # has_many posts, dependent: :delete_all
    # ```
    macro has_many(name, **options)
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

        # Handle foreign_key option
        foreign_key_opt = options[:foreign_key]
        foreign_key_override = foreign_key_opt != nil
        foreign_key = foreign_key_opt ? foreign_key_opt.id : "#{type_name.id}_id".id
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
      %}

      # Register the association metadata
      {% if @type.has_constant?("_ralph_associations") %}
        @@_ralph_associations[{{name_str}}] = AssociationMetadata.new(
          {{name_str}},
          {{class_name}},
          {{foreign_key_str}},
          :has_many,
          {{table_name}},
          nil,
          {{primary_key}},
          {% if dependent_sym == "destroy" %}
            DependentBehavior::Destroy,
          {% elsif dependent_sym == "delete_all" || dependent_sym == "delete" %}
            DependentBehavior::Delete,
          {% elsif dependent_sym == "nullify" %}
            DependentBehavior::Nullify,
          {% elsif dependent_sym == "restrict_with_error" %}
            DependentBehavior::RestrictWithError,
          {% elsif dependent_sym == "restrict_with_exception" %}
            DependentBehavior::RestrictWithException,
          {% else %}
            DependentBehavior::None,
          {% end %}
          {{class_name_override}},
          {{foreign_key_override}},
          {{primary_key_override}}
        )
      {% else %}
        @@_ralph_associations = Hash(String, AssociationMetadata).new
        @@_ralph_associations[{{name_str}}] = AssociationMetadata.new(
          {{name_str}},
          {{class_name}},
          {{foreign_key_str}},
          :has_many,
          {{table_name}},
          nil,
          {{primary_key}},
          {% if dependent_sym == "destroy" %}
            DependentBehavior::Destroy,
          {% elsif dependent_sym == "delete_all" || dependent_sym == "delete" %}
            DependentBehavior::Delete,
          {% elsif dependent_sym == "nullify" %}
            DependentBehavior::Nullify,
          {% elsif dependent_sym == "restrict_with_error" %}
            DependentBehavior::RestrictWithError,
          {% elsif dependent_sym == "restrict_with_exception" %}
            DependentBehavior::RestrictWithException,
          {% else %}
            DependentBehavior::None,
          {% end %}
          {{class_name_override}},
          {{foreign_key_override}},
          {{primary_key_override}}
        )
        Ralph::Associations.associations[{{type_str}}] = @@_ralph_associations
      {% end %}

      # Getter for the associated records collection
      def {{name}} : Array({{class_name.id}})
        # Get the primary key value from this record
        {% if primary_key == "id" %}
          pk_value = self.id
        {% else %}
          pk_value = self.__get_by_key_name({{primary_key}})
        {% end %}
        return [] of {{class_name.id}} if pk_value.nil?

        # Find associated records by foreign key
        {{class_name.id}}.find_all_by({{foreign_key_str}}, pk_value)
      end

      # Count the associated records
      def {{name}}_count : Int32
        # Get the primary key value from this record
        {% if primary_key == "id" %}
          pk_value = self.id
        {% else %}
          pk_value = self.__get_by_key_name({{primary_key}})
        {% end %}
        return 0 if pk_value.nil?

        table_name = {{class_name.id}}.table_name
        fk = {{foreign_key_str}}
        sql = "SELECT COUNT(*) FROM \"#{table_name}\" WHERE \"#{fk}\" = ?"

        result = Ralph.database.query_one(sql, args: [pk_value])
        return 0 unless result

        count = result.read(Int32)
        result.close
        count
      end

      # Check if any associated records exist
      def {{name}}_any? : Bool
        {{name}}_count > 0
      end

      # Check if no associated records exist
      def {{name}}_empty? : Bool
        {{name}}_count == 0
      end

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

      # Handle dependent behavior for has_many
      {% if dependent_sym != "none" %}
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
            {% if primary_key == "id" %}
              pk_value = self.id
            {% else %}
              pk_value = self.__get_by_key_name({{primary_key}})
            {% end %}
            return true if pk_value.nil?

            sql = "DELETE FROM \"#{{{class_name.id}}.table_name}\" WHERE \"#{{{foreign_key_str}}}\" = ?"
            Ralph.database.execute(sql, args: [pk_value])
            true
          {% elsif dependent_sym == "nullify" %}
            # Set foreign key to NULL
            {% if primary_key == "id" %}
              pk_value = self.id
            {% else %}
              pk_value = self.__get_by_key_name({{primary_key}})
            {% end %}
            return true if pk_value.nil?

            sql = "UPDATE \"#{{{class_name.id}}.table_name}\" SET \"#{{{foreign_key_str}}}\" = NULL WHERE \"#{{{foreign_key_str}}}\" = ?"
            Ralph.database.execute(sql, args: [pk_value])
            true
          {% else %}
            true
          {% end %}
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

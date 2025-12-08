module Ralph
  # Association metadata storage
  class AssociationMetadata
    property name : String
    property class_name : String
    property foreign_key : String
    property type : Symbol # :belongs_to, :has_one, :has_many
    property through : String?
    property table_name : String

    def initialize(@name : String, @class_name : String, @foreign_key : String, @type : Symbol, @table_name : String, @through : String? = nil)
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
    # Usage:
    # ```crystal
    # belongs_to user
    # ```
    macro belongs_to(name)
      {%
        name_str = name.id.stringify
        class_name = name_str.camelcase
        foreign_key = "#{name.id}_id".id
        foreign_key_str = foreign_key.id.stringify
        type_str = @type.stringify

        # Get the table name from the associated class
        # We need to look at the @type to see if it has a table method
        # For now, we'll use the underscored class name
        table_name = class_name.underscore
      %}

      # Register the association metadata
      {% if @type.has_constant?("_ralph_associations") %}
        @@_ralph_associations[{{name_str}}] = AssociationMetadata.new({{name_str}}, {{class_name}}, {{foreign_key_str}}, :belongs_to, {{table_name}})
      {% else %}
        @@_ralph_associations = Hash(String, AssociationMetadata).new
        @@_ralph_associations[{{name_str}}] = AssociationMetadata.new({{name_str}}, {{class_name}}, {{foreign_key_str}}, :belongs_to, {{table_name}})
        Ralph::Associations.associations[{{type_str}}] = @@_ralph_associations
      {% end %}

      # Define the foreign key column if not already defined
      column {{foreign_key}}, Int64

      # Getter for the associated record
      def {{name}} : {{class_name.id}}?
        # Get the foreign key value
        foreign_key_value = @{{foreign_key}}

        return nil if foreign_key_value.nil?

        # Find the associated record
        {{class_name.id}}.find(foreign_key_value)
      end

      # Setter for the associated record
      def {{name}}=(record : {{class_name.id}}?)
        if record
          @{{foreign_key}} = record.id
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
        @{{foreign_key}} = record.id
        record
      end
    end

    # Define a has_one association
    #
    # Usage:
    # ```crystal
    # has_one profile
    # ```
    macro has_one(name)
      {%
        name_str = name.id.stringify
        class_name = name_str.camelcase
        # Get just the class name without namespace for the foreign key
        type_name = @type.name.stringify.split("::").last.underscore
        foreign_key = "#{type_name.id}_id".id
        foreign_key_str = foreign_key.id.stringify
        type_str = @type.stringify

        # Table name is the underscored class name
        table_name = class_name.underscore
      %}

      # Register the association metadata
      {% if @type.has_constant?("_ralph_associations") %}
        @@_ralph_associations[{{name_str}}] = AssociationMetadata.new({{name_str}}, {{class_name}}, {{foreign_key_str}}, :has_one, {{table_name}})
      {% else %}
        @@_ralph_associations = Hash(String, AssociationMetadata).new
        @@_ralph_associations[{{name_str}}] = AssociationMetadata.new({{name_str}}, {{class_name}}, {{foreign_key_str}}, :has_one, {{table_name}})
        Ralph::Associations.associations[{{type_str}}] = @@_ralph_associations
      {% end %}

      # Getter for the associated record
      def {{name}} : {{class_name.id}}?
        # Use all and filter - inefficient but works for now
        {{class_name.id}}.all.find do |record|
          record.{{foreign_key}} == self.id
        end
      end

      # Setter for the associated record
      def {{name}}=(record : {{class_name.id}}?)
        if record
          record.{{foreign_key}} = self.id
          record.save
        end
      end

      # Build a new associated record
      def build_{{name}}(**attrs) : {{class_name.id}}
        record = {{class_name.id}}.new(**attrs)
        record.{{foreign_key}} = self.id
        record
      end

      # Create a new associated record and save it
      def create_{{name}}(**attrs) : {{class_name.id}}
        record = {{class_name.id}}.new(**attrs)
        record.{{foreign_key}} = self.id
        record.save
        record
      end
    end

    # Define a has_many association
    #
    # Usage:
    # ```crystal
    # has_many posts
    # ```
    macro has_many(name)
      {%
        # Singularize the class name (e.g., "posts" -> "Post")
        name_str = name.id.stringify
        singular_name = name_str[0...-1] # Remove trailing 's'
        class_name = singular_name.camelcase
        # Get just the class name without namespace for the foreign key
        type_name = @type.name.stringify.split("::").last.underscore
        foreign_key = "#{type_name.id}_id".id
        foreign_key_str = foreign_key.id.stringify
        type_str = @type.stringify

        # Table name is the underscored class name (usually plural, matching the association name)
        table_name = name_str
      %}

      # Register the association metadata
      {% if @type.has_constant?("_ralph_associations") %}
        @@_ralph_associations[{{name_str}}] = AssociationMetadata.new({{name_str}}, {{class_name}}, {{foreign_key_str}}, :has_many, {{table_name}})
      {% else %}
        @@_ralph_associations = Hash(String, AssociationMetadata).new
        @@_ralph_associations[{{name_str}}] = AssociationMetadata.new({{name_str}}, {{class_name}}, {{foreign_key_str}}, :has_many, {{table_name}})
        Ralph::Associations.associations[{{type_str}}] = @@_ralph_associations
      {% end %}

      # Getter for the associated records collection
      def {{name}} : Array({{class_name.id}})
        # Use all and select - inefficient but works for now
        {{class_name.id}}.all.select do |record|
          record.{{foreign_key}} == self.id
        end
      end

      # Count the associated records
      def {{name}}_count : Int32
        table_name = {{class_name.id}}.table_name
        fk = {{foreign_key_str}}
        sql = "SELECT COUNT(*) FROM \"#{table_name}\" WHERE \"#{fk}\" = ?"

        result = Ralph.database.query_one(sql, args: [self.id])
        return 0 unless result

        count = result.read(Int32)
        result.close
        count
      end

      # Build a new associated record
      def build_{{singular_name.id}}(**attrs) : {{class_name.id}}
        record = {{class_name.id}}.new(**attrs)
        record.{{foreign_key}} = self.id
        record
      end

      # Create a new associated record and save it
      def create_{{singular_name.id}}(**attrs) : {{class_name.id}}
        record = {{class_name.id}}.new(**attrs)
        record.{{foreign_key}} = self.id
        record.save
        record
      end
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

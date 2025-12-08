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

    @@table_name : String = ""
    @@columns : Hash(String, ColumnMetadata) = {} of String => ColumnMetadata
    @@primary_key : String = "id"

    # Dirty tracking instance variables
    @_changed_attributes : Set(String) = Set(String).new
    @_original_attributes : Hash(String, DB::Any) = {} of String => DB::Any

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
        @@columns[{{name.stringify}}] = ColumnMetadata.new({{name.stringify}}, {{type}}, {{primary}}, {{default}})
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
      query.where("#{@@primary_key} = ?", id)

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
    def self.query(&block : Query::Builder ->) : Query::Builder
      query = Query::Builder.new(self.table_name)
      block.call(query)
      query
    end

    # Find records matching conditions (alias for query)
    def self.with_query(&block : Query::Builder ->) : Query::Builder
      query(&block)
    end

    # Build a query with GROUP BY clause
    def self.group_by(*columns : String) : Query::Builder
      query = Query::Builder.new(self.table_name)
      query.group(*columns)
      query
    end

    # Build a query with GROUP BY clause and block
    def self.group_by(*columns : String, &block : Query::Builder ->) : Query::Builder
      query = Query::Builder.new(self.table_name)
      query.group(*columns)
      block.call(query)
      query
    end

    # Build a query with DISTINCT
    def self.distinct : Query::Builder
      query = Query::Builder.new(self.table_name)
      query.distinct
    end

    # Build a query with DISTINCT and block
    def self.distinct(&block : Query::Builder ->) : Query::Builder
      query = Query::Builder.new(self.table_name)
      query.distinct
      block.call(query)
      query
    end

    # Build a query with DISTINCT on specific columns
    def self.distinct(*columns : String) : Query::Builder
      query = Query::Builder.new(self.table_name)
      query.distinct(*columns)
      query
    end

    # Build a query with DISTINCT on specific columns and block
    def self.distinct(*columns : String, &block : Query::Builder ->) : Query::Builder
      query = Query::Builder.new(self.table_name)
      query.distinct(*columns)
      block.call(query)
      query
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
      query
    end

    # Find the first record matching conditions
    def self.first : self?
      query = Query::Builder.new(self.table_name)
      query.limit(1)
      query.order(@@primary_key, :asc)

      result = Ralph.database.query_one(query.build_select)
      return nil unless result

      record = from_result_set(result)
      result.close
      record
    end

    # Find the last record
    def self.last : self?
      query = Query::Builder.new(self.table_name)
      query.limit(1)
      query.order(@@primary_key, :desc)

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
      query.where("#{column} = ?", value)
      query.limit(1)

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
      query.where("#{column} = ?", value)

      results = Ralph.database.query_all(query.build_select, args: query.where_args)
      records = [] of self
      results.each do
        records << from_result_set(results)
      end
      records
    ensure
      results.close if results
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

    # Count records matching a column value
    def self.count_by(column : String, value) : Int64
      query = Query::Builder.new(self.table_name)
      query.where("#{column} = ?", value)

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
      query.where("#{self.class.primary_key} = ?", primary_key_value)

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
      query.where("#{self.class.primary_key} = ?", primary_key_value)

      data = to_h
      data.delete(self.class.primary_key)

      sql, args = query.build_update(data)
      Ralph.database.execute(sql, args: args)
      clear_changes_information
      true
    end

    # Convert model to hash
    def to_h : Hash(String, DB::Any)
      hash = {} of String => DB::Any
      {% for ivar in @type.instance_vars %}
        {% unless ivar.name.starts_with?("_") %}
          value = {{ivar.name}}
          hash[{{ivar.name.stringify}}] = value unless value.nil?
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
          {% elsif type_str.includes?("String") %}
            {% if nilable %}
              %instance.{{ivar.name}}={{rs}}.read(String | Nil)
            {% else %}
              %instance.{{ivar.name}}={{rs}}.read(String)
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
          {% else %}
            %instance.{{ivar.name}}={{rs}}.read(String | Nil)
          {% end %}
        {% end %}
      {% end %}

      # Clear dirty tracking
      %instance.clear_changes_information

      %instance
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
            {% else %}
              # For complex types (Array, Hash, etc.), just assign directly
              self.{{ivar.name}} = {{value}}
            {% end %}
        {% end %}
      {% end %}
      else
        # Unknown attribute, skip
      end
    end
  end
end

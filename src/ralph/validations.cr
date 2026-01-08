require "./validations/*"

module Ralph
  module Validations
    # Annotation to mark a method as a validation method
    annotation ValidationMethod
    end

    macro included
      # Errors object accessor (using private ivar name to avoid conflicts)
      def errors : Validations::Errors
        @_ralph_errors ||= Validations::Errors.new
      end

      def invalid? : Bool
        !valid?
      end
    end

    # Declare a validation with a block
    macro validate(attribute, message, &block)
      def _ralph_validate_{{attribute.id}} : Bool
        begin
          %result = {{block.body}}
          unless %result
            errors.add({{attribute.id.stringify}}, {{message}})
          end
          %result
        end
      end
    end

    # Presence validation - ensures attribute is not nil/blank
    #
    # ```
    # validates_presence_of :name
    # validates_presence_of :email, message: "is required"
    # ```
    macro validates_presence_of(attribute, message = nil)
      def _ralph_validate_presence_{{attribute.id}} : Nil
        %value = @{{attribute.id}}
        %is_blank = case %value
        when nil then true
        when String then %value.empty?
        when Array then %value.empty?
        else false
        end

        if %is_blank
          {% if message %}
            errors.add({{attribute.id.stringify}}, :blank, {{message}})
          {% else %}
            errors.add({{attribute.id.stringify}}, :blank)
          {% end %}
        end
      end
    end

    # Length validation - ensures attribute length is within range
    #
    # ```
    # validates_length_of :name, min: 3, max: 50
    # validates_length_of :password, minimum: 8, message: "is too short"
    # validates_length_of :username, range: 3..20
    # ```
    macro validates_length_of(attribute, min = nil, max = nil, minimum = nil, maximum = nil, range = nil, message = nil)
      {%
        min_val = min || minimum
        max_val = max || maximum
      %}

      def _ralph_validate_length_{{attribute.id}} : Nil
        %value = @{{attribute.id}}

        if %value.is_a?(String)
          %length = %value.size

          {% if range %}
            {% range_min = range.begin %}
            {% range_max = range.end %}
            if %length < {{range_min}} || %length > {{range_max}}
              {% if message %}
                errors.add({{attribute.id.stringify}}, :wrong_length, {{message}}, count: {{range_max}} - {{range_min}})
              {% else %}
                errors.add({{attribute.id.stringify}}, :wrong_length, minimum: {{range_min}}, maximum: {{range_max}})
              {% end %}
            end
          {% else %}
            {% if min_val %}
              if %length < {{min_val}}
                {% if message %}
                  errors.add({{attribute.id.stringify}}, :too_short, {{message}}, count: {{min_val}})
                {% else %}
                  errors.add({{attribute.id.stringify}}, :too_short, count: {{min_val}})
                {% end %}
              end
            {% end %}

            {% if max_val %}
              if %length > {{max_val}}
                {% if message %}
                  errors.add({{attribute.id.stringify}}, :too_long, {{message}}, count: {{max_val}})
                {% else %}
                  errors.add({{attribute.id.stringify}}, :too_long, count: {{max_val}})
                {% end %}
              end
            {% end %}
          {% end %}
        end
      end
    end

    # Format validation - ensures attribute matches regex pattern
    #
    # ```
    # validates_format_of :email, pattern: /@/
    # validates_format_of :username, pattern: /^[a-zA-Z0-9_]+$/, message: "contains invalid characters"
    # ```
    macro validates_format_of(attribute, pattern, message = nil)
      def _ralph_validate_format_{{attribute.id}} : Nil
        %value = @{{attribute.id}}
        if %value.is_a?(String) && !%value.matches?({{pattern}})
          {% if message %}
            errors.add({{attribute.id.stringify}}, :invalid, {{message}})
          {% else %}
            errors.add({{attribute.id.stringify}}, :invalid)
          {% end %}
        end
      end
    end

    # Numericality validation - ensures attribute is numeric
    #
    # ```
    # validates_numericality_of :age
    # validates_numericality_of :price, message: "must be a number"
    # ```
    macro validates_numericality_of(attribute, message = nil)
      def _ralph_validate_numericality_{{attribute.id}} : Nil
        %value = @{{attribute.id}}
        %is_numeric = case %value
        when Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64, Float32, Float64 then true
        when String then %value.to_f64?
        else nil
        end

        if %is_numeric.nil? || (%is_numeric.is_a?(Bool) && !%is_numeric)
          {% if message %}
            errors.add({{attribute.id.stringify}}, :not_a_number, {{message}})
          {% else %}
            errors.add({{attribute.id.stringify}}, :not_a_number)
          {% end %}
        end
      end
    end

    # Inclusion validation - ensures attribute is in allowed values
    #
    # ```
    # validates_inclusion_of :status, allow: ["draft", "published", "archived"]
    # validates_inclusion_of :role, allow: ["user", "admin"], message: "is not a valid role"
    # ```
    macro validates_inclusion_of(attribute, allow, message = nil)
      def _ralph_validate_inclusion_{{attribute.id}} : Nil
        %value = @{{attribute.id}}
        unless {{allow}}.includes?(%value)
          {% if message %}
            errors.add({{attribute.id.stringify}}, :inclusion, {{message}})
          {% else %}
            errors.add({{attribute.id.stringify}}, :inclusion)
          {% end %}
        end
      end
    end

    # Exclusion validation - ensures attribute is NOT in forbidden values
    #
    # ```
    # validates_exclusion_of :username, forbid: ["admin", "root"]
    # validates_exclusion_of :email, forbid: ["blocked@example.com"], message: "is not allowed"
    # ```
    macro validates_exclusion_of(attribute, forbid, message = nil)
      def _ralph_validate_exclusion_{{attribute.id}} : Nil
        %value = @{{attribute.id}}
        if {{forbid}}.includes?(%value)
          {% if message %}
            errors.add({{attribute.id.stringify}}, :exclusion, {{message}})
          {% else %}
            errors.add({{attribute.id.stringify}}, :exclusion)
          {% end %}
        end
      end
    end

    # Uniqueness validation - ensures attribute is unique in the database
    #
    # ```
    # validates_uniqueness_of :email
    # validates_uniqueness_of :username, message: "is already taken"
    # ```
    macro validates_uniqueness_of(attribute, message = nil)
      def _ralph_validate_uniqueness_{{attribute.id}} : Nil
        %value = @{{attribute.id}}

        # Skip validation if value is nil
        return if %value.nil?

        # Build query to check for existing records
        %query = Query::Builder.new(self.class.table_name)
          .where("#{{{attribute.id.stringify}}} = ?", %value)

        # Exclude current record if it's persisted
        if persisted?
          %pk_value = primary_key_value
          %query = %query.where("#{self.class.primary_key} != ?", %pk_value) if %pk_value
        end

        %result = Ralph.database.query_one(%query.build_select, args: %query.where_args)
        if %result
          %result.close
          {% if message %}
            errors.add({{attribute.id.stringify}}, :taken, {{message}})
          {% else %}
            errors.add({{attribute.id.stringify}}, :taken)
          {% end %}
        end
      end
    end
  end
end

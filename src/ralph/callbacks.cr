module Ralph
  module Callbacks
    # Callback type annotations
    annotation BeforeSave
    end

    annotation AfterSave
    end

    annotation BeforeCreate
    end

    annotation AfterCreate
    end

    annotation BeforeUpdate
    end

    annotation AfterUpdate
    end

    annotation BeforeDestroy
    end

    annotation AfterDestroy
    end

    annotation BeforeValidation
    end

    annotation AfterValidation
    end

    # Conditional callback options - use with if/unless on callback methods
    annotation CallbackOptions
    end

    # Call this macro at the end of your class definition to set up callbacks
    macro setup_callbacks
      # Override save to run callbacks
      def save : Bool
        # Run before_validation callbacks
        {% for meth in @type.methods %}
          {% if meth.annotation(Ralph::Callbacks::BeforeValidation) %}
            {% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
            {% if options %}
              {% if_method = options[:if] %}
              {% unless_method = options[:unless] %}
              {% if if_method && unless_method %}
                if {{if_method.id}} && !{{unless_method.id}}
                  {{meth.name}}
                end
              {% elsif if_method %}
                if {{if_method.id}}
                  {{meth.name}}
                end
              {% elsif unless_method %}
                if !{{unless_method.id}}
                  {{meth.name}}
                end
              {% else %}
                {{meth.name}}
              {% end %}
            {% else %}
              {{meth.name}}
            {% end %}
          {% end %}
        {% end %}

        # Run validations
        is_valid = valid?

        # Run after_validation callbacks
        {% for meth in @type.methods %}
          {% if meth.annotation(Ralph::Callbacks::AfterValidation) %}
            {% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
            {% if options %}
              {% if_method = options[:if] %}
              {% unless_method = options[:unless] %}
              {% if if_method && unless_method %}
                if {{if_method.id}} && !{{unless_method.id}}
                  {{meth.name}}
                end
              {% elsif if_method %}
                if {{if_method.id}}
                  {{meth.name}}
                end
              {% elsif unless_method %}
                if !{{unless_method.id}}
                  {{meth.name}}
                end
              {% else %}
                {{meth.name}}
              {% end %}
            {% else %}
              {{meth.name}}
            {% end %}
          {% end %}
        {% end %}

        # Return false if validations failed
        return false unless is_valid

        # Run before_save callbacks
        {% for meth in @type.methods %}
          {% if meth.annotation(Ralph::Callbacks::BeforeSave) %}
            {% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
            {% if options %}
              {% if_method = options[:if] %}
              {% unless_method = options[:unless] %}
              {% if if_method && unless_method %}
                if {{if_method.id}} && !{{unless_method.id}}
                  {{meth.name}}
                end
              {% elsif if_method %}
                if {{if_method.id}}
                  {{meth.name}}
                end
              {% elsif unless_method %}
                if !{{unless_method.id}}
                  {{meth.name}}
                end
              {% else %}
                {{meth.name}}
              {% end %}
            {% else %}
              {{meth.name}}
            {% end %}
          {% end %}
        {% end %}

        result = if new_record?
          # Run before_create callbacks
          {% for meth in @type.methods %}
            {% if meth.annotation(Ralph::Callbacks::BeforeCreate) %}
              {% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
              {% if options %}
                {% if_method = options[:if] %}
                {% unless_method = options[:unless] %}
                {% if if_method && unless_method %}
                  if {{if_method.id}} && !{{unless_method.id}}
                    {{meth.name}}
                  end
                {% elsif if_method %}
                  if {{if_method.id}}
                    {{meth.name}}
                  end
                {% elsif unless_method %}
                  unless {{unless_method.id}}
                    {{meth.name}}
                  end
                {% else %}
                  {{meth.name}}
                {% end %}
              {% else %}
                {{meth.name}}
              {% end %}
            {% end %}
          {% end %}

          insert_result = insert

          if insert_result
            # Run after_create callbacks
            {% for meth in @type.methods %}
              {% if meth.annotation(Ralph::Callbacks::AfterCreate) %}
                {% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
                {% if options %}
                  {% if_method = options[:if] %}
                  {% unless_method = options[:unless] %}
                  {% if if_method && unless_method %}
                    if {{if_method.id}} && !{{unless_method.id}}
                      {{meth.name}}
                    end
                  {% elsif if_method %}
                    if {{if_method.id}}
                      {{meth.name}}
                    end
                  {% elsif unless_method %}
                    unless {{unless_method.id}}
                      {{meth.name}}
                    end
                  {% else %}
                    {{meth.name}}
                  {% end %}
                {% else %}
                  {{meth.name}}
                {% end %}
              {% end %}
            {% end %}
          end

          insert_result
        else
          # Run before_update callbacks
          {% for meth in @type.methods %}
            {% if meth.annotation(Ralph::Callbacks::BeforeUpdate) %}
              {% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
              {% if options %}
                {% if_method = options[:if] %}
                {% unless_method = options[:unless] %}
                {% if if_method && unless_method %}
                  if {{if_method.id}} && !{{unless_method.id}}
                    {{meth.name}}
                  end
                {% elsif if_method %}
                  if {{if_method.id}}
                    {{meth.name}}
                  end
                {% elsif unless_method %}
                  unless {{unless_method.id}}
                    {{meth.name}}
                  end
                {% else %}
                  {{meth.name}}
                {% end %}
              {% else %}
                {{meth.name}}
              {% end %}
            {% end %}
          {% end %}

          update_result = update_record

          if update_result
            # Run after_update callbacks
            {% for meth in @type.methods %}
              {% if meth.annotation(Ralph::Callbacks::AfterUpdate) %}
                {% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
                {% if options %}
                  {% if_method = options[:if] %}
                  {% unless_method = options[:unless] %}
                  {% if if_method && unless_method %}
                    if {{if_method.id}} && !{{unless_method.id}}
                      {{meth.name}}
                    end
                  {% elsif if_method %}
                    if {{if_method.id}}
                      {{meth.name}}
                    end
                  {% elsif unless_method %}
                    unless {{unless_method.id}}
                      {{meth.name}}
                    end
                  {% else %}
                    {{meth.name}}
                  {% end %}
                {% else %}
                  {{meth.name}}
                {% end %}
              {% end %}
            {% end %}
          end

          update_result
        end

        if result
          # Run after_save callbacks
          {% for meth in @type.methods %}
            {% if meth.annotation(Ralph::Callbacks::AfterSave) %}
              {% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
              {% if options %}
                {% if_method = options[:if] %}
                {% unless_method = options[:unless] %}
                {% if if_method && unless_method %}
                  if {{if_method.id}} && !{{unless_method.id}}
                    {{meth.name}}
                  end
                {% elsif if_method %}
                  if {{if_method.id}}
                    {{meth.name}}
                  end
                {% elsif unless_method %}
                  unless {{unless_method.id}}
                    {{meth.name}}
                  end
                {% else %}
                  {{meth.name}}
                {% end %}
              {% else %}
                {{meth.name}}
              {% end %}
            {% end %}
          {% end %}
        end

        result
      end

      # Override destroy to run callbacks
      def destroy : Bool
        return false if new_record?

        # Run before_destroy callbacks
        {% for meth in @type.methods %}
          {% if meth.annotation(Ralph::Callbacks::BeforeDestroy) %}
            {% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
            {% if options %}
              {% if_method = options[:if] %}
              {% unless_method = options[:unless] %}
              {% if if_method && unless_method %}
                if {{if_method.id}} && !{{unless_method.id}}
                  {{meth.name}}
                end
              {% elsif if_method %}
                if {{if_method.id}}
                  {{meth.name}}
                end
              {% elsif unless_method %}
                if !{{unless_method.id}}
                  {{meth.name}}
                end
              {% else %}
                {{meth.name}}
              {% end %}
            {% else %}
              {{meth.name}}
            {% end %}
          {% end %}
        {% end %}

        query = Query::Builder.new(self.class.table_name)
        query.where("#{self.class.primary_key} = ?", primary_key_value)

        sql, args = query.build_delete
        Ralph.database.execute(sql, args: args)
        result = true

        if result
          # Run after_destroy callbacks
          {% for meth in @type.methods %}
            {% if meth.annotation(Ralph::Callbacks::AfterDestroy) %}
              {% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
              {% if options %}
                {% if_method = options[:if] %}
                {% unless_method = options[:unless] %}
                {% if if_method && unless_method %}
                  if {{if_method.id}} && !{{unless_method.id}}
                    {{meth.name}}
                  end
                {% elsif if_method %}
                  if {{if_method.id}}
                    {{meth.name}}
                  end
                {% elsif unless_method %}
                  unless {{unless_method.id}}
                    {{meth.name}}
                  end
                {% else %}
                  {{meth.name}}
                {% end %}
              {% else %}
                {{meth.name}}
              {% end %}
            {% end %}
          {% end %}
        end

        result
      end
    end
  end
end

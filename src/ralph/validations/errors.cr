module Ralph
  module Validations
    # Represents a single validation error with structured data
    #
    # This class provides i18n-ready error information with error codes
    # and interpolation options for generating translated messages.
    #
    # ## Example
    #
    # ```
    # error = ValidationError.new(:blank)
    # error.message # => "can't be blank"
    #
    # error = ValidationError.new(:too_short, count: 3)
    # error.message # => "is too short (minimum is 3 characters)"
    # error.options # => {count: 3}
    # ```
    class ValidationError
      # The error code (e.g., :blank, :too_short, :invalid)
      getter code : Symbol

      # The human-readable message
      getter message : String

      # Additional options for interpolation (e.g., count, minimum, maximum)
      getter options : Hash(Symbol, String | Int32 | Int64 | Float64 | Bool | Nil)

      def initialize(@code : Symbol, @message : String = "", **opts)
        @options = opts.to_h.transform_values(&.as(String | Int32 | Int64 | Float64 | Bool | Nil))
        @message = default_message if @message.empty?
      end

      # Generate the default message based on error code and options
      private def default_message : String
        case @code
        when :blank
          "can't be blank"
        when :empty
          "can't be empty"
        when :invalid
          "is invalid"
        when :taken
          "has already been taken"
        when :too_short
          count = @options[:count]? || @options[:minimum]?
          "is too short (minimum is #{count} characters)"
        when :too_long
          count = @options[:count]? || @options[:maximum]?
          "is too long (maximum is #{count} characters)"
        when :wrong_length
          count = @options[:count]?
          "is the wrong length (should be #{count} characters)"
        when :not_a_number
          "is not a number"
        when :not_an_integer
          "must be an integer"
        when :greater_than
          count = @options[:count]?
          "must be greater than #{count}"
        when :greater_than_or_equal_to
          count = @options[:count]?
          "must be greater than or equal to #{count}"
        when :less_than
          count = @options[:count]?
          "must be less than #{count}"
        when :less_than_or_equal_to
          count = @options[:count]?
          "must be less than or equal to #{count}"
        when :equal_to
          count = @options[:count]?
          "must be equal to #{count}"
        when :other_than
          count = @options[:count]?
          "must be other than #{count}"
        when :inclusion
          "is not included in the list"
        when :exclusion
          "is reserved"
        when :confirmation
          "doesn't match confirmation"
        when :accepted
          "must be accepted"
        when :present
          "must be blank"
        else
          "is invalid"
        end
      end

      # Convert to a simple string for backward compatibility
      def to_s : String
        @message
      end

      # Compare errors by code
      def ==(other : ValidationError) : Bool
        @code == other.code && @message == other.message
      end
    end

    # Stores validation errors for a model
    #
    # Errors provides both backward-compatible string access and
    # structured error access for i18n and detailed error handling.
    #
    # ## Basic Usage
    #
    # ```
    # errors = Errors.new
    # errors.add("name", "can't be blank")
    # errors.add("email", :taken)
    # errors.add("password", :too_short, count: 8)
    #
    # errors.full_messages # => ["name can't be blank", "email has already been taken", "password is too short (minimum is 8 characters)"]
    # errors.details       # => {"name" => [{error: :blank}], "email" => [{error: :taken}], ...}
    # ```
    class Errors
      @errors : Hash(String, Array(ValidationError))

      def initialize
        @errors = Hash(String, Array(ValidationError)).new
      end

      # Add an error for a specific attribute (string message - backward compatible)
      def add(attribute : String, message : String)
        # Infer code from common messages
        code = infer_code(message)
        @errors[attribute] ||= [] of ValidationError
        @errors[attribute] << ValidationError.new(code, message)
      end

      # Add an error for a specific attribute (structured with code)
      def add(attribute : String, code : Symbol, **options)
        @errors[attribute] ||= [] of ValidationError
        @errors[attribute] << ValidationError.new(code, **options)
      end

      # Add an error for a specific attribute (with explicit message and code)
      def add(attribute : String, code : Symbol, message : String, **options)
        @errors[attribute] ||= [] of ValidationError
        @errors[attribute] << ValidationError.new(code, message, **options)
      end

      # Get all error messages for an attribute (backward compatible - returns strings)
      def [](attribute : String) : Array(String)
        errors_for(attribute).map(&.message)
      end

      # Get all validation errors for an attribute (structured)
      def errors_for(attribute : String) : Array(ValidationError)
        @errors[attribute] ||= [] of ValidationError
      end

      # Check if there are any errors
      def empty? : Bool
        @errors.empty? || @errors.values.all?(&.empty?)
      end

      # Check if there are any errors (inverse of empty?)
      def any? : Bool
        !empty?
      end

      # Check if there are errors for a specific attribute
      def include?(attribute : String) : Bool
        @errors.has_key?(attribute) && !@errors[attribute].empty?
      end

      # Alias for include?
      def has_key?(attribute : String) : Bool
        include?(attribute)
      end

      # Get all error messages as a flat array (backward compatible)
      def full_messages : Array(String)
        messages = [] of String
        @errors.each do |attr, errs|
          errs.each do |err|
            messages << "#{attr} #{err.message}"
          end
        end
        messages
      end

      # Get error details for i18n/structured access
      #
      # Returns a hash where each attribute maps to an array of error details.
      # Each detail contains the error code and any options.
      #
      # ## Example
      #
      # ```
      # errors.add("name", :blank)
      # errors.add("password", :too_short, count: 8)
      #
      # errors.details
      # # => {
      # #   "name" => [{error: :blank}],
      # #   "password" => [{error: :too_short, count: 8}]
      # # }
      # ```
      def details : Hash(String, Array(Hash(Symbol, Symbol | String | Int32 | Int64 | Float64 | Bool | Nil)))
        result = Hash(String, Array(Hash(Symbol, Symbol | String | Int32 | Int64 | Float64 | Bool | Nil))).new
        @errors.each do |attr, errs|
          result[attr] = errs.map do |err|
            detail = Hash(Symbol, Symbol | String | Int32 | Int64 | Float64 | Bool | Nil).new
            detail[:error] = err.code
            err.options.each do |k, v|
              detail[k] = v
            end
            detail
          end
        end
        result
      end

      # Get all errors as a hash of attribute => messages (backward compatible)
      def to_h : Hash(String, Array(String))
        result = Hash(String, Array(String)).new
        @errors.each do |attr, errs|
          result[attr] = errs.map(&.message)
        end
        result
      end

      # Get all error messages as a hash (alias for to_h)
      def messages : Hash(String, Array(String))
        to_h
      end

      # Clear all errors
      def clear
        @errors.clear
      end

      # Get count of errors
      def count : Int32
        @errors.values.sum(&.size)
      end

      # Alias for count
      def size : Int32
        count
      end

      # Iterate over errors (yields full messages)
      def each(&block : String ->)
        full_messages.each do |msg|
          yield msg
        end
      end

      # Iterate over errors with attribute and message
      def each_with_attribute(&block : String, String ->)
        @errors.each do |attr, errs|
          errs.each do |err|
            yield attr, err.message
          end
        end
      end

      # Iterate over structured errors
      def each_error(&block : String, ValidationError ->)
        @errors.each do |attr, errs|
          errs.each do |err|
            yield attr, err
          end
        end
      end

      # Get all error codes for an attribute
      def codes_for(attribute : String) : Array(Symbol)
        errors_for(attribute).map(&.code)
      end

      # Check if a specific error code exists for an attribute
      def has_error?(attribute : String, code : Symbol) : Bool
        errors_for(attribute).any? { |e| e.code == code }
      end

      # Merge errors from another Errors object
      def merge!(other : Errors)
        other.each_error do |attr, err|
          @errors[attr] ||= [] of ValidationError
          @errors[attr] << err
        end
      end

      # Infer error code from a message string
      private def infer_code(message : String) : Symbol
        case message
        when /can't be blank/, /cannot be blank/
          :blank
        when /can't be empty/, /cannot be empty/
          :empty
        when /has already been taken/
          :taken
        when /is too short/
          :too_short
        when /is too long/
          :too_long
        when /is the wrong length/
          :wrong_length
        when /is not a number/
          :not_a_number
        when /must be an integer/
          :not_an_integer
        when /is not included in the list/
          :inclusion
        when /is reserved/
          :exclusion
        else
          :invalid
        end
      end
    end
  end
end

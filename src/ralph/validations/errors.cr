module Ralph
  module Validations
    # Stores validation errors for a model
    class Errors
      @errors : Hash(String, Array(String))

      def initialize
        @errors = Hash(String, Array(String)).new
      end

      # Add an error for a specific attribute
      def add(attribute : String, message : String)
        @errors[attribute] ||= [] of String
        @errors[attribute] << message
      end

      # Get all error messages for an attribute
      def [](attribute : String) : Array(String)
        @errors[attribute] ||= [] of String
      end

      # Check if there are any errors
      def empty? : Bool
        @errors.empty?
      end

      # Check if there are errors for a specific attribute
      def include?(attribute : String) : Bool
        @errors.has_key?(attribute) && !@errors[attribute].empty?
      end

      # Get all error messages as a flat array
      def full_messages : Array(String)
        messages = [] of String
        @errors.each do |attr, msgs|
          msgs.each do |msg|
            messages << "#{attr} #{msg}"
          end
        end
        messages
      end

      # Get all errors as a hash
      def to_h : Hash(String, Array(String))
        @errors.dup
      end

      # Clear all errors
      def clear
        @errors.clear
      end

      # Get count of errors
      def count : Int32
        @errors.values.sum(&.size)
      end

      # Iterate over errors
      def each(&block : String ->)
        @errors.each do |attr, msgs|
          msgs.each do |msg|
            yield "#{attr} #{msg}"
          end
        end
      end
    end
  end
end

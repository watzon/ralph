module Ralph
  module Cli
    module Generators
      class ScaffoldGenerator
        @name : String
        @fields : Array(String)
        @table_name : String
        @class_name : String

        def initialize(name : String, fields : Array(String))
          @name = name
          @fields = fields
          @class_name = name.camelcase
          @table_name = name.underscore + "s"
        end

        def run
          # Generate the model first
          model_gen = ModelGenerator.new(@name, @fields)
          model_gen.run

          # Generate additional scaffold files
          puts "\nScaffold generation complete!"
          puts "Generated files:"
          puts "  - Model: src/models/#{@name.underscore}.cr"
          puts "  - Migration: db/migrations/XXXX_create_#{@table_name}.cr"
          puts "\nNext steps:"
          puts "  1. Review the generated model file"
          puts "  2. Run: ralph db:migrate"
          puts "  3. Use your model in your application"
        end
      end
    end
  end
end

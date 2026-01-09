# Schema Puller Orchestrator
#
# Coordinates the db:pull command by:
# 1. Introspecting the database schema via the backend
# 2. Inferring associations from foreign keys
# 3. Generating Ralph model files

require "file_utils"

module Ralph
  module Cli
    # Orchestrates pulling models from database schema
    class SchemaPuller
      @db : Database::Backend
      @output_dir : String
      @tables : Array(String)?
      @skip_tables : Array(String)
      @overwrite : Bool
      @output : IO

      def initialize(
        @db : Database::Backend,
        @output_dir : String = "./src/models",
        @tables : Array(String)? = nil,
        @skip_tables : Array(String) = [] of String,
        @overwrite : Bool = false,
        @output : IO = STDOUT,
      )
      end

      # Preview what would be generated (dry-run)
      def preview
        schema = introspect_schema

        if schema.tables.empty?
          @output.puts "No tables found in database"
          return
        end

        @output.puts "Found #{schema.tables.size} table(s):"
        @output.puts ""

        schema.each_table do |table|
          class_name = classify(table.name)
          file_name = "#{singularize(table.name).underscore}.cr"

          @output.puts "  #{class_name} (#{table.name})"
          @output.puts "    File: #{@output_dir}/#{file_name}"
          @output.puts "    Columns: #{table.columns.size}"

          if table.foreign_keys.size > 0
            @output.puts "    Foreign Keys: #{table.foreign_keys.size}"
          end

          # Show what associations would be inferred
          inferrer = AssociationInferrer.new(schema)
          associations = inferrer.infer_for(table)

          if associations.size > 0
            @output.puts "    Associations:"
            associations.each do |assoc|
              @output.puts "      - #{assoc.type}: #{assoc.name}"
            end
          end

          @output.puts ""
        end
      end

      # Run the schema pull and generate model files
      def run
        schema = introspect_schema

        if schema.tables.empty?
          @output.puts "No tables found in database"
          return
        end

        @output.puts "Pulling #{schema.tables.size} table(s) from database..."
        @output.puts ""

        FileUtils.mkdir_p(@output_dir)

        generated_files = [] of String
        skipped_files = [] of String
        errors = [] of String

        schema.each_table do |table|
          begin
            result = generate_model(table, schema)

            if File.exists?(result[:path]) && !@overwrite
              skipped_files << result[:path]
              @output.puts "  Skipped: #{result[:path]} (already exists)"
            else
              File.write(result[:path], result[:content])
              generated_files << result[:path]
              @output.puts "  Created: #{result[:path]}"
            end
          rescue ex
            errors << "#{table.name}: #{ex.message}"
            @output.puts "  Error: #{table.name} - #{ex.message}"
          end
        end

        @output.puts ""
        @output.puts "Summary:"
        @output.puts "  Generated: #{generated_files.size} file(s)"
        @output.puts "  Skipped: #{skipped_files.size} file(s)" unless skipped_files.empty?
        @output.puts "  Errors: #{errors.size}" unless errors.empty?

        unless skipped_files.empty?
          @output.puts ""
          @output.puts "To regenerate skipped files, use --overwrite"
        end
      end

      private def introspect_schema : Schema::DatabaseSchema
        # Get full schema or filtered by table names
        if tables = @tables
          @db.introspect_tables(tables)
        else
          schema = @db.introspect_schema

          # Filter out skipped tables
          unless @skip_tables.empty?
            filtered_tables = schema.tables.reject { |name, _| @skip_tables.includes?(name) }
            schema = Schema::DatabaseSchema.new(filtered_tables)
          end

          schema
        end
      end

      private def generate_model(table : Schema::DatabaseTable, schema : Schema::DatabaseSchema) : NamedTuple(path: String, content: String, class_name: String)
        # Infer associations
        inferrer = AssociationInferrer.new(schema)
        associations = inferrer.infer_for(table)

        # Generate model
        generator = Generators::PulledModelGenerator.new(
          table: table,
          associations: associations,
          output_dir: @output_dir,
          dialect: @db.dialect
        )

        generator.generate
      end

      # Convert table name to class name
      private def classify(name : String) : String
        name.singularize.split('_').map(&.capitalize).join
      end
    end
  end
end

require "../spec_helper"
require "file_utils"

# Require the main Ralph library which includes CLI
require "../../src/ralph"

module Ralph
  describe "CLI" do
    describe "Commands" do
      describe "help" do
        it "displays help information" do
          runner = Cli::Runner.new

          # Capture output
          output = IO::Memory.new
          runner.run(["help"])

          # Help should be displayed (this is a basic smoke test)
          # A full test would capture stdout, but we're just ensuring it doesn't crash
        end
      end

      describe "version" do
        it "displays version information" do
          runner = Cli::Runner.new
          runner.run(["version"])

          # Version should be displayed without errors
        end
      end
    end

    describe "ModelGenerator" do
      before_all do
        # Clean up any test artifacts
        FileUtils.rm_rf("./tmp/models")
        FileUtils.rm_rf("./tmp/migrations")
      end

      after_all do
        # Clean up test artifacts
        FileUtils.rm_rf("./tmp/models")
        FileUtils.rm_rf("./tmp/migrations")
      end

      describe "generate" do
        it "can be instantiated with name and fields" do
          generator = Cli::Generators::ModelGenerator.new("User", ["name:string", "email:string"])

          generator.should_not be_nil
          generator.is_a?(Cli::Generators::ModelGenerator).should be_true
        end

        it "can be instantiated with no fields" do
          generator = Cli::Generators::ModelGenerator.new("Test", [] of String)

          generator.should_not be_nil
        end
      end
    end

    describe "ScaffoldGenerator" do
      it "can be instantiated with name and fields" do
        generator = Cli::Generators::ScaffoldGenerator.new("Post", ["title:string", "body:text"])

        generator.should_not be_nil
        generator.is_a?(Cli::Generators::ScaffoldGenerator).should be_true
      end
    end
  end

  describe "CLI Database Commands" do
    # These are integration-style tests that would require a real database
    # For now, we just test that the command structure is correct

    describe "db:seed" do
      it "handles missing seed file gracefully" do
        # This would test the actual db:seed command
        # For now, we skip it as it requires file system setup
      end
    end

    describe "db:reset" do
      it "combines drop, create, migrate, and seed" do
        # This would test the db:reset command
      end
    end

    describe "db:setup" do
      it "creates database and runs migrations" do
        # This would test the db:setup command
      end
    end
  end

end

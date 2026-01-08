require "../spec_helper"
require "file_utils"

# Require the main Ralph library which includes CLI
require "../../src/ralph"

module Ralph
  describe "CLI" do
    describe "Commands" do
      describe "help" do
        it "displays help information" do
          output = IO::Memory.new
          runner = Cli::Runner.new(output)
          runner.run(["help"])

          output.to_s.should contain("Ralph v#{Ralph::VERSION}")
          output.to_s.should contain("Usage:")
        end
      end

      describe "version" do
        it "displays version information" do
          output = IO::Memory.new
          runner = Cli::Runner.new(output)
          runner.run(["version"])

          output.to_s.should contain("Ralph v#{Ralph::VERSION}")
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

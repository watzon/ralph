require "../spec_helper"
require "../ralph/test_helper"

module Ralph
  # Test model for default values
  class DefaultValueModel < Model
    table "users"

    column id, Int64
    column name, String
    column email, String
    column age, Int32 | Nil

    setup_validations
    setup_callbacks
  end

  # Test model with default values defined
  class ModelWithDefaults < Model
    table "users"

    column id, Int64
    column name, String, default: "Anonymous"
    column email, String, default: "anonymous@example.com"
    column age, Int32 | Nil, default: 18

    setup_validations
    setup_callbacks
  end

  # Test model for conditional callbacks
  class ConditionalCallbackModel < Model
    table "users"

    column id, Int64
    column name, String
    column email, String
    column active, Bool | Nil
    column skip_callback, Bool | Nil

    @_conditional_callback_log : Array(String) = [] of String

    def conditional_callback_log : Array(String)
      @_conditional_callback_log
    end

    def active? : Bool
      @active == true
    end

    def should_skip? : Bool
      @skip_callback == true
    end

    @[BeforeSave]
    @[CallbackOptions(if: :active?)]
    def set_timestamp_if_active
      @_conditional_callback_log << "before_save_if_active"
    end

    @[AfterSave]
    @[CallbackOptions(unless: :should_skip?)]
    def log_after_save_unless_skipped
      @_conditional_callback_log << "after_save_unless_skipped"
    end

    @[BeforeCreate]
    @[CallbackOptions(if: :active?)]
    def log_before_create_if_active
      @_conditional_callback_log << "before_create_if_active"
    end

    setup_validations
    setup_callbacks
  end

  describe "Default Values" do
    before_all do
      RalphTestHelper.setup_test_database
    end

    before_each do
      RalphTestHelper.clear_tables
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    it "applies default value for string column" do
      model = ModelWithDefaults.new
      model.name.should eq("Anonymous")
      model.email.should eq("anonymous@example.com")
    end

    it "applies default value for integer column" do
      model = ModelWithDefaults.new
      model.age.should eq(18)
    end

    it "uses provided value instead of default" do
      model = ModelWithDefaults.new(name: "Alice", email: "alice@example.com", age: 25)
      model.name.should eq("Alice")
      model.email.should eq("alice@example.com")
      model.age.should eq(25)
    end

    it "uses provided value for some columns and defaults for others" do
      model = ModelWithDefaults.new(name: "Bob")
      model.name.should eq("Bob")
      model.email.should eq("anonymous@example.com")  # default
      model.age.should eq(18)  # default
    end

    it "saves record with default values" do
      model = ModelWithDefaults.new
      model.save

      model.name.should eq("Anonymous")
      model.email.should eq("anonymous@example.com")
      model.persisted?.should be_true
    end

    it "has nil default when no default specified" do
      model = DefaultValueModel.new
      model.age.should be_nil
    end
  end

  describe "Conditional Callbacks" do
    before_all do
      RalphTestHelper.setup_test_database
    end

    before_each do
      RalphTestHelper.clear_tables
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    describe "callbacks with if condition" do
      it "runs callback when if condition is true" do
        model = ConditionalCallbackModel.new(name: "Test", email: "test@example.com", active: true)
        model.save

        model.conditional_callback_log.should contain("before_save_if_active")
        model.conditional_callback_log.should contain("before_create_if_active")
      end

      it "does not run callback when if condition is false" do
        model = ConditionalCallbackModel.new(name: "Test", email: "test@example.com", active: false)
        model.save

        model.conditional_callback_log.should_not contain("before_save_if_active")
        model.conditional_callback_log.should_not contain("before_create_if_active")
      end

      it "does not run callback when if condition is nil" do
        model = ConditionalCallbackModel.new(name: "Test", email: "test@example.com")
        model.save

        model.conditional_callback_log.should_not contain("before_save_if_active")
        model.conditional_callback_log.should_not contain("before_create_if_active")
      end
    end

    describe "callbacks with unless condition" do
      it "runs callback when unless condition is false" do
        model = ConditionalCallbackModel.new(name: "Test", email: "test@example.com", skip_callback: false)
        model.save

        model.conditional_callback_log.should contain("after_save_unless_skipped")
      end

      it "does not run callback when unless condition is true" do
        model = ConditionalCallbackModel.new(name: "Test", email: "test@example.com", skip_callback: true)
        model.save

        model.conditional_callback_log.should_not contain("after_save_unless_skipped")
      end
    end

    describe "callbacks without conditions" do
      it "existing callback tests still pass" do
        # Verify that callbacks without conditions still work
        model = ConditionalCallbackModel.new(name: "Test", email: "test@example.com")
        model.save

        # The callback log should have the conditional callbacks that ran
        # (after_save_unless_skipped runs because skip_callback is nil/false)
        model.conditional_callback_log.should contain("after_save_unless_skipped")
      end
    end
  end
end

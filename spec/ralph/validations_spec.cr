require "../spec_helper"
require "../ralph/test_helper"

module Ralph
  # Test models with validations - defined outside describe block
  class BlockValidationModel < Model
    table "users"

    column id, Int64
    column name, String
    column email, String

    validate :name, "can't be blank" do
      !name.to_s.empty?
    end

    validate :email, "must contain @" do
      email.to_s.includes?("@")
    end
  end

  # Model with custom validation method
  class CustomValidationModel < Model
    table "users"

    column id, Int64
    column name, String
    column age, Int32 | Nil

    @[ValidationMethod]
    private def check_name_not_reserved
      if name == "admin"
        errors.add("name", "is reserved")
      end
    end
  end

  describe Validations do
    before_all do
      RalphTestHelper.setup_test_database
    end

    before_each do
      RalphTestHelper.clear_tables
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    describe "block-based validation" do
      it "adds error when validation fails" do
        model = BlockValidationModel.new(name: "", email: "invalid")
        model.valid?

        model.errors["name"].should eq(["can't be blank"])
        model.errors["email"].should eq(["must contain @"])
      end

      it "passes when validations succeed" do
        model = BlockValidationModel.new(name: "Alice", email: "alice@example.com")
        model.valid?.should be_true
        model.errors.empty?.should be_true
      end

      it "returns correct valid?/invalid? status" do
        model = BlockValidationModel.new
        model.valid?.should be_false
        model.invalid?.should be_true

        model.name = "Alice"
        model.email = "alice@example.com"
        model.valid?.should be_true
        model.invalid?.should be_false
      end
    end

    describe "custom validation method" do
      it "calls custom validation method" do
        model = CustomValidationModel.new(name: "admin")
        model.valid?

        model.errors["name"].should eq(["is reserved"])
      end

      it "passes when custom validation succeeds" do
        model = CustomValidationModel.new(name: "Alice")
        model.valid?.should be_true
        model.errors.empty?.should be_true
      end
    end

    describe "errors object" do
      it "returns errors for specific attribute" do
        model = BlockValidationModel.new(name: "")
        model.valid?

        model.errors["name"].should eq(["can't be blank"])
      end

      it "returns all error messages" do
        model = BlockValidationModel.new(name: "", email: "invalid")
        model.valid?

        messages = model.errors.full_messages
        messages.should contain("name can't be blank")
        messages.should contain("email must contain @")
      end

      it "clears errors between validations" do
        model = BlockValidationModel.new(name: "", email: "invalid")
        model.valid?
        model.errors.count.should be > 0

        model.name = "Alice"
        model.email = "alice@example.com"
        model.valid?
        model.errors.count.should eq(0)
      end

      it "checks if attribute has errors" do
        model = BlockValidationModel.new(name: "")
        model.valid?

        model.errors.include?("name").should be_true
        model.errors.include?("age").should be_false
      end

      it "reports empty? correctly" do
        model = BlockValidationModel.new
        model.valid?

        model.errors.empty?.should be_false

        model.name = "Alice"
        model.email = "alice@example.com"
        model.valid?

        model.errors.empty?.should be_true
      end
    end

    describe "structured errors (error codes)" do
      it "provides error codes via errors_for" do
        model = BlockValidationModel.new(name: "", email: "invalid")
        model.valid?

        name_errors = model.errors.errors_for("name")
        name_errors.size.should eq(1)
        # Custom message errors infer code from message
        name_errors[0].code.should eq(:blank)
      end

      it "returns error details for i18n" do
        model = BlockValidationModel.new(name: "", email: "invalid")
        model.valid?

        details = model.errors.details
        details.has_key?("name").should be_true
        details["name"][0][:error].should eq(:blank)
      end

      it "provides codes_for helper method" do
        model = BlockValidationModel.new(name: "", email: "invalid")
        model.valid?

        model.errors.codes_for("name").should eq([:blank])
      end

      it "has_error? checks for specific error code" do
        model = BlockValidationModel.new(name: "", email: "invalid")
        model.valid?

        model.errors.has_error?("name", :blank).should be_true
        model.errors.has_error?("name", :taken).should be_false
      end

      it "iterates over errors with each_error" do
        model = BlockValidationModel.new(name: "", email: "invalid")
        model.valid?

        error_pairs = [] of Tuple(String, Symbol)
        model.errors.each_error do |attr, err|
          error_pairs << {attr, err.code}
        end

        error_pairs.should contain({"name", :blank})
      end

      it "merges errors from another errors object" do
        errors1 = Validations::Errors.new
        errors1.add("name", :blank)

        errors2 = Validations::Errors.new
        errors2.add("email", :invalid)

        errors1.merge!(errors2)
        errors1.include?("name").should be_true
        errors1.include?("email").should be_true
      end

      it "supports messages hash for backward compatibility" do
        model = BlockValidationModel.new(name: "", email: "invalid")
        model.valid?

        messages = model.errors.messages
        messages["name"].should eq(["can't be blank"])
      end
    end
  end
end

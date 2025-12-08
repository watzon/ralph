require "../spec_helper"
require "../ralph/test_helper"

module Ralph
  # Define all test models at module level (Crystal doesn't allow nested classes in describe blocks)

  # Presence validation test models
  class PresenceTestModel < Model
    table "users"
    column id, Int64
    column name, String
    column email, String

    validates_presence_of :name
    validates_presence_of :email

    setup_validations
    setup_callbacks
  end

  class PresenceCustomMessageModel < Model
    table "users"
    column id, Int64
    column name, String

    validates_presence_of :name, message: "is required"

    setup_validations
    setup_callbacks
  end

  # Length validation test models
  class LengthTestModel < Model
    table "users"
    column id, Int64
    column name, String
    column email, String

    validates_length_of :name, min: 3, max: 50
    validates_length_of :email, minimum: 8

    setup_validations
    setup_callbacks
  end

  class LengthRangeModel < Model
    table "users"
    column id, Int64
    column name, String

    validates_length_of :name, range: 3..20

    setup_validations
    setup_callbacks
  end

  class LengthCustomMessageModel < Model
    table "users"
    column id, Int64
    column name, String

    validates_length_of :name, min: 5, message: "is too short"

    setup_validations
    setup_callbacks
  end

  # Format validation test models
  class FormatTestModel < Model
    table "users"
    column id, Int64
    column email, String
    column name, String

    validates_format_of :email, pattern: /@/
    validates_format_of :name, pattern: /^[a-zA-Z0-9_]+$/

    setup_validations
    setup_callbacks
  end

  class FormatCustomMessageModel < Model
    table "users"
    column id, Int64
    column email, String

    validates_format_of :email, pattern: /@/, message: "must contain @"

    setup_validations
    setup_callbacks
  end

  # Numericality validation test models
  class NumericalityTestModel < Model
    table "users"
    column id, Int64
    column age, Int32 | Nil

    validates_numericality_of :age

    setup_validations
    setup_callbacks
  end

  class NumericalityCustomMessageModel < Model
    table "users"
    column id, Int64
    column age, Int32 | Nil

    validates_numericality_of :age, message: "must be numeric"

    setup_validations
    setup_callbacks
  end

  # Inclusion validation test models
  class InclusionTestModel < Model
    table "users"
    column id, Int64
    column name, String
    column email, String

    validates_inclusion_of :name, allow: ["draft", "published", "archived"]
    validates_inclusion_of :email, allow: ["user", "admin"]

    setup_validations
    setup_callbacks
  end

  class InclusionCustomMessageModel < Model
    table "users"
    column id, Int64
    column name, String

    validates_inclusion_of :name, allow: ["active", "inactive"], message: "is not a valid status"

    setup_validations
    setup_callbacks
  end

  # Exclusion validation test models
  class ExclusionTestModel < Model
    table "users"
    column id, Int64
    column name, String
    column email, String

    validates_exclusion_of :name, forbid: ["admin", "root", "system"]
    validates_exclusion_of :email, forbid: ["blocked@example.com"]

    setup_validations
    setup_callbacks
  end

  class ExclusionCustomMessageModel < Model
    table "users"
    column id, Int64
    column name, String

    validates_exclusion_of :name, forbid: ["admin"], message: "is not allowed"

    setup_validations
    setup_callbacks
  end

  # Uniqueness validation test models
  class UniquenessTestModel < Model
    table "users"
    column id, Int64
    column email, String
    column name, String

    validates_uniqueness_of :email
    validates_uniqueness_of :name

    setup_validations
    setup_callbacks
  end

  class UniquenessCustomMessageModel < Model
    table "users"
    column id, Int64
    column email, String
    column name, String

    validates_uniqueness_of :email, message: "is already taken"

    setup_validations
    setup_callbacks
  end

  class UniquenessNilModel < Model
    table "users"
    column id, Int64
    column age, Int32 | Nil

    validates_uniqueness_of :age

    setup_validations
    setup_callbacks
  end

  # Validation callback test model
  class ValidationCallbackTestModel < Model
    table "users"

    column id, Int64
    column name, String
    column email, String

    @_validation_callback_log : Array(String) = [] of String

    def validation_callback_log : Array(String)
      @_validation_callback_log
    end

    @[BeforeValidation]
    def before_validation_callback
      @_validation_callback_log << "before_validation"
    end

    @[AfterValidation]
    def after_validation_callback
      @_validation_callback_log << "after_validation"
    end

    validates_presence_of :name

    setup_validations
    setup_callbacks
  end

  describe "Validation Helpers" do
    before_all do
      RalphTestHelper.setup_test_database
    end

    before_each do
      RalphTestHelper.clear_tables
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    describe "validates_presence_of" do
      it "adds error when attribute is nil" do
        model = PresenceTestModel.new(name: "", email: nil)
        model.valid?

        model.errors["name"].should eq(["can't be blank"])
        model.errors["email"].should eq(["can't be blank"])
      end

      it "adds error when string attribute is empty" do
        model = PresenceTestModel.new(name: "", email: "")
        model.valid?

        model.errors["name"].should eq(["can't be blank"])
        model.errors["email"].should eq(["can't be blank"])
      end

      it "passes when attribute has value" do
        model = PresenceTestModel.new(name: "Alice", email: "alice@example.com")
        model.valid?.should be_true
        model.errors.empty?.should be_true
      end

      it "allows custom message" do
        model = PresenceCustomMessageModel.new(name: "")
        model.valid?
        model.errors["name"].should eq(["is required"])
      end
    end

    describe "validates_length_of" do
      it "adds error when string is too short" do
        model = LengthTestModel.new(name: "AB", email: "longenough@example.com")
        model.valid?

        model.errors["name"][0].should contain("too short")
      end

      it "adds error when string is too long" do
        model = LengthTestModel.new(name: "A" * 51, email: "test@example.com")
        model.valid?

        model.errors["name"][0].should contain("too long")
      end

      it "passes when length is within range" do
        model = LengthTestModel.new(name: "Alice", email: "test@example.com")
        model.valid?.should be_true
      end

      it "works with minimum: alias" do
        model = LengthTestModel.new(name: "Bob", email: "short")
        model.valid?

        model.errors["email"][0].should contain("too short")
      end

      it "works with range using range:" do
        model = LengthRangeModel.new(name: "AB")
        model.valid?
        model.errors["name"][0].should contain("wrong length")

        model2 = LengthRangeModel.new(name: "A" * 25)
        model2.valid?
        model2.errors["name"][0].should contain("wrong length")

        model3 = LengthRangeModel.new(name: "validuser")
        model3.valid?.should be_true
      end

      it "allows custom message" do
        model = LengthCustomMessageModel.new(name: "ABC")
        model.valid?
        model.errors["name"].should eq(["is too short"])
      end
    end

    describe "validates_format_of" do
      it "adds error when value doesn't match pattern" do
        model = FormatTestModel.new(email: "notanemail", name: "valid_user")
        model.valid?

        model.errors["email"].should eq(["is invalid"])
      end

      it "passes when value matches pattern" do
        model = FormatTestModel.new(email: "test@example.com", name: "valid_user")
        model.valid?.should be_true
      end

      it "skips validation for nil values" do
        model = FormatTestModel.new(email: nil, name: nil)
        model.valid?.should be_true
      end

      it "allows custom message" do
        model = FormatCustomMessageModel.new(email: "invalid")
        model.valid?
        model.errors["email"].should eq(["must contain @"])
      end
    end

    describe "validates_numericality_of" do
      it "passes for numeric types" do
        model = NumericalityTestModel.new(age: 25)
        model.valid?.should be_true
      end

      it "adds error for non-numeric values (nil)" do
        model = NumericalityTestModel.new(age: nil)
        model.valid?

        model.errors["age"].should eq(["is not a number"])
      end

      it "allows custom message" do
        model = NumericalityCustomMessageModel.new(age: nil)
        model.valid?
        model.errors["age"].should eq(["must be numeric"])
      end
    end

    describe "validates_inclusion_of" do
      it "adds error when value is not in list" do
        model = InclusionTestModel.new(name: "deleted", email: "superadmin")
        model.valid?

        model.errors["name"].should eq(["is not included in the list"])
        model.errors["email"].should eq(["is not included in the list"])
      end

      it "passes when value is in list" do
        model = InclusionTestModel.new(name: "published", email: "admin")
        model.valid?.should be_true
      end

      it "allows custom message" do
        model = InclusionCustomMessageModel.new(name: "pending")
        model.valid?
        model.errors["name"].should eq(["is not a valid status"])
      end
    end

    describe "validates_exclusion_of" do
      it "adds error when value is in forbidden list" do
        model = ExclusionTestModel.new(name: "admin", email: "test@example.com")
        model.valid?

        model.errors["name"].should eq(["is reserved"])
      end

      it "passes when value is not in forbidden list" do
        model = ExclusionTestModel.new(name: "regularuser", email: "test@example.com")
        model.valid?.should be_true
      end

      it "allows custom message" do
        model = ExclusionCustomMessageModel.new(name: "admin")
        model.valid?
        model.errors["name"].should eq(["is not allowed"])
      end
    end

    describe "validates_uniqueness_of" do
      it "passes for new unique record" do
        model = UniquenessTestModel.new(email: "unique@example.com", name: "uniqueuser")
        model.valid?.should be_true
      end

      it "adds error when value already exists" do
        UniquenessTestModel.create(email: "taken@example.com", name: "takenuser")

        model = UniquenessTestModel.new(email: "taken@example.com", name: "takenuser")
        model.valid?

        model.errors["email"].should eq(["has already been taken"])
        model.errors["name"].should eq(["has already been taken"])
      end

      it "allows updating same record" do
        record = UniquenessTestModel.create(email: "test@example.com", name: "testuser")

        # Updating the same record should not fail uniqueness
        record.email = "test@example.com"
        record.valid?.should be_true
      end

      it "allows custom message" do
        UniquenessCustomMessageModel.create(email: "taken@example.com", name: "testuser")

        model = UniquenessCustomMessageModel.new(email: "taken@example.com", name: "another")
        model.valid?
        model.errors["email"].should eq(["is already taken"])
      end

      it "skips validation for nil values" do
        model = UniquenessNilModel.new(age: nil)
        model.valid?.should be_true
      end
    end
  end

  describe "Validation Callbacks" do
    before_all do
      RalphTestHelper.setup_test_database
    end

    before_each do
      RalphTestHelper.clear_tables
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    describe "before_validation and after_validation callbacks" do
      it "runs before_validation callback" do
        model = ValidationCallbackTestModel.new(name: "Alice", email: "alice@example.com")
        model.save

        model.validation_callback_log.should contain("before_validation")
      end

      it "runs after_validation callback" do
        model = ValidationCallbackTestModel.new(name: "Alice", email: "alice@example.com")
        model.save

        model.validation_callback_log.should contain("after_validation")
      end

      it "runs validation callbacks in correct order" do
        model = ValidationCallbackTestModel.new(name: "Alice", email: "alice@example.com")
        model.save

        log = model.validation_callback_log
        log.index("before_validation").not_nil!.should be < log.index("after_validation").not_nil!
      end

      it "does not save when validation fails" do
        model = ValidationCallbackTestModel.new(name: "", email: "test@example.com")
        result = model.save

        result.should be_false
        model.new_record?.should be_true
      end
    end
  end
end

# Unit tests for Schema Validation features
#
# Tests the new error types and validation functionality:
# - SchemaMismatchError
# - TypeMismatchError
# - Settings for strict_resultset_validation
# - Schema Validator

require "../../spec_helper"

describe Ralph::SchemaMismatchError do
  it "creates error with detailed message for missing columns" do
    error = Ralph::SchemaMismatchError.new(
      model_name: "Supply",
      table_name: "supplies",
      expected_columns: ["id", "name", "price"],
      actual_columns: ["id", "name", "price", "created_at", "updated_at"]
    )

    error.model_name.should eq("Supply")
    error.table_name.should eq("supplies")
    msg = error.message.not_nil!
    msg.should contain("Missing in model")
    msg.should contain("created_at")
    msg.should contain("updated_at")
  end

  it "creates error with detailed message for extra columns" do
    error = Ralph::SchemaMismatchError.new(
      model_name: "User",
      table_name: "users",
      expected_columns: ["id", "name", "deleted_column"],
      actual_columns: ["id", "name"]
    )

    msg = error.message.not_nil!
    msg.should contain("Extra in model")
    msg.should contain("deleted_column")
  end

  it "identifies first position mismatch" do
    error = Ralph::SchemaMismatchError.new(
      model_name: "Item",
      table_name: "items",
      expected_columns: ["id", "name", "description"],
      actual_columns: ["id", "description", "name"]
    )

    msg = error.message.not_nil!
    msg.should contain("First mismatch at index 1")
    msg.should contain("Expected: name")
    msg.should contain("Got: description")
  end

  it "provides helpful hints" do
    error = Ralph::SchemaMismatchError.new(
      model_name: "Product",
      table_name: "products",
      expected_columns: ["id"],
      actual_columns: ["id", "sku"]
    )

    error.message.not_nil!.should contain("ralph db:pull")
  end

  describe "#summary" do
    it "returns concise summary" do
      error = Ralph::SchemaMismatchError.new(
        model_name: "Supply",
        table_name: "supplies",
        expected_columns: ["a", "b"],
        actual_columns: ["a", "b", "c", "d"]
      )

      error.summary.should eq("Supply: expected 2 columns, got 4 (2 missing, 0 extra)")
    end
  end
end

describe Ralph::TypeMismatchError do
  it "creates error with column context" do
    error = Ralph::TypeMismatchError.new(
      model_name: "Supply",
      column_name: "stock_quantity",
      column_index: 6,
      expected_type: "Float64 | PG::Numeric | Nil",
      actual_type: "Float32"
    )

    error.model_name.should eq("Supply")
    error.column_name.should eq("stock_quantity")
    error.column_index.should eq(6)
    msg = error.message.not_nil!
    msg.should contain("Supply#stock_quantity")
    msg.should contain("Float64")
    msg.should contain("Float32")
  end

  it "provides type hints for Float32" do
    error = Ralph::TypeMismatchError.new(
      model_name: "Supply",
      column_name: "price",
      column_index: 3,
      expected_type: "Float64",
      actual_type: "Float32"
    )

    msg = error.message.not_nil!
    msg.should contain("real")
    msg.should contain("Float32")
  end

  it "warns about column name mismatch" do
    error = Ralph::TypeMismatchError.new(
      model_name: "Item",
      column_name: "price",
      column_index: 2,
      expected_type: "Float64",
      actual_type: "String",
      resultset_column_name: "name"
    )

    msg = error.message.not_nil!
    msg.should contain("WARNING")
    msg.should contain("Column name mismatch")
    msg.should contain("price")
    msg.should contain("name")
  end
end

describe Ralph::Settings do
  describe "schema validation settings" do
    it "has strict_resultset_validation enabled by default" do
      settings = Ralph::Settings.new
      settings.strict_resultset_validation.should be_true
    end

    it "has validate_schema_on_boot disabled by default" do
      settings = Ralph::Settings.new
      settings.validate_schema_on_boot.should be_false
    end

    it "allows configuring strict_resultset_validation" do
      settings = Ralph::Settings.new
      settings.strict_resultset_validation = false
      settings.strict_resultset_validation.should be_false
    end

    it "allows configuring validate_schema_on_boot" do
      settings = Ralph::Settings.new
      settings.validate_schema_on_boot = true
      settings.validate_schema_on_boot.should be_true
    end
  end
end

describe Ralph::Schema::Validator do
  describe "PG_TYPE_TO_CRYSTAL mappings" do
    it "knows Float32 maps to real/float4" do
      hints = Ralph::Schema::Validator::PG_TYPE_TO_CRYSTAL
      hints["real"]?.should_not be_nil
      hints["real"].not_nil!.should contain("Float32")
      hints["float4"]?.should_not be_nil
      hints["float4"].not_nil!.should contain("Float32")
    end

    it "knows Float64 maps to double precision/float8" do
      hints = Ralph::Schema::Validator::PG_TYPE_TO_CRYSTAL
      hints["double precision"]?.should_not be_nil
      hints["double precision"].not_nil!.should contain("Float64")
      hints["float8"]?.should_not be_nil
      hints["float8"].not_nil!.should contain("Float64")
    end

    it "knows numeric can be Float64 or PG::Numeric" do
      hints = Ralph::Schema::Validator::PG_TYPE_TO_CRYSTAL
      hints["numeric"]?.should_not be_nil
      numeric_types = hints["numeric"].not_nil!
      numeric_types.should contain("Float64")
      numeric_types.should contain("PG::Numeric")
    end

    it "knows Int64 maps to bigint/int8" do
      hints = Ralph::Schema::Validator::PG_TYPE_TO_CRYSTAL
      hints["bigint"]?.should_not be_nil
      hints["bigint"].not_nil!.should contain("Int64")
      hints["int8"]?.should_not be_nil
      hints["int8"].not_nil!.should contain("Int64")
    end

    it "knows UUID maps to uuid" do
      hints = Ralph::Schema::Validator::PG_TYPE_TO_CRYSTAL
      hints["uuid"]?.should_not be_nil
      hints["uuid"].not_nil!.should contain("UUID")
    end

    it "knows jsonb maps to JSON::Any" do
      hints = Ralph::Schema::Validator::PG_TYPE_TO_CRYSTAL
      hints["jsonb"]?.should_not be_nil
      hints["jsonb"].not_nil!.should contain("JSON::Any")
    end
  end
end

describe Ralph::Schema::ValidationResult do
  it "is valid when no errors" do
    result = Ralph::Schema::ValidationResult.new(
      model_name: "User",
      table_name: "users",
      errors: [] of String,
      warnings: ["Column 'name' is nullable in DB but not in model"]
    )

    result.valid?.should be_true
    result.warnings.size.should eq(1)
  end

  it "is invalid when has errors" do
    result = Ralph::Schema::ValidationResult.new(
      model_name: "User",
      table_name: "users",
      errors: ["Missing columns in model: created_at"],
      warnings: [] of String
    )

    result.valid?.should be_false
    result.errors.size.should eq(1)
  end

  describe "#to_s" do
    it "shows OK for valid result" do
      result = Ralph::Schema::ValidationResult.new(
        model_name: "User",
        table_name: "users"
      )

      result.to_s.should contain("User: OK")
    end

    it "shows INVALID for invalid result" do
      result = Ralph::Schema::ValidationResult.new(
        model_name: "User",
        table_name: "users",
        errors: ["Missing columns"]
      )

      result.to_s.should contain("User: INVALID")
      result.to_s.should contain("Missing columns")
    end
  end
end

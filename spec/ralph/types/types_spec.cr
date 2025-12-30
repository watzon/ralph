require "../../spec_helper"
require "uuid"

# Test enum defined at top level (Crystal requires enums to be defined at compile time)
enum TestStatus
  Active
  Inactive
  Pending
end

describe Ralph::Types do
  describe Ralph::Types::Registry do
    before_each do
      Ralph::Types::Registry.clear!
    end

    after_each do
      Ralph::Types::Registry.clear!
    end

    describe ".register" do
      it "registers a type globally" do
        type = Ralph::Types::PrimitiveType.new(:test)
        Ralph::Types::Registry.register(:test, type)

        Ralph::Types::Registry.registered?(:test).should be_true
      end
    end

    describe ".lookup" do
      it "returns registered type" do
        type = Ralph::Types::PrimitiveType.new(:test)
        Ralph::Types::Registry.register(:test, type)

        result = Ralph::Types::Registry.lookup(:test)
        result.should eq(type)
      end

      it "returns nil for unregistered type" do
        result = Ralph::Types::Registry.lookup(:nonexistent)
        result.should be_nil
      end
    end

    describe ".register_for_backend" do
      it "registers backend-specific types" do
        pg_type = Ralph::Types::PrimitiveType.new(:pg_test)
        sqlite_type = Ralph::Types::PrimitiveType.new(:sqlite_test)

        Ralph::Types::Registry.register_for_backend(:postgres, :test, pg_type)
        Ralph::Types::Registry.register_for_backend(:sqlite, :test, sqlite_type)

        Ralph::Types::Registry.lookup(:test, :postgres).should eq(pg_type)
        Ralph::Types::Registry.lookup(:test, :sqlite).should eq(sqlite_type)
      end

      it "backend-specific takes priority over global" do
        global_type = Ralph::Types::PrimitiveType.new(:global)
        pg_type = Ralph::Types::PrimitiveType.new(:pg)

        Ralph::Types::Registry.register(:test, global_type)
        Ralph::Types::Registry.register_for_backend(:postgres, :test, pg_type)

        Ralph::Types::Registry.lookup(:test, :postgres).should eq(pg_type)
        Ralph::Types::Registry.lookup(:test, :sqlite).should eq(global_type)
      end
    end

    describe ".all_types" do
      it "returns all registered type symbols" do
        Ralph::Types::Registry.register(:type1, Ralph::Types::PrimitiveType.new(:type1))
        Ralph::Types::Registry.register(:type2, Ralph::Types::PrimitiveType.new(:type2))

        types = Ralph::Types::Registry.all_types
        types.should contain(:type1)
        types.should contain(:type2)
      end
    end
  end

  describe Ralph::Types::JsonType do
    describe "#cast" do
      it "accepts JSON::Any directly" do
        type = Ralph::Types::JsonType.new
        input = JSON.parse(%({"key": "value"}))

        result = type.cast(input)
        result.should eq(input)
      end

      it "parses JSON string" do
        type = Ralph::Types::JsonType.new
        result = type.cast(%({"key": "value"}))

        result.should be_a(JSON::Any)
        result.as(JSON::Any)["key"].as_s.should eq("value")
      end

      it "handles invalid JSON string gracefully" do
        type = Ralph::Types::JsonType.new
        result = type.cast("not json")

        # Invalid JSON is wrapped as a string
        result.should be_a(JSON::Any)
      end
    end

    describe "#dump" do
      it "converts JSON::Any to JSON string" do
        type = Ralph::Types::JsonType.new
        input = JSON.parse(%({"key": "value"}))

        result = type.dump(input)
        result.should eq(%({"key":"value"}))
      end
    end

    describe "#load" do
      it "parses JSON string from database" do
        type = Ralph::Types::JsonType.new
        result = type.load(%({"key": "value"}))

        result.should be_a(JSON::Any)
        result.as(JSON::Any)["key"].as_s.should eq("value")
      end

      it "handles nil gracefully" do
        type = Ralph::Types::JsonType.new
        result = type.load(nil)

        result.should be_nil
      end
    end

    describe "#sql_type" do
      it "returns JSONB for postgres with jsonb mode" do
        type = Ralph::Types::JsonType.new(Ralph::Types::JsonMode::Jsonb)
        type.sql_type(:postgres).should eq("JSONB")
      end

      it "returns JSON for postgres with json mode" do
        type = Ralph::Types::JsonType.new(Ralph::Types::JsonMode::Json)
        type.sql_type(:postgres).should eq("JSON")
      end

      it "returns TEXT for sqlite" do
        type = Ralph::Types::JsonType.new
        type.sql_type(:sqlite).should eq("TEXT")
      end
    end
  end

  describe Ralph::Types::UuidType do
    describe "#cast" do
      it "accepts UUID directly" do
        type = Ralph::Types::UuidType.new
        uuid = UUID.random

        result = type.cast(uuid)
        result.should eq(uuid)
      end

      it "parses valid UUID string" do
        type = Ralph::Types::UuidType.new
        uuid_str = "550e8400-e29b-41d4-a716-446655440000"

        result = type.cast(uuid_str)
        result.should be_a(UUID)
        result.as(UUID).to_s.should eq(uuid_str)
      end

      it "returns nil for invalid UUID string" do
        type = Ralph::Types::UuidType.new
        result = type.cast("not-a-uuid")

        result.should be_nil
      end
    end

    describe "#dump" do
      it "converts UUID to string" do
        type = Ralph::Types::UuidType.new
        uuid = UUID.new("550e8400-e29b-41d4-a716-446655440000")

        result = type.dump(uuid)
        result.should eq("550e8400-e29b-41d4-a716-446655440000")
      end
    end

    describe "#load" do
      it "parses UUID string from database" do
        type = Ralph::Types::UuidType.new
        result = type.load("550e8400-e29b-41d4-a716-446655440000")

        result.should be_a(UUID)
      end

      it "handles nil gracefully" do
        type = Ralph::Types::UuidType.new
        result = type.load(nil)

        result.should be_nil
      end
    end

    describe "#sql_type" do
      it "returns UUID for postgres" do
        type = Ralph::Types::UuidType.new
        type.sql_type(:postgres).should eq("UUID")
      end

      it "returns CHAR(36) for sqlite" do
        type = Ralph::Types::UuidType.new
        type.sql_type(:sqlite).should eq("CHAR(36)")
      end
    end
  end

  describe Ralph::Types::ArrayType do
    describe "String array" do
      it "casts JSON array to Crystal array" do
        type = Ralph::Types::ArrayType(String).new
        input = JSON.parse(%(["a", "b", "c"]))

        result = type.cast(input)
        result.should eq(["a", "b", "c"])
      end

      it "dumps array to JSON string" do
        type = Ralph::Types::ArrayType(String).new
        result = type.dump(["a", "b", "c"])

        result.should eq(%(["a","b","c"]))
      end

      it "loads from JSON string" do
        type = Ralph::Types::ArrayType(String).new
        result = type.load(%(["a","b","c"]))

        result.should eq(["a", "b", "c"])
      end

      it "loads from PostgreSQL array format" do
        type = Ralph::Types::ArrayType(String).new
        result = type.load("{a,b,c}")

        result.should eq(["a", "b", "c"])
      end
    end

    describe "Int32 array" do
      it "casts JSON array to Crystal array" do
        type = Ralph::Types::ArrayType(Int32).new
        input = JSON.parse(%([1, 2, 3]))

        result = type.cast(input)
        result.should eq([1, 2, 3])
      end

      it "loads from PostgreSQL array format" do
        type = Ralph::Types::ArrayType(Int32).new
        result = type.load("{1,2,3}")

        result.should eq([1, 2, 3])
      end
    end

    describe "#sql_type" do
      it "returns TEXT[] for postgres string array" do
        type = Ralph::Types::ArrayType(String).new
        type.sql_type(:postgres).should eq("TEXT[]")
      end

      it "returns INTEGER[] for postgres int32 array" do
        type = Ralph::Types::ArrayType(Int32).new
        type.sql_type(:postgres).should eq("INTEGER[]")
      end

      it "returns TEXT for sqlite" do
        type = Ralph::Types::ArrayType(String).new
        type.sql_type(:sqlite).should eq("TEXT")
      end
    end
  end

  describe Ralph::Types::EnumType do
    describe "#cast" do
      it "casts from enum value to serialized form" do
        type = Ralph::Types::EnumType(TestStatus).new
        result = type.cast(TestStatus::Active)

        # Returns string representation for string storage
        result.should eq("Active")
      end

      it "casts from string" do
        type = Ralph::Types::EnumType(TestStatus).new
        result = type.cast("Active")

        result.should eq("Active")
      end

      it "casts from integer" do
        type = Ralph::Types::EnumType(TestStatus).new(:integer)
        result = type.cast(1)

        # Returns integer for integer storage
        result.should eq(1)
      end

      it "returns nil for invalid value" do
        type = Ralph::Types::EnumType(TestStatus).new
        result = type.cast("InvalidStatus")

        result.should be_nil
      end
    end

    describe "#dump" do
      it "dumps as string by default" do
        type = Ralph::Types::EnumType(TestStatus).new
        result = type.dump(TestStatus::Active)

        result.should eq("Active")
      end

      it "dumps as integer when storage is :integer" do
        type = Ralph::Types::EnumType(TestStatus).new(:integer)
        result = type.dump(TestStatus::Inactive)

        result.should eq(1)
      end
    end

    describe "#load" do
      it "passes through string value" do
        type = Ralph::Types::EnumType(TestStatus).new
        result = type.load("Pending")

        # Returns the DB value as-is for model layer to parse
        result.should eq("Pending")
      end

      it "passes through integer value" do
        type = Ralph::Types::EnumType(TestStatus).new(:integer)
        result = type.load(2)

        result.should eq(2)
      end
    end

    describe "#check_constraint" do
      it "generates CHECK for string storage" do
        type = Ralph::Types::EnumType(TestStatus).new
        result = type.check_constraint("status")

        result.should_not be_nil
        result.not_nil!.should contain("IN")
        result.not_nil!.should contain("'Active'")
        result.not_nil!.should contain("'Inactive'")
        result.not_nil!.should contain("'Pending'")
      end

      it "generates CHECK for integer storage" do
        type = Ralph::Types::EnumType(TestStatus).new(:integer)
        result = type.check_constraint("status")

        result.should_not be_nil
        result.not_nil!.should contain(">=")
        result.not_nil!.should contain("<=")
      end
    end
  end

  describe Ralph::Types::PrimitiveType do
    it "passes through values without conversion" do
      type = Ralph::Types::PrimitiveType.new(:string)

      type.cast("hello").should eq("hello")
      type.dump("hello").should eq("hello")
      type.load("hello").should eq("hello")
    end

    it "does not require converter" do
      type = Ralph::Types::PrimitiveType.new(:string)
      type.requires_converter?.should be_false
    end
  end
end

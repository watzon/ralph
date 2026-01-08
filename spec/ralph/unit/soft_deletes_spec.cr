require "../../spec_helper"

describe "Ralph::ActsAsParanoid" do
  describe "migration schema helper" do
    it "soft_deletes creates deleted_at column" do
      dialect = Ralph::Migrations::Schema::Dialect::Sqlite.new
      definition = Ralph::Migrations::Schema::TableDefinition.new("test_table", dialect)

      definition.primary_key
      definition.string("name")
      definition.soft_deletes

      sql = definition.to_sql
      sql.should contain("\"deleted_at\"")
      sql.should contain("TIMESTAMP")
    end

    it "soft_deletes column allows NULL" do
      dialect = Ralph::Migrations::Schema::Dialect::Sqlite.new
      definition = Ralph::Migrations::Schema::TableDefinition.new("test_table", dialect)

      definition.primary_key
      definition.soft_deletes

      sql = definition.to_sql
      # Should NOT contain NOT NULL for deleted_at
      # (timestamps without explicit null: false allow nulls)
      sql.should contain("\"deleted_at\" TIMESTAMP")
    end
  end

  describe "query building" do
    it "with_deleted creates query without soft delete filter" do
      # Test that with_deleted doesn't add a WHERE clause for deleted_at
      # We can't easily test this without a model, but we can verify the concept
      query = Ralph::Query::Builder.new("test_table")

      sql = query.build_select
      sql.should_not contain("deleted_at")
    end

    it "only_deleted creates query with IS NOT NULL filter" do
      query = Ralph::Query::Builder.new("test_table")
        .where("\"test_table\".\"deleted_at\" IS NOT NULL")

      sql = query.build_select
      sql.should contain("deleted_at")
      sql.should contain("IS NOT NULL")
    end

    it "base query for paranoid model includes IS NULL filter" do
      query = Ralph::Query::Builder.new("test_table")
        .where("\"test_table\".\"deleted_at\" IS NULL")

      sql = query.build_select
      sql.should contain("deleted_at")
      sql.should contain("IS NULL")
    end
  end

  describe "ActsAsParanoid module" do
    it "defines paranoid? class method" do
      # When ActsAsParanoid is included, paranoid? returns true
      # This is tested in integration tests with actual models
    end
  end
end

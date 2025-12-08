require "../../spec_helper"

# Unit tests for Migrations::Schema classes
describe Ralph::Migrations::Schema::TableDefinition do
  it "creates TableDefinition" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("test_table")
    definition.string("name")
    definition.integer("age")
    definition.timestamps

    sql = definition.to_sql
    sql.should contain("CREATE TABLE IF NOT EXISTS")
    sql.should contain("\"test_table\"")
    sql.should contain("\"name\"")
    sql.should contain("\"age\"")
    sql.should contain("\"created_at\"")
    sql.should contain("\"updated_at\"")
  end

  it "creates TableDefinition with primary key" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("posts")
    definition.primary_key
    definition.string("title")

    sql = definition.to_sql
    sql.should contain("CREATE TABLE IF NOT EXISTS")
  end

  it "creates TableDefinition with custom primary key" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("posts")
    definition.primary_key(:post_id)
    definition.string("title")

    sql = definition.to_sql
    sql.should contain("\"posts\"")
  end

  it "creates TableDefinition with all column types" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("items")
    definition.primary_key
    definition.string("name", size: 100)
    definition.text("description")
    definition.integer("quantity")
    definition.bigint("count")
    definition.float("price")
    definition.boolean("active")
    definition.date("published_on")
    definition.timestamp("created_at")

    sql = definition.to_sql
    sql.should contain("VARCHAR(100)")
    sql.should contain("TEXT")
    sql.should contain("INTEGER")
    sql.should contain("BIGINT")
    sql.should contain("REAL")
    sql.should contain("BOOLEAN")
    sql.should contain("DATE")
    sql.should contain("TIMESTAMP")
  end

  it "creates TableDefinition with indexes" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("users")
    definition.primary_key
    definition.string("email")
    definition.index("email", unique: true)

    indexes = definition.indexes
    indexes.size.should eq(1)
    indexes[0].unique.should be_true
  end

  it "TableDefinition includes reference column" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("posts")
    definition.primary_key
    definition.string("title")
    definition.reference("user")

    sql = definition.to_sql
    sql.should contain("user_id")
  end

  it "TableDefinition reference creates index" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("posts")
    definition.primary_key
    definition.reference("user")

    definition.indexes.size.should eq(1)
    definition.indexes[0].column.should eq("user_id")
  end
end

describe Ralph::Migrations::Schema::ColumnDefinition do
  it "creates ColumnDefinition with SQL" do
    column = Ralph::Migrations::Schema::ColumnDefinition.new("title", :string, size: 100)
    sql = column.to_sql

    sql.should contain("\"title\"")
    sql.should contain("VARCHAR(100)")
  end

  it "creates ColumnDefinition with NOT NULL" do
    column = Ralph::Migrations::Schema::ColumnDefinition.new("email", :string, size: 255, null: false)
    sql = column.to_sql

    sql.should contain("NOT NULL")
  end

  it "creates ColumnDefinition with default value" do
    column = Ralph::Migrations::Schema::ColumnDefinition.new("status", :string, size: 50, default: "pending")
    sql = column.to_sql

    sql.should contain("DEFAULT 'pending'")
  end

  it "creates ColumnDefinition with integer default" do
    column = Ralph::Migrations::Schema::ColumnDefinition.new("views", :integer, default: 0)
    sql = column.to_sql

    sql.should contain("DEFAULT 0")
  end
end

describe Ralph::Migrations::Schema::IndexDefinition do
  it "creates IndexDefinition" do
    index = Ralph::Migrations::Schema::IndexDefinition.new("users", "email", "index_users_on_email", false)
    sql = index.to_sql

    sql.should eq("CREATE INDEX IF NOT EXISTS \"index_users_on_email\" ON \"users\" (\"email\")")
  end

  it "creates unique IndexDefinition" do
    index = Ralph::Migrations::Schema::IndexDefinition.new("users", "email", "unique_email", true)
    sql = index.to_sql

    sql.should eq("CREATE UNIQUE INDEX IF NOT EXISTS \"unique_email\" ON \"users\" (\"email\")")
  end
end

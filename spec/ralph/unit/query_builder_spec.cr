require "../../spec_helper"

# Unit tests for Query::Builder
describe Ralph::Query::Builder do
  it "builds SELECT query" do
    builder = Ralph::Query::Builder.new("users")
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"users\"")
  end

  it "builds SELECT with specific columns" do
    builder = Ralph::Query::Builder.new("users")
    builder.select("id", "name")
    sql = builder.build_select

    sql.should eq("SELECT \"id\", \"name\" FROM \"users\"")
  end

  it "builds SELECT with WHERE clause" do
    builder = Ralph::Query::Builder.new("users")
    builder.where("name = ?", "Alice")
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"users\" WHERE name = $1")
  end

  it "builds SELECT with multiple WHERE clauses" do
    builder = Ralph::Query::Builder.new("users")
    builder.where("age > ?", 18)
    builder.where("name = ?", "Bob")
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"users\" WHERE age > $1 AND name = $2")
  end

  it "builds SELECT with ORDER BY" do
    builder = Ralph::Query::Builder.new("users")
    builder.order("name", :asc)
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"users\" ORDER BY \"name\" ASC")
  end

  it "builds SELECT with ORDER BY DESC" do
    builder = Ralph::Query::Builder.new("users")
    builder.order("created_at", :desc)
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"users\" ORDER BY \"created_at\" DESC")
  end

  it "builds SELECT with multiple ORDER BY clauses" do
    builder = Ralph::Query::Builder.new("users")
    builder.order("name", :asc)
    builder.order("created_at", :desc)
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"users\" ORDER BY \"name\" ASC, \"created_at\" DESC")
  end

  it "builds SELECT with LIMIT and OFFSET" do
    builder = Ralph::Query::Builder.new("users")
    builder.limit(10)
    builder.offset(5)
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"users\" LIMIT 10 OFFSET 5")
  end

  it "builds SELECT with JOIN" do
    builder = Ralph::Query::Builder.new("posts")
    builder.join("users", "posts.user_id = users.id")
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"posts\" INNER JOIN \"users\" ON posts.user_id = users.id")
  end

  it "builds SELECT with LEFT JOIN" do
    builder = Ralph::Query::Builder.new("posts")
    builder.join("users", "posts.user_id = users.id", :left)
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"posts\" LEFT JOIN \"users\" ON posts.user_id = users.id")
  end

  it "builds INSERT query" do
    builder = Ralph::Query::Builder.new("users")
    data = {"name" => "Alice", "email" => "alice@example.com"} of String => DB::Any
    sql, args = builder.build_insert(data)

    sql.should eq("INSERT INTO \"users\" (\"name\", \"email\") VALUES ($1, $2)")
    args.should eq(["Alice", "alice@example.com"])
  end

  it "builds UPDATE query" do
    builder = Ralph::Query::Builder.new("users")
    builder.where("id = ?", 1)
    data = {"name" => "Bob"} of String => DB::Any
    sql, args = builder.build_update(data)

    sql.should contain("UPDATE \"users\" SET")
    sql.should contain("\"name\" = $1")
    sql.should contain("WHERE id = $2")
  end

  it "builds UPDATE with multiple columns" do
    builder = Ralph::Query::Builder.new("users")
    builder.where("id = ?", 1)
    data = {"name" => "Bob", "age" => 25} of String => DB::Any
    sql, args = builder.build_update(data)

    sql.should contain("\"name\" = $1")
    sql.should contain("\"age\" = $2")
  end

  it "builds DELETE query" do
    builder = Ralph::Query::Builder.new("users")
    builder.where("id = ?", 1)
    sql, args = builder.build_delete

    sql.should eq("DELETE FROM \"users\" WHERE id = $1")
  end

  it "builds DELETE with multiple WHERE clauses" do
    builder = Ralph::Query::Builder.new("users")
    builder.where("age < ?", 18)
    builder.where("name = ?", "Test")
    sql, args = builder.build_delete

    sql.should eq("DELETE FROM \"users\" WHERE age < $1 AND name = $2")
  end

  it "builds COUNT query" do
    builder = Ralph::Query::Builder.new("users")
    sql = builder.build_count

    sql.should eq("SELECT COUNT(\"*\") FROM \"users\"")
  end

  it "builds COUNT with WHERE clause" do
    builder = Ralph::Query::Builder.new("users")
    builder.where("age > ?", 18)
    sql = builder.build_count

    sql.should eq("SELECT COUNT(\"*\") FROM \"users\" WHERE age > $1")
  end

  it "builds COUNT on specific column" do
    builder = Ralph::Query::Builder.new("users")
    sql = builder.build_count("id")

    sql.should eq("SELECT COUNT(\"id\") FROM \"users\"")
  end

  it "resets query state" do
    builder = Ralph::Query::Builder.new("users")
    builder.where("age > ?", 18)
    builder.limit(10)

    builder.reset
    builder.limit(5)
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"users\" LIMIT 5")
  end

  it "checks if query has conditions" do
    builder = Ralph::Query::Builder.new("users")
    builder.has_conditions?.should be_false

    builder.where("age > ?", 18)
    builder.has_conditions?.should be_true
  end
end

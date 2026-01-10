require "../../spec_helper"

# Unit tests for query clause classes
describe Ralph::Query::WhereClause do
  it "converts empty args to SQL" do
    clause = Ralph::Query::WhereClause.new("active = 1")
    clause.to_sql.should eq("active = 1")
  end

  it "converts args with placeholders" do
    args = [18] of Ralph::Query::DBValue
    clause = Ralph::Query::WhereClause.new("age > ?", args)
    clause.to_sql.should eq("age > $1")
  end

  it "converts multiple placeholders" do
    args = [18, 65] of Ralph::Query::DBValue
    clause = Ralph::Query::WhereClause.new("age BETWEEN ? AND ?", args)
    clause.to_sql.should eq("age BETWEEN $1 AND $2")
  end

  it "stores arguments" do
    args = ["Alice"] of Ralph::Query::DBValue
    clause = Ralph::Query::WhereClause.new("name = ?", args)
    clause.args.should eq(["Alice"])
  end
end

describe Ralph::Query::OrderClause do
  it "generates ASC SQL" do
    clause = Ralph::Query::OrderClause.new("name", :asc)
    clause.to_sql.should eq("\"name\" ASC")
  end

  it "generates DESC SQL" do
    clause = Ralph::Query::OrderClause.new("created_at", :desc)
    clause.to_sql.should eq("\"created_at\" DESC")
  end
end

describe Ralph::Query::JoinClause do
  it "generates INNER JOIN SQL" do
    clause = Ralph::Query::JoinClause.new("posts", "posts.user_id = users.id", :inner)
    clause.to_sql.should eq("INNER JOIN \"posts\" ON posts.user_id = users.id")
  end

  it "generates LEFT JOIN SQL" do
    clause = Ralph::Query::JoinClause.new("posts", "posts.user_id = users.id", :left)
    clause.to_sql.should eq("LEFT JOIN \"posts\" ON posts.user_id = users.id")
  end

  it "generates RIGHT JOIN SQL" do
    clause = Ralph::Query::JoinClause.new("posts", "posts.user_id = users.id", :right)
    clause.to_sql.should eq("RIGHT JOIN \"posts\" ON posts.user_id = users.id")
  end
end

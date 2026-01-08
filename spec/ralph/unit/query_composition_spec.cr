require "../../spec_helper"

# Unit tests for query composition features in Query::Builder
describe Ralph::Query::Builder do
  describe "OR query merging" do
    it "combines two queries with OR" do
      query1 = Ralph::Query::Builder.new("users")
        .where("age > ?", 18)

      query2 = Ralph::Query::Builder.new("users")
        .where("role = ?", "admin")

      combined = query1.or(query2)
      sql = combined.build_select

      sql.should eq("SELECT * FROM \"users\" WHERE (age > $1 OR role = $2)")

      args = combined.all_args
      args.should eq([18, "admin"])
    end

    it "combines queries with multiple WHERE clauses using OR" do
      query1 = Ralph::Query::Builder.new("users")
        .where("age > ?", 18)
        .where("active = ?", true)

      query2 = Ralph::Query::Builder.new("users")
        .where("role = ?", "admin")

      combined = query1.or(query2)
      sql = combined.build_select

      sql.should eq("SELECT * FROM \"users\" WHERE ((age > $1 AND active = $2) OR role = $3)")

      args = combined.all_args
      args.should eq([18, true, "admin"])
    end

    it "combines queries with multiple WHERE clauses on both sides using OR" do
      query1 = Ralph::Query::Builder.new("users")
        .where("age > ?", 18)
        .where("active = ?", true)

      query2 = Ralph::Query::Builder.new("users")
        .where("role = ?", "admin")
        .where("department = ?", "engineering")

      combined = query1.or(query2)
      sql = combined.build_select

      sql.should eq("SELECT * FROM \"users\" WHERE ((age > $1 AND active = $2) OR (role = $3 AND department = $4))")

      args = combined.all_args
      args.should eq([18, true, "admin", "engineering"])
    end

    it "handles OR when first query has no WHERE clauses" do
      query1 = Ralph::Query::Builder.new("users")

      query2 = Ralph::Query::Builder.new("users")
        .where("role = ?", "admin")

      combined = query1.or(query2)
      sql = combined.build_select

      sql.should eq("SELECT * FROM \"users\" WHERE role = $1")
    end

    it "handles OR when second query has no WHERE clauses" do
      query1 = Ralph::Query::Builder.new("users")
        .where("age > ?", 18)

      query2 = Ralph::Query::Builder.new("users")

      combined = query1.or(query2)
      sql = combined.build_select

      # Original WHERE is preserved
      sql.should eq("SELECT * FROM \"users\" WHERE age > $1")
    end

    it "chains OR with additional WHERE clauses" do
      query1 = Ralph::Query::Builder.new("users")
        .where("age > ?", 18)

      query2 = Ralph::Query::Builder.new("users")
        .where("role = ?", "admin")

      combined = query1.or(query2).where("active = ?", true)
      sql = combined.build_select

      sql.should eq("SELECT * FROM \"users\" WHERE (age > $1 OR role = $2) AND active = $3")

      args = combined.all_args
      args.should eq([18, "admin", true])
    end
  end

  describe "AND query merging (explicit grouping)" do
    it "combines two queries with AND" do
      query1 = Ralph::Query::Builder.new("users")
        .where("age > ?", 18)

      query2 = Ralph::Query::Builder.new("users")
        .where("role = ?", "admin")

      combined = query1.and(query2)
      sql = combined.build_select

      sql.should eq("SELECT * FROM \"users\" WHERE (age > $1 AND role = $2)")

      args = combined.all_args
      args.should eq([18, "admin"])
    end

    it "combines queries with multiple WHERE clauses using AND" do
      query1 = Ralph::Query::Builder.new("users")
        .where("age > ?", 18)

      query2 = Ralph::Query::Builder.new("users")
        .where("role = ?", "admin")
        .where("department = ?", "engineering")

      combined = query1.and(query2)
      sql = combined.build_select

      sql.should eq("SELECT * FROM \"users\" WHERE (age > $1 AND (role = $2 AND department = $3))")

      args = combined.all_args
      args.should eq([18, "admin", "engineering"])
    end

    it "handles AND when first query has no WHERE clauses" do
      query1 = Ralph::Query::Builder.new("users")

      query2 = Ralph::Query::Builder.new("users")
        .where("role = ?", "admin")

      combined = query1.and(query2)
      sql = combined.build_select

      sql.should eq("SELECT * FROM \"users\" WHERE role = $1")
    end

    it "chains AND with additional WHERE clauses" do
      query1 = Ralph::Query::Builder.new("users")
        .where("age > ?", 18)

      query2 = Ralph::Query::Builder.new("users")
        .where("role = ?", "admin")

      combined = query1.and(query2).where("active = ?", true)
      sql = combined.build_select

      sql.should eq("SELECT * FROM \"users\" WHERE (age > $1 AND role = $2) AND active = $3")

      args = combined.all_args
      args.should eq([18, "admin", true])
    end
  end

  describe "complex OR/AND combinations" do
    it "supports nested OR and AND operations" do
      # (A OR B) AND C
      query_a = Ralph::Query::Builder.new("users")
        .where("role = ?", "admin")

      query_b = Ralph::Query::Builder.new("users")
        .where("role = ?", "moderator")

      query_c = Ralph::Query::Builder.new("users")
        .where("active = ?", true)

      combined = query_a.or(query_b).and(query_c)
      sql = combined.build_select

      # The OR creates (role = $1 OR role = $2), then AND adds the active condition
      sql.should contain("OR")
      sql.should contain("AND")

      args = combined.all_args
      args.should eq(["admin", "moderator", true])
    end

    it "preserves ORDER BY, LIMIT, OFFSET through OR operations" do
      query1 = Ralph::Query::Builder.new("users")
        .where("age > ?", 18)
        .order("name", :asc)
        .limit(10)

      query2 = Ralph::Query::Builder.new("users")
        .where("role = ?", "admin")

      combined = query1.or(query2)
      sql = combined.build_select

      sql.should contain("ORDER BY")
      sql.should contain("LIMIT 10")
    end
  end

  describe "query merging" do
    it "merges WHERE clauses from another query" do
      base = Ralph::Query::Builder.new("users")
        .where("active = ?", true)

      additional = Ralph::Query::Builder.new("users")
        .where("age > ?", 18)

      merged = base.merge(additional)
      sql = merged.build_select

      sql.should eq("SELECT * FROM \"users\" WHERE active = $1 AND age > $2")
    end

    it "merges ORDER BY clauses" do
      base = Ralph::Query::Builder.new("users")
        .order("name", :asc)

      additional = Ralph::Query::Builder.new("users")
        .order("created_at", :desc)

      merged = base.merge(additional)
      sql = merged.build_select

      sql.should contain("ORDER BY \"name\" ASC, \"created_at\" DESC")
    end

    it "merges SELECT columns" do
      base = Ralph::Query::Builder.new("users")
        .select("id", "name")

      additional = Ralph::Query::Builder.new("users")
        .select("email")

      merged = base.merge(additional)
      sql = merged.build_select

      sql.should contain("\"id\"")
      sql.should contain("\"name\"")
      sql.should contain("\"email\"")
    end

    it "merges GROUP BY clauses" do
      base = Ralph::Query::Builder.new("users")
        .group("department")

      additional = Ralph::Query::Builder.new("users")
        .group("role")

      merged = base.merge(additional)
      sql = merged.build_select

      sql.should contain("GROUP BY \"department\", \"role\"")
    end

    it "merges HAVING clauses" do
      base = Ralph::Query::Builder.new("users")
        .group("department")
        .having("COUNT(*) > ?", 5)

      additional = Ralph::Query::Builder.new("users")
        .having("SUM(salary) > ?", 100000)

      merged = base.merge(additional)
      sql = merged.build_select

      sql.should contain("HAVING COUNT(*) > $1 AND SUM(salary) > $2")
    end

    it "preserves LIMIT from base query when merging" do
      base = Ralph::Query::Builder.new("users")
        .limit(10)

      additional = Ralph::Query::Builder.new("users")
        .limit(20)

      merged = base.merge(additional)
      sql = merged.build_select

      sql.should contain("LIMIT 10")
      sql.should_not contain("LIMIT 20")
    end

    it "uses LIMIT from merged query if base has none" do
      base = Ralph::Query::Builder.new("users")

      additional = Ralph::Query::Builder.new("users")
        .limit(20)

      merged = base.merge(additional)
      sql = merged.build_select

      sql.should contain("LIMIT 20")
    end

    it "merges DISTINCT setting" do
      base = Ralph::Query::Builder.new("users")

      additional = Ralph::Query::Builder.new("users")
        .distinct

      merged = base.merge(additional)
      sql = merged.build_select

      sql.should contain("SELECT DISTINCT")
    end
  end

  describe "has_conditions? with combined clauses" do
    it "returns true when combined clauses are present" do
      query1 = Ralph::Query::Builder.new("users")
        .where("age > ?", 18)

      query2 = Ralph::Query::Builder.new("users")
        .where("role = ?", "admin")

      combined = query1.or(query2)
      combined.has_conditions?.should be_true
    end
  end

  describe "reset clears combined clauses" do
    it "clears combined clauses on reset" do
      query1 = Ralph::Query::Builder.new("users")
        .where("age > ?", 18)

      query2 = Ralph::Query::Builder.new("users")
        .where("role = ?", "admin")

      combined = query1.or(query2)
      reset_query = combined.reset

      sql = reset_query.build_select
      sql.should eq("SELECT * FROM \"users\"")
    end
  end

  describe "parameter numbering" do
    it "correctly numbers parameters across OR combined queries" do
      query1 = Ralph::Query::Builder.new("users")
        .where("a = ?", 1)
        .where("b = ?", 2)

      query2 = Ralph::Query::Builder.new("users")
        .where("c = ?", 3)
        .where("d = ?", 4)

      combined = query1.or(query2).where("e = ?", 5)
      sql = combined.build_select

      sql.should contain("$1")
      sql.should contain("$2")
      sql.should contain("$3")
      sql.should contain("$4")
      sql.should contain("$5")

      args = combined.all_args
      args.should eq([1, 2, 3, 4, 5])
    end

    it "correctly numbers parameters with subqueries and OR" do
      subquery = Ralph::Query::Builder.new("orders")
        .select("user_id")
        .where("total > ?", 100)

      query1 = Ralph::Query::Builder.new("users")
        .where("age > ?", 18)

      query2 = Ralph::Query::Builder.new("users")
        .where("role = ?", "admin")

      combined = query1.or(query2).where_in("id", subquery)
      sql = combined.build_select

      # Parameters should be in order: OR clause params, then subquery params
      sql.should contain("$1") # age > 18
      sql.should contain("$2") # role = admin
      sql.should contain("$3") # total > 100

      args = combined.all_args
      args.should eq([18, "admin", 100])
    end
  end
end

# Test model for scope testing
module Ralph
  class ScopeTestUser < Model
    table "scope_test_users"

    column id, Int64, primary: true
    column name, String
    column age, Int32
    column active, Bool
    column role, String?

    scope :active, ->(q : Query::Builder) { q.where("active = ?", true) }
    scope :adults, ->(q : Query::Builder) { q.where("age >= ?", 18) }
    scope :older_than, ->(q : Query::Builder, min_age : Int32) { q.where("age > ?", min_age) }
    scope :with_role, ->(q : Query::Builder, role : String) { q.where("role = ?", role) }
    scope :ordered_by_name, ->(q : Query::Builder) { q.order("name", :asc) }
    scope :limited, ->(q : Query::Builder, count : Int32) { q.limit(count) }
  end
end

describe "Model scopes" do
  describe "simple scope without arguments" do
    it "creates a query with scope conditions" do
      query = Ralph::ScopeTestUser.active
      sql = query.build_select

      sql.should eq("SELECT * FROM \"scope_test_users\" WHERE active = $1")

      args = query.all_args
      args.should eq([true])
    end

    it "allows chaining multiple scopes" do
      query = Ralph::ScopeTestUser.active.merge(Ralph::ScopeTestUser.adults)
      sql = query.build_select

      sql.should contain("active = $1")
      sql.should contain("age >= $2")

      args = query.all_args
      args.should eq([true, 18])
    end

    it "allows chaining scopes with other query methods" do
      query = Ralph::ScopeTestUser.active
        .order("name", :asc)
        .limit(10)
      sql = query.build_select

      sql.should contain("WHERE active = $1")
      sql.should contain("ORDER BY")
      sql.should contain("LIMIT 10")
    end
  end

  describe "scope with arguments" do
    it "creates a query with parameterized scope conditions" do
      query = Ralph::ScopeTestUser.older_than(21)
      sql = query.build_select

      sql.should eq("SELECT * FROM \"scope_test_users\" WHERE age > $1")

      args = query.all_args
      args.should eq([21])
    end

    it "creates a query with string argument" do
      query = Ralph::ScopeTestUser.with_role("admin")
      sql = query.build_select

      sql.should eq("SELECT * FROM \"scope_test_users\" WHERE role = $1")

      args = query.all_args
      args.should eq(["admin"])
    end

    it "allows chaining parameterized scopes" do
      query = Ralph::ScopeTestUser.older_than(18)
      query = query.merge(Ralph::ScopeTestUser.with_role("moderator"))
      sql = query.build_select

      sql.should contain("age > $1")
      sql.should contain("role = $2")

      args = query.all_args
      args.should eq([18, "moderator"])
    end
  end

  describe "scope with ORDER BY" do
    it "applies ORDER BY from scope" do
      query = Ralph::ScopeTestUser.ordered_by_name
      sql = query.build_select

      sql.should contain("ORDER BY \"name\" ASC")
    end

    it "chains ORDER BY scope with WHERE scope" do
      query = Ralph::ScopeTestUser.active.merge(Ralph::ScopeTestUser.ordered_by_name)
      sql = query.build_select

      sql.should contain("WHERE active = $1")
      sql.should contain("ORDER BY \"name\" ASC")
    end
  end

  describe "scope with LIMIT" do
    it "applies LIMIT from parameterized scope" do
      query = Ralph::ScopeTestUser.limited(5)
      sql = query.build_select

      sql.should contain("LIMIT 5")
    end
  end

  describe "anonymous/inline scopes" do
    it "creates an inline scope with block" do
      query = Ralph::ScopeTestUser.scoped { |q| q.where("active = ?", true) }
      sql = query.build_select

      sql.should eq("SELECT * FROM \"scope_test_users\" WHERE active = $1")
    end

    it "chains inline scopes with other query methods" do
      query = Ralph::ScopeTestUser.scoped { |q| q.where("age > ?", 18) }
        .order("name", :asc)
        .limit(10)
      sql = query.build_select

      sql.should contain("WHERE age > $1")
      sql.should contain("ORDER BY")
      sql.should contain("LIMIT 10")
    end

    it "supports complex inline scope logic" do
      query = Ralph::ScopeTestUser.scoped { |q|
        q.where("active = ?", true)
          .where("age >= ?", 18)
          .order("created_at", :desc)
      }
      sql = query.build_select

      sql.should contain("active = $1")
      sql.should contain("age >= $2")
      sql.should contain("ORDER BY")
    end
  end

  describe "combining named scopes with OR" do
    it "combines two scopes using OR" do
      active_query = Ralph::ScopeTestUser.active
      admin_query = Ralph::ScopeTestUser.with_role("admin")

      combined = active_query.or(admin_query)
      sql = combined.build_select

      sql.should contain("OR")
      sql.should contain("active = $1")
      sql.should contain("role = $2")

      args = combined.all_args
      args.should eq([true, "admin"])
    end
  end
end

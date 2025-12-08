require "../spec_helper"
require "../ralph/test_helper"

module Ralph
  # Test model for advanced query clauses
  class AdvancedClausesTestModel < Model
    table "posts_advanced"

    column id, Int64
    column title, String
    column category, String
    column views, Int32
    column published, Bool | Nil

    setup_validations
    setup_callbacks
  end

  describe "Advanced Query Clauses" do
    before_all do
      RalphTestHelper.setup_test_database

      # Create posts table with test data
      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS posts_advanced (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title VARCHAR(255) NOT NULL,
        category VARCHAR(100),
        views INTEGER DEFAULT 0,
        published BOOLEAN
      )
      SQL

      # Insert test data
      AdvancedClausesTestModel.create(title: "Post 1", category: "tech", views: 100, published: true)
      AdvancedClausesTestModel.create(title: "Post 2", category: "tech", views: 200, published: true)
      AdvancedClausesTestModel.create(title: "Post 3", category: "tech", views: 150, published: false)
      AdvancedClausesTestModel.create(title: "Post 4", category: "news", views: 50, published: true)
      AdvancedClausesTestModel.create(title: "Post 5", category: "news", views: 75, published: true)
    end

    before_each do
      # No cleanup needed between tests as we're just reading
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    describe "GROUP BY clause" do
      it "builds GROUP BY query" do
        query = Query::Builder.new("posts_advanced")
        query.group("category")

        sql = query.build_select
        sql.should contain("GROUP BY")
        sql.should contain("\"category\"")
      end

      it "groups by single column" do
        query = Query::Builder.new("posts_advanced")
        query.group("category")
        query.select("category")

        results = Ralph.database.query_all(query.build_select)
        categories = [] of String
        results.each do
          categories << results.read(String)
        end
        results.close

        categories.should contain("tech")
        categories.should contain("news")
      end

      it "groups by multiple columns" do
        query = Query::Builder.new("posts_advanced")
        query.group("category", "published")

        sql = query.build_select
        sql.should contain("GROUP BY")
        sql.should contain("\"category\"")
        sql.should contain("\"published\"")
      end
    end

    describe "HAVING clause" do
      it "builds HAVING query with GROUP BY" do
        query = Query::Builder.new("posts_advanced")
        query.group("category")
        query.having("COUNT(*) > 1")

        sql = query.build_select
        sql.should contain("GROUP BY")
        sql.should contain("HAVING")
        sql.should contain("COUNT(*) > 1")
      end

      it "uses HAVING with parameterized conditions" do
        query = Query::Builder.new("posts_advanced")
        query.group("category")
        query.having("SUM(views) > ?", 200)

        sql = query.build_select
        sql.should contain("HAVING")
        sql.should contain("SUM(views) > $1")
      end
    end

    describe "DISTINCT clause" do
      it "builds DISTINCT query" do
        query = Query::Builder.new("posts_advanced")
        query.distinct

        sql = query.build_select
        sql.should start_with("SELECT DISTINCT")
      end

      it "builds DISTINCT with specific columns using GROUP BY" do
        query = Query::Builder.new("posts_advanced")
        query.distinct("category")

        sql = query.build_select
        # SQLite uses GROUP BY for column-specific distinct
        sql.should contain("GROUP BY")
        sql.should contain("\"category\"")
      end

      it "returns distinct categories" do
        query = Query::Builder.new("posts_advanced")
        query.distinct("category")
        query.select("category")
        query.order("category")

        results = Ralph.database.query_all(query.build_select)
        categories = [] of String
        results.each do
          categories << results.read(String)
        end
        results.close

        categories.should eq(["news", "tech"])
      end

      it "returns distinct values" do
        query = Query::Builder.new("posts_advanced")
        query.distinct
        query.select("category")
        query.order("category")

        results = Ralph.database.query_all(query.build_select)
        categories = [] of String
        results.each do
          categories << results.read(String)
        end
        results.close

        categories.should eq(["news", "tech"])
      end
    end

    describe "Model convenience methods" do
      it "provides group_by class method" do
        query = AdvancedClausesTestModel.group_by("category")

        sql = query.build_select
        sql.should contain("GROUP BY")
      end

      it "provides distinct class method" do
        query = AdvancedClausesTestModel.distinct("category")

        sql = query.build_select
        # SQLite uses GROUP BY for column-specific distinct
        sql.should contain("GROUP BY")
        sql.should contain("\"category\"")
      end

      it "provides distinct without columns" do
        query = AdvancedClausesTestModel.distinct

        sql = query.build_select
        sql.should start_with("SELECT DISTINCT")
      end
    end

    describe "Combined clauses" do
      it "combines GROUP BY, HAVING, and ORDER BY" do
        query = Query::Builder.new("posts_advanced")
        query.group("category")
        query.having("SUM(views) > ?", 100)
        query.order("category")

        sql = query.build_select
        sql.should contain("GROUP BY")
        sql.should contain("HAVING")
        sql.should contain("ORDER BY")
      end

      it "combines WHERE, GROUP BY, and HAVING" do
        query = Query::Builder.new("posts_advanced")
        query.where("published = ?", true)
        query.group("category")
        query.having("COUNT(*) >= ?", 2)

        sql = query.build_select
        sql.should contain("WHERE")
        sql.should contain("GROUP BY")
        sql.should contain("HAVING")
      end

      it "combines DISTINCT with WHERE and ORDER BY" do
        query = Query::Builder.new("posts_advanced")
        query.distinct
        query.where("views > ?", 50)
        query.order("views", :desc)

        sql = query.build_select
        sql.should contain("SELECT DISTINCT")
        sql.should contain("WHERE")
        sql.should contain("ORDER BY")
      end
    end
  end
end

require "../spec_helper"
require "../ralph/test_helper"

module Ralph
  # Test models for joins
  class JoinTestUser < Model
    table "join_test_users"

    column id, Int64, primary: true
    column name, String
    column email, String?

    setup_validations
    setup_callbacks
  end

  class JoinTestPost < Model
    table "join_test_posts"

    column id, Int64, primary: true
    column title, String
    column content, String?
    column user_id, Int64?
    column author_id, Int64?

    setup_validations
    setup_callbacks
  end

  class JoinTestComment < Model
    table "join_test_comments"

    column id, Int64, primary: true
    column body, String
    column post_id, Int64?

    setup_validations
    setup_callbacks
  end

  # Test models with associations
  class JoinAssocUser < Model
    table "join_test_users"

    column id, Int64, primary: true
    column name, String
    column email, String?

    has_many posts
    has_one profile

    setup_validations
    setup_callbacks
  end

  class JoinAssocPost < Model
    table "join_test_posts"

    column id, Int64, primary: true
    column title, String
    column content, String?
    column user_id, Int64?
    column author_id, Int64?

    belongs_to user
    has_many comments

    setup_validations
    setup_callbacks
  end

  class JoinAssocComment < Model
    table "join_test_comments"

    column id, Int64, primary: true
    column body, String
    column post_id, Int64?

    belongs_to post

    setup_validations
    setup_callbacks
  end

  describe "Joins" do
    before_all do
      RalphTestHelper.setup_test_database

      # Create test tables
      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS join_test_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255)
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS join_test_posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title VARCHAR(255) NOT NULL,
        content TEXT,
        user_id INTEGER,
        author_id INTEGER
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS join_test_comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        body TEXT NOT NULL,
        post_id INTEGER
      )
      SQL
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    before_each do
      # Clean tables before each test
      Ralph.database.execute("DELETE FROM join_test_users")
      Ralph.database.execute("DELETE FROM join_test_posts")
      Ralph.database.execute("DELETE FROM join_test_comments")
    end

    describe "Basic Joins" do
      it "supports INNER JOIN" do
        user = JoinTestUser.create(name: "Alice")
        post = JoinTestPost.create(title: "Hello", user_id: user.id)

        query = JoinTestUser.query
          .join("join_test_posts", "\"join_test_posts\".\"user_id\" = \"join_test_users\".\"id\"")

        sql = query.build_select
        sql.should contain("INNER JOIN")
        sql.should contain("\"join_test_posts\"")
        sql.should contain("user_id")
      end

      it "supports LEFT JOIN" do
        query = JoinTestUser.query
          .left_join("join_test_posts", "\"join_test_posts\".\"user_id\" = \"join_test_users\".\"id\"")

        sql = query.build_select
        sql.should contain("LEFT JOIN")
        sql.should contain("\"join_test_posts\"")
      end

      it "supports RIGHT JOIN" do
        query = JoinTestUser.query
          .right_join("join_test_posts", "\"join_test_posts\".\"user_id\" = \"join_test_users\".\"id\"")

        sql = query.build_select
        sql.should contain("RIGHT JOIN")
        sql.should contain("\"join_test_posts\"")
      end

      it "supports CROSS JOIN" do
        query = JoinTestUser.query.cross_join("join_test_posts")

        sql = query.build_select
        sql.should contain("CROSS JOIN")
        # CROSS JOIN shouldn't have ON clause
        sql.should_not contain(" ON ")
      end

      it "supports FULL OUTER JOIN" do
        query = JoinTestUser.query
          .full_outer_join("join_test_posts", "\"join_test_posts\".\"user_id\" = \"join_test_users\".\"id\"")

        sql = query.build_select
        sql.should contain("FULL OUTER JOIN")
        sql.should contain("\"join_test_posts\"")
      end

      it "supports FULL JOIN as alias for FULL OUTER JOIN" do
        query = JoinTestUser.query
          .full_join("join_test_posts", "\"join_test_posts\".\"user_id\" = \"join_test_users\".\"id\"")

        sql = query.build_select
        sql.should contain("FULL OUTER JOIN")
      end
    end

    describe "Join Aliases" do
      it "supports table aliases in joins" do
        query = JoinTestUser.query
          .join("join_test_posts", "\"p\".\"user_id\" = \"join_test_users\".\"id\"", alias: "p")

        sql = query.build_select
        sql.should contain("AS \"p\"")
      end

      it "supports aliases with LEFT JOIN" do
        query = JoinTestUser.query
          .left_join("join_test_posts", "\"p\".\"user_id\" = \"join_test_users\".\"id\"", alias: "p")

        sql = query.build_select
        sql.should contain("LEFT JOIN")
        sql.should contain("AS \"p\"")
      end

      it "supports aliases with CROSS JOIN" do
        query = JoinTestUser.query.cross_join("join_test_posts", alias: "p")

        sql = query.build_select
        sql.should contain("CROSS JOIN \"join_test_posts\" AS \"p\"")
      end
    end

    describe "Association Joins" do
      it "joins belongs_to association" do
        user = JoinAssocUser.create(name: "Alice")
        post = JoinAssocPost.create(title: "Hello", user_id: user.id)

        query = JoinAssocPost.join_assoc(:user)
        sql = query.build_select

        sql.should contain("INNER JOIN")
        # Association metadata uses convention-based table names
        sql.should contain("\"user\"")
        sql.should contain("\"user\".\"id\" = \"join_test_posts\".\"user_id\"")
      end

      it "joins has_many association" do
        user = JoinAssocUser.create(name: "Alice")
        post = JoinAssocPost.create(title: "Hello", user_id: user.id)

        query = JoinAssocUser.join_assoc(:posts)
        sql = query.build_select

        sql.should contain("INNER JOIN")
        # Association metadata uses the association name for table
        sql.should contain("\"posts\"")
        sql.should contain("\"posts\".\"join_assoc_user_id\" = \"join_test_users\".\"id\"")
      end

      it "joins has_one association" do
        query = JoinAssocUser.join_assoc(:profile)
        sql = query.build_select

        sql.should contain("INNER JOIN")
        # has_one uses the association name as table name
        sql.should contain("\"profile\"")
        # has_one uses the model's foreign key pointing to self
        sql.should contain("\"profile\".\"join_assoc_user_id\" = \"join_test_users\".\"id\"")
      end

      it "joins association with LEFT JOIN type" do
        query = JoinAssocPost.join_assoc(:user, :left)
        sql = query.build_select

        sql.should contain("LEFT JOIN")
        sql.should contain("\"user\"")
      end

      it "joins association with alias" do
        query = JoinAssocPost.join_assoc(:user, :inner, "u")
        sql = query.build_select

        sql.should contain("AS \"u\"")
      end

      it "raises error for unknown association" do
        expect_raises(Exception, /Unknown association/) do
          JoinAssocPost.join_assoc(:nonexistent)
        end
      end

      it "chains association joins with where conditions" do
        user = JoinAssocUser.create(name: "Alice")
        post = JoinAssocPost.create(title: "Hello", user_id: user.id)

        query = JoinAssocPost.join_assoc(:user).where("\"user\".\"name\" = ?", "Alice")
        sql = query.build_select

        sql.should contain("INNER JOIN")
        sql.should contain("WHERE")
        sql.should contain("\"user\".\"name\"")
      end
    end

    describe "Complex Join Scenarios" do
      it "supports multiple joins" do
        user = JoinTestUser.create(name: "Alice")
        post = JoinTestPost.create(title: "Hello", user_id: user.id)
        comment = JoinTestComment.create(body: "Great!", post_id: post.id)

        query = JoinTestUser.query
          .join("join_test_posts", "\"join_test_posts\".\"user_id\" = \"join_test_users\".\"id\"")
          .join("join_test_comments", "\"join_test_comments\".\"post_id\" = \"join_test_posts\".\"id\"")

        sql = query.build_select
        (sql =~ /INNER JOIN.*INNER JOIN/m).should_not be_nil
      end

      it "supports joins with GROUP BY" do
        user = JoinTestUser.create(name: "Alice")
        JoinTestPost.create(title: "Hello", user_id: user.id)
        JoinTestPost.create(title: "World", user_id: user.id)

        query = JoinTestUser.query
          .join("join_test_posts", "\"join_test_posts\".\"user_id\" = \"join_test_users\".\"id\"")
          .group("join_test_users.id")

        sql = query.build_select
        sql.should contain("INNER JOIN")
        sql.should contain("GROUP BY")
      end

      it "supports joins with ORDER BY" do
        query = JoinTestUser.query
          .join("join_test_posts", "\"join_test_posts\".\"user_id\" = \"join_test_users\".\"id\"")
          .order("join_test_posts.title", :asc)

        sql = query.build_select
        sql.should contain("INNER JOIN")
        sql.should contain("ORDER BY")
      end

      it "supports joins with LIMIT" do
        query = JoinTestUser.query
          .join("join_test_posts", "\"join_test_posts\".\"user_id\" = \"join_test_users\".\"id\"")
          .limit(5)

        sql = query.build_select
        sql.should contain("INNER JOIN")
        sql.should contain("LIMIT 5")
      end

      it "supports self-joins with aliases" do
        query = JoinTestUser.query
          .join("join_test_users", "\"u2\".\"id\" = \"join_test_users\".\"id\"", alias: "u2")

        sql = query.build_select
        sql.should contain("AS \"u2\"")
      end
    end
  end
end

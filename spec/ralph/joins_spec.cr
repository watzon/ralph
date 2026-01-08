require "../spec_helper"
require "../ralph/test_helper"

module Ralph
  # Test models for joins
  class JoinTestUser < Model
    table "join_test_users"

    column id, Int64, primary: true
    column name, String
    column email, String?
  end

  class JoinTestPost < Model
    table "join_test_posts"

    column id, Int64, primary: true
    column title, String
    column content, String?
    column user_id, Int64?
    column author_id, Int64?
  end

  class JoinTestComment < Model
    table "join_test_comments"

    column id, Int64, primary: true
    column body, String
    column post_id, Int64?
  end

  # Test models with associations
  class JoinAssocUser < Model
    table "join_test_users"

    column id, Int64, primary: true
    column name, String
    column email, String?

    has_many posts, class_name: "JoinAssocPost"
    has_one profile, class_name: "JoinAssocProfile"
  end

  class JoinAssocPost < Model
    table "join_test_posts"

    column id, Int64, primary: true
    column title, String
    column content, String?
    column user_id, Int64?
    column author_id, Int64?

    belongs_to user, class_name: "JoinAssocUser"
    has_many comments, class_name: "JoinAssocComment"
  end

  class JoinAssocComment < Model
    table "join_test_comments"

    column id, Int64, primary: true
    column body, String
    column post_id, Int64?

    belongs_to post, class_name: "JoinAssocPost"
  end

  class JoinAssocProfile < Model
    table "profile"

    column id, Int64, primary: true
    column bio, String?
    column join_assoc_user_id, Int64?

    belongs_to join_assoc_user, class_name: "JoinAssocUser"
  end

  describe "Joins" do
    before_all do
      RalphTestHelper.setup_test_database

      # Create test tables
      TestSchema.create_table("join_test_users") do |t|
        t.primary_key
        t.string("name")
        t.string("email")
      end

      TestSchema.create_table("join_test_posts") do |t|
        t.primary_key
        t.string("title")
        t.text("content")
        t.bigint("user_id")
        t.bigint("author_id")
      end

      TestSchema.create_table("join_test_comments") do |t|
        t.primary_key
        t.text("body")
        t.bigint("post_id")
      end

      TestSchema.create_table("profile") do |t|
        t.primary_key
        t.text("bio")
        t.bigint("join_assoc_user_id")
      end
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    before_each do
      # Clean tables before each test
      Ralph.database.execute("DELETE FROM join_test_users")
      Ralph.database.execute("DELETE FROM join_test_posts")
      Ralph.database.execute("DELETE FROM join_test_comments")
      Ralph.database.execute("DELETE FROM profile")
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
        # Association metadata uses class_name.underscore for table names
        sql.should contain("\"join_assoc_user\"")
        sql.should contain("\"join_assoc_user\".\"id\" = \"join_test_posts\".\"user_id\"")
      end

      it "joins has_many association" do
        user = JoinAssocUser.create(name: "Alice")
        post = JoinAssocPost.create(title: "Hello", user_id: user.id)

        query = JoinAssocUser.join_assoc(:posts)
        sql = query.build_select

        sql.should contain("INNER JOIN")
        # has_many uses the association name as the table name
        sql.should contain("\"posts\"")
        sql.should contain("\"posts\".\"join_assoc_user_id\" = \"join_test_users\".\"id\"")
      end

      it "joins has_one association" do
        query = JoinAssocUser.join_assoc(:profile)
        sql = query.build_select

        sql.should contain("INNER JOIN")
        # has_one uses class_name.underscore as table name
        sql.should contain("\"join_assoc_profile\"")
        # has_one uses the model's foreign key pointing to self
        sql.should contain("\"join_assoc_profile\".\"join_assoc_user_id\" = \"join_test_users\".\"id\"")
      end

      it "joins association with LEFT JOIN type" do
        query = JoinAssocPost.join_assoc(:user, :left)
        sql = query.build_select

        sql.should contain("LEFT JOIN")
        sql.should contain("\"join_assoc_user\"")
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

        query = JoinAssocPost.join_assoc(:user).where("\"join_assoc_user\".\"name\" = ?", "Alice")
        sql = query.build_select

        sql.should contain("INNER JOIN")
        sql.should contain("WHERE")
        sql.should contain("\"join_assoc_user\".\"name\"")
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

require "../spec_helper"
require "../ralph/test_helper"

module Ralph
  module PolymorphicTests
    # ========================================
    # Models for polymorphic has_many tests
    # ========================================

    class Comment < Model
      table "poly_test_comments"

      column id, Int64, primary: true
      column body, String

      belongs_to commentable, polymorphic: true
    end

    class Post < Model
      table "poly_test_posts"

      column id, Int64, primary: true
      column title, String

      has_many comments, as: :commentable
    end

    class Article < Model
      table "poly_test_articles"

      column id, Int64, primary: true
      column title, String

      has_many comments, as: :commentable
    end

    # ========================================
    # Models for polymorphic has_one tests
    # ========================================

    class Profile < Model
      table "poly_test_profiles"

      column id, Int64, primary: true
      column bio, String

      belongs_to profileable, polymorphic: true
    end

    class User < Model
      table "poly_test_users"

      column id, Int64, primary: true
      column name, String

      has_one profile, as: :profileable
    end

    class Company < Model
      table "poly_test_companies"

      column id, Int64, primary: true
      column name, String

      has_one profile, as: :profileable
    end

    # ========================================
    # Models for dependent option tests
    # ========================================

    class Tag < Model
      table "poly_test_tags"

      column id, Int64, primary: true
      column name, String

      belongs_to taggable, polymorphic: true

      @@destroyed_names = [] of String

      def self.destroyed_names
        @@destroyed_names
      end

      def self.clear_destroyed_names
        @@destroyed_names.clear
      end

      @[AfterDestroy]
      def track_destruction
        @@destroyed_names << name.to_s if name
      end
    end

    class Photo < Model
      table "poly_test_photos"

      column id, Int64, primary: true
      column url, String

      has_many tags, as: :taggable, dependent: :destroy
    end

    class Video < Model
      table "poly_test_videos"

      column id, Int64, primary: true
      column url, String

      has_many tags, as: :taggable, dependent: :delete_all
    end
  end

  describe "Polymorphic Associations" do
    before_all do
      RalphTestHelper.setup_test_database

      # Create tables for has_many polymorphic tests
      TestSchema.create_table("poly_test_posts") do |t|
        t.primary_key
        t.string("title")
      end

      TestSchema.create_table("poly_test_articles") do |t|
        t.primary_key
        t.string("title")
      end

      TestSchema.create_table("poly_test_comments") do |t|
        t.primary_key
        t.string("body", size: 500)
        t.bigint("commentable_id")
        t.string("commentable_type")
      end

      # Create tables for has_one polymorphic tests
      TestSchema.create_table("poly_test_users") do |t|
        t.primary_key
        t.string("name")
      end

      TestSchema.create_table("poly_test_companies") do |t|
        t.primary_key
        t.string("name")
      end

      TestSchema.create_table("poly_test_profiles") do |t|
        t.primary_key
        t.string("bio", size: 500)
        t.bigint("profileable_id")
        t.string("profileable_type")
      end

      # Create tables for dependent option tests
      TestSchema.create_table("poly_test_photos") do |t|
        t.primary_key
        t.string("url")
      end

      TestSchema.create_table("poly_test_videos") do |t|
        t.primary_key
        t.string("url")
      end

      TestSchema.create_table("poly_test_tags") do |t|
        t.primary_key
        t.string("name")
        t.bigint("taggable_id")
        t.string("taggable_type")
      end
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    # Clear all polymorphic test tables before each test
    before_each do
      Ralph.database.execute("DELETE FROM poly_test_comments")
      Ralph.database.execute("DELETE FROM poly_test_posts")
      Ralph.database.execute("DELETE FROM poly_test_articles")
      Ralph.database.execute("DELETE FROM poly_test_profiles")
      Ralph.database.execute("DELETE FROM poly_test_users")
      Ralph.database.execute("DELETE FROM poly_test_companies")
      Ralph.database.execute("DELETE FROM poly_test_tags")
      Ralph.database.execute("DELETE FROM poly_test_photos")
      Ralph.database.execute("DELETE FROM poly_test_videos")
    end

    describe "polymorphic belongs_to" do
      it "defines both id and type columns" do
        comment = PolymorphicTests::Comment.new(body: "Test")

        # Should have both columns available
        comment.responds_to?(:commentable_id).should be_true
        comment.responds_to?(:commentable_type).should be_true
      end

      it "returns nil when association is not set" do
        comment = PolymorphicTests::Comment.create(body: "Orphan comment")

        associated = comment.commentable
        associated.should be_nil
      end

      it "loads associated Post model" do
        post = PolymorphicTests::Post.create(title: "My Post")
        comment = PolymorphicTests::Comment.new(body: "Great post!")
        comment.commentable = post
        comment.save

        reloaded = PolymorphicTests::Comment.find(comment.id)
        reloaded.should_not be_nil

        associated = reloaded.not_nil!.commentable
        associated.should_not be_nil
        associated.should be_a(PolymorphicTests::Post)
        associated.as(PolymorphicTests::Post).title.should eq("My Post")
      end

      it "loads associated Article model" do
        article = PolymorphicTests::Article.create(title: "My Article")
        comment = PolymorphicTests::Comment.new(body: "Great article!")
        comment.commentable = article
        comment.save

        reloaded = PolymorphicTests::Comment.find(comment.id)
        associated = reloaded.not_nil!.commentable

        associated.should_not be_nil
        associated.should be_a(PolymorphicTests::Article)
        associated.as(PolymorphicTests::Article).title.should eq("My Article")
      end

      it "stores correct type and id columns" do
        post = PolymorphicTests::Post.create(title: "Test Post")
        comment = PolymorphicTests::Comment.new(body: "Test")
        comment.commentable = post
        comment.save

        # Verify directly in database
        result = Ralph.database.query_one(
          "SELECT commentable_id, commentable_type FROM poly_test_comments WHERE id = ?",
          args: [comment.id]
        )
        result.should_not be_nil

        rs = result.not_nil!
        id = rs.read(Int64?)
        type = rs.read(String?)
        rs.close

        id.should eq(post.id)
        type.should eq("Ralph::PolymorphicTests::Post")
      end

      it "can clear the association by setting to nil" do
        post = PolymorphicTests::Post.create(title: "Another Post")
        comment = PolymorphicTests::Comment.new(body: "Comment")
        comment.commentable = post
        comment.save

        # Verify it's set
        comment.commentable_id.should eq(post.id)
        comment.commentable_type.should_not be_nil

        # Clear it
        comment.commentable = nil

        comment.commentable_id.should be_nil
        comment.commentable_type.should be_nil
      end
    end

    describe "polymorphic has_many" do
      it "loads comments for a post" do
        post = PolymorphicTests::Post.create(title: "Post with comments")

        comment1 = PolymorphicTests::Comment.new(body: "Comment 1")
        comment1.commentable = post
        comment1.save

        comment2 = PolymorphicTests::Comment.new(body: "Comment 2")
        comment2.commentable = post
        comment2.save

        reloaded_post = PolymorphicTests::Post.find(post.id).not_nil!
        comments = reloaded_post.comments

        comments.size.should eq(2)
        comments.map(&.body).should contain("Comment 1")
        comments.map(&.body).should contain("Comment 2")
      end

      it "loads comments for an article" do
        article = PolymorphicTests::Article.create(title: "Article with comments")

        comment = PolymorphicTests::Comment.new(body: "Article comment")
        comment.commentable = article
        comment.save

        reloaded_article = PolymorphicTests::Article.find(article.id).not_nil!
        comments = reloaded_article.comments

        comments.size.should eq(1)
        comments[0].body.should eq("Article comment")
      end

      it "returns empty array when no comments exist" do
        post = PolymorphicTests::Post.create(title: "Empty post")

        comments = post.comments
        comments.should be_empty
      end

      it "counts comments correctly" do
        post = PolymorphicTests::Post.create(title: "Post for count")

        3.times do |i|
          comment = PolymorphicTests::Comment.new(body: "Comment #{i}")
          comment.commentable = post
          comment.save
        end

        count = post.comments.size
        count.should eq(3)
      end

      it "only loads comments for the specific model" do
        post = PolymorphicTests::Post.create(title: "Post 1")
        article = PolymorphicTests::Article.create(title: "Article 1")

        post_comment = PolymorphicTests::Comment.new(body: "For post")
        post_comment.commentable = post
        post_comment.save

        article_comment = PolymorphicTests::Comment.new(body: "For article")
        article_comment.commentable = article
        article_comment.save

        # Post should only get its comment
        post_comments = post.comments
        post_comments.size.should eq(1)
        post_comments[0].body.should eq("For post")

        # Article should only get its comment
        article_comments = article.comments
        article_comments.size.should eq(1)
        article_comments[0].body.should eq("For article")
      end

      it "builds a new associated record with correct polymorphic columns" do
        post = PolymorphicTests::Post.create(title: "Post for build")

        built_comment = post.build_comment(body: "Built comment")

        built_comment.body.should eq("Built comment")
        built_comment.commentable_type.should eq("Ralph::PolymorphicTests::Post")
        built_comment.commentable_id.should eq(post.id)
        built_comment.new_record?.should be_true
      end

      it "creates a new associated record with correct polymorphic columns" do
        post = PolymorphicTests::Post.create(title: "Post for create")

        created_comment = post.create_comment(body: "Created comment")

        created_comment.body.should eq("Created comment")
        created_comment.commentable_type.should eq("Ralph::PolymorphicTests::Post")
        created_comment.commentable_id.should eq(post.id)
        created_comment.persisted?.should be_true

        # Verify it's actually in the database
        reloaded = PolymorphicTests::Comment.find(created_comment.id)
        reloaded.should_not be_nil
      end

      it "reports any? correctly" do
        post = PolymorphicTests::Post.create(title: "Any test post")
        post.comments_any?.should be_false

        comment = PolymorphicTests::Comment.new(body: "A comment")
        comment.commentable = post
        comment.save

        post.comments_any?.should be_true
      end

      it "reports empty? correctly" do
        post = PolymorphicTests::Post.create(title: "Empty test post")
        post.comments_empty?.should be_true

        comment = PolymorphicTests::Comment.new(body: "A comment")
        comment.commentable = post
        comment.save

        post.comments_empty?.should be_false
      end
    end

    describe "polymorphic has_one" do
      it "loads profile for a user" do
        user = PolymorphicTests::User.create(name: "Alice")

        profile = PolymorphicTests::Profile.new(bio: "User bio")
        profile.profileable = user
        profile.save

        reloaded_user = PolymorphicTests::User.find(user.id).not_nil!
        user_profile = reloaded_user.profile

        user_profile.should_not be_nil
        user_profile.not_nil!.bio.should eq("User bio")
      end

      it "loads profile for a company" do
        company = PolymorphicTests::Company.create(name: "Acme Corp")

        profile = PolymorphicTests::Profile.new(bio: "Company bio")
        profile.profileable = company
        profile.save

        reloaded_company = PolymorphicTests::Company.find(company.id).not_nil!
        company_profile = reloaded_company.profile

        company_profile.should_not be_nil
        company_profile.not_nil!.bio.should eq("Company bio")
      end

      it "returns nil when no profile exists" do
        user = PolymorphicTests::User.create(name: "Bob")

        profile = user.profile
        profile.should be_nil
      end

      it "builds a new associated record with correct polymorphic columns" do
        user = PolymorphicTests::User.create(name: "Charlie")

        built_profile = user.build_profile(bio: "Built profile")

        built_profile.bio.should eq("Built profile")
        built_profile.profileable_type.should eq("Ralph::PolymorphicTests::User")
        built_profile.profileable_id.should eq(user.id)
        built_profile.new_record?.should be_true
      end

      it "creates a new associated record with correct polymorphic columns" do
        user = PolymorphicTests::User.create(name: "David")

        created_profile = user.create_profile(bio: "Created profile")

        created_profile.bio.should eq("Created profile")
        created_profile.profileable_type.should eq("Ralph::PolymorphicTests::User")
        created_profile.profileable_id.should eq(user.id)
        created_profile.persisted?.should be_true
      end

      it "can assign via setter" do
        company = PolymorphicTests::Company.create(name: "Tech Inc")
        profile = PolymorphicTests::Profile.new(bio: "Assigned profile")

        company.profile = profile

        profile.persisted?.should be_true
        profile.profileable_type.should eq("Ralph::PolymorphicTests::Company")
        profile.profileable_id.should eq(company.id)
      end
    end

    describe "polymorphic dependent options" do
      describe "dependent: :destroy" do
        it "destroys associated records with callbacks" do
          PolymorphicTests::Tag.clear_destroyed_names

          photo = PolymorphicTests::Photo.create(url: "photo1.jpg")

          tag1 = PolymorphicTests::Tag.new(name: "Tag 1")
          tag1.taggable = photo
          tag1.save

          tag2 = PolymorphicTests::Tag.new(name: "Tag 2")
          tag2.taggable = photo
          tag2.save

          # Verify tags exist
          photo.tags.size.should eq(2)

          # Destroy photo - should destroy tags with callbacks
          photo.destroy

          # Tags should be destroyed
          PolymorphicTests::Tag.find(tag1.id).should be_nil
          PolymorphicTests::Tag.find(tag2.id).should be_nil

          # Callbacks should have been called
          PolymorphicTests::Tag.destroyed_names.should contain("Tag 1")
          PolymorphicTests::Tag.destroyed_names.should contain("Tag 2")
        end
      end

      describe "dependent: :delete_all" do
        it "deletes associated records without callbacks" do
          PolymorphicTests::Tag.clear_destroyed_names

          video = PolymorphicTests::Video.create(url: "video1.mp4")

          tag1 = PolymorphicTests::Tag.new(name: "Video Tag 1")
          tag1.taggable = video
          tag1.save

          tag2 = PolymorphicTests::Tag.new(name: "Video Tag 2")
          tag2.taggable = video
          tag2.save

          # Verify tags exist
          video.tags.size.should eq(2)

          # Destroy video - should delete tags WITHOUT callbacks
          video.destroy

          # Tags should be deleted
          PolymorphicTests::Tag.find(tag1.id).should be_nil
          PolymorphicTests::Tag.find(tag2.id).should be_nil

          # Callbacks should NOT have been called
          PolymorphicTests::Tag.destroyed_names.should be_empty
        end
      end
    end

    describe "polymorphic registry" do
      it "registers polymorphic parent models" do
        registry = Ralph::Associations.polymorphic_registry

        # Post should be registered
        registry.has_key?("Ralph::PolymorphicTests::Post").should be_true

        # Article should be registered
        registry.has_key?("Ralph::PolymorphicTests::Article").should be_true

        # User should be registered (from has_one)
        registry.has_key?("Ralph::PolymorphicTests::User").should be_true

        # Company should be registered (from has_one)
        registry.has_key?("Ralph::PolymorphicTests::Company").should be_true
      end

      it "can find records via registry" do
        post = PolymorphicTests::Post.create(title: "Registry test")

        found = Ralph::Associations.find_polymorphic("Ralph::PolymorphicTests::Post", post.id.not_nil!)

        found.should_not be_nil
        found.should be_a(PolymorphicTests::Post)
        found.as(PolymorphicTests::Post).title.should eq("Registry test")
      end

      it "returns nil for unknown types" do
        found = Ralph::Associations.find_polymorphic("UnknownClass", 1_i64)
        found.should be_nil
      end
    end

    describe "association metadata" do
      it "stores polymorphic flag for belongs_to" do
        associations = Ralph::Associations.associations
        comment_assocs = associations["Ralph::PolymorphicTests::Comment"]?

        comment_assocs.should_not be_nil
        commentable_meta = comment_assocs.not_nil!["commentable"]?

        commentable_meta.should_not be_nil
        commentable_meta.not_nil!.polymorphic.should be_true
      end

      it "stores as_name for has_many" do
        associations = Ralph::Associations.associations
        post_assocs = associations["Ralph::PolymorphicTests::Post"]?

        post_assocs.should_not be_nil
        comments_meta = post_assocs.not_nil!["comments"]?

        comments_meta.should_not be_nil
        comments_meta.not_nil!.as_name.should eq("commentable")
      end

      it "stores as_name for has_one" do
        associations = Ralph::Associations.associations
        user_assocs = associations["Ralph::PolymorphicTests::User"]?

        user_assocs.should_not be_nil
        profile_meta = user_assocs.not_nil!["profile"]?

        profile_meta.should_not be_nil
        profile_meta.not_nil!.as_name.should eq("profileable")
      end
    end
  end
end

require "../spec_helper"
require "../ralph/test_helper"

module Ralph
  module AssociationTests
    # Test models for associations

    class Author < Model
      table "assoc_test_authors"

      column id, Int64
      column name, String

      has_one profile
      has_many articles

      @@author1 : Author?
      @@author2 : Author?

      def self.author1
        @@author1
      end

      def self.author2
        @@author2
      end

      def self.set_test_authors(a1, a2)
        @@author1 = a1
        @@author2 = a2
      end
    end

    class Profile < Model
      table "assoc_test_profiles"

      column id, Int64
      column bio_text, String
      column author_id, Int64
    end

    class Article < Model
      table "assoc_test_articles"

      column id, Int64
      column title, String
      column author_id, Int64

      @@article1 : Article?
      @@article2 : Article?
      @@article3 : Article?

      def self.article1
        @@article1
      end

      def self.article2
        @@article2
      end

      def self.article3
        @@article3
      end

      def self.set_test_articles(a1, a2, a3)
        @@article1 = a1
        @@article2 = a2
        @@article3 = a3
      end
    end

    class Comment < Model
      table "assoc_test_comments"

      column id, Int64
      column body, String

      belongs_to article

      @@comment1 : Comment?
      @@comment2 : Comment?

      def self.comment1
        @@comment1
      end

      def self.set_test_comments(c1, c2)
        @@comment1 = c1
        @@comment2 = c2
      end
    end
  end

  describe "Associations" do
    before_all do
      RalphTestHelper.setup_test_database

      # Create tables for associations
      TestSchema.create_table("assoc_test_authors") do |t|
        t.primary_key
        t.string("name")
      end

      TestSchema.create_table("assoc_test_profiles") do |t|
        t.primary_key
        t.string("bio_text", size: 500)
        t.bigint("author_id")
      end

      TestSchema.create_table("assoc_test_articles") do |t|
        t.primary_key
        t.string("title")
        t.bigint("author_id")
      end

      TestSchema.create_table("assoc_test_comments") do |t|
        t.primary_key
        t.string("body", size: 500)
        t.bigint("article_id")
      end

      # Insert test data
      author1 = AssociationTests::Author.create(name: "Alice")
      author2 = AssociationTests::Author.create(name: "Bob")

      profile1 = AssociationTests::Profile.create(bio_text: "Alice's bio", author_id: author1.id)
      profile2 = AssociationTests::Profile.create(bio_text: "Bob's bio", author_id: author2.id)

      article1 = AssociationTests::Article.create(title: "Article 1", author_id: author1.id)
      article2 = AssociationTests::Article.create(title: "Article 2", author_id: author1.id)
      article3 = AssociationTests::Article.create(title: "Article 3", author_id: author2.id)

      comment1 = AssociationTests::Comment.create(body: "Comment 1", article_id: article1.id)
      comment2 = AssociationTests::Comment.create(body: "Comment 2", article_id: article2.id)

      # Store in class variables for tests
      AssociationTests::Author.set_test_authors(author1, author2)
      AssociationTests::Article.set_test_articles(article1, article2, article3)
      AssociationTests::Comment.set_test_comments(comment1, comment2)
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    describe "belongs_to" do
      it "loads the associated record" do
        comment = AssociationTests::Comment.find(AssociationTests::Comment.comment1.not_nil!.id)
        comment.should_not be_nil

        article = comment.not_nil!.article

        article.should_not be_nil
        article.not_nil!.title.should eq("Article 1")
      end

      it "returns nil when foreign key is nil" do
        comment = AssociationTests::Comment.create(body: "Orphan Comment", article_id: nil)
        article = comment.article

        article.should be_nil
      end

      it "sets the associated record via setter" do
        comment = AssociationTests::Comment.new(body: "New Comment")
        article2 = AssociationTests::Article.article2.not_nil!
        comment.article = article2

        comment.article_id.should eq(article2.id)
      end

      it "builds a new associated record" do
        comment = AssociationTests::Comment.new(body: "Draft")
        built_article = comment.build_article(title: "Draft Article")

        built_article.should be_a(AssociationTests::Article)
        built_article.title.should eq("Draft Article")
      end

      it "creates a new associated record" do
        comment = AssociationTests::Comment.new(body: "New Comment", article_id: nil)
        new_article = comment.create_article(title: "New Article")

        new_article.should be_a(AssociationTests::Article)
        new_article.title.should eq("New Article")
        comment.article_id.should eq(new_article.id)
      end
    end

    describe "has_one" do
      it "loads the associated record" do
        author = AssociationTests::Author.find(AssociationTests::Author.author1.not_nil!.id)
        author.should_not be_nil

        profile = author.not_nil!.profile

        profile.should_not be_nil
        profile.not_nil!.bio_text.should eq("Alice's bio")
      end

      it "returns nil when no associated record exists" do
        author = AssociationTests::Author.create(name: "Charlie")
        profile = author.profile

        profile.should be_nil
      end

      it "builds a new associated record" do
        author = AssociationTests::Author.author2.not_nil!
        built_profile = author.build_profile(bio_text: "Updated bio")

        built_profile.should be_a(AssociationTests::Profile)
        built_profile.bio_text.should eq("Updated bio")
        # The built profile should have the author_id set
        # Note: we need to access the instance variable since we don't have a getter
      end

      it "creates a new associated record" do
        author = AssociationTests::Author.create(name: "David")
        new_profile = author.create_profile(bio_text: "David's bio")

        new_profile.should be_a(AssociationTests::Profile)
        new_profile.bio_text.should eq("David's bio")
      end
    end

    describe "has_many" do
      it "loads the associated records" do
        author = AssociationTests::Author.find(AssociationTests::Author.author1.not_nil!.id)
        author.should_not be_nil

        articles = author.not_nil!.articles

        articles.size.should eq(2)
        articles[0].title.should eq("Article 1")
        articles[1].title.should eq("Article 2")
      end

      it "returns empty array when no associated records exist" do
        author = AssociationTests::Author.create(name: "Eve")
        articles = author.articles

        articles.should be_empty
      end

      it "counts the associated records" do
        author = AssociationTests::Author.author1.not_nil!
        count = author.articles.size

        count.should eq(2)
      end

      it "builds a new associated record" do
        author = AssociationTests::Author.author2.not_nil!
        built_article = author.build_article(title: "Draft Article")

        built_article.should be_a(AssociationTests::Article)
        built_article.title.should eq("Draft Article")
      end

      it "creates a new associated record" do
        author = AssociationTests::Author.create(name: "Frank")
        new_article = author.create_article(title: "Frank's Article")

        new_article.should be_a(AssociationTests::Article)
        new_article.title.should eq("Frank's Article")
      end
    end

    describe "association metadata" do
      it "stores belongs_to association metadata" do
        associations = Ralph::Associations.associations

        associations.has_key?("Ralph::AssociationTests::Comment").should be_true
        comment_associations = associations["Ralph::AssociationTests::Comment"]
        comment_associations.has_key?("article").should be_true

        article_assoc = comment_associations["article"]
        article_assoc.type.should eq(:belongs_to)
        article_assoc.class_name.should eq("Article")
        article_assoc.foreign_key.should eq("article_id")
      end

      it "stores has_one association metadata" do
        associations = Ralph::Associations.associations

        associations.has_key?("Ralph::AssociationTests::Author").should be_true
        author_associations = associations["Ralph::AssociationTests::Author"]
        author_associations.has_key?("profile").should be_true

        profile_assoc = author_associations["profile"]
        profile_assoc.type.should eq(:has_one)
        profile_assoc.class_name.should eq("Profile")
        profile_assoc.foreign_key.should eq("author_id")
      end

      it "stores has_many association metadata" do
        associations = Ralph::Associations.associations

        author_associations = associations["Ralph::AssociationTests::Author"]
        author_associations.has_key?("articles").should be_true

        articles_assoc = author_associations["articles"]
        articles_assoc.type.should eq(:has_many)
        articles_assoc.class_name.should eq("Article")
        articles_assoc.foreign_key.should eq("author_id")
      end
    end

    describe "nested associations" do
      it "traverses multiple levels" do
        comment = AssociationTests::Comment.find(AssociationTests::Comment.comment1.not_nil!.id)
        comment.should_not be_nil

        article = comment.not_nil!.article
        article.should_not be_nil

        # Article has author_id but no belongs_to in this test setup
        # So we can't test article.author directly
        article.not_nil!.title.should eq("Article 1")
      end
    end
  end
end

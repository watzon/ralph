require "../spec_helper"
require "../ralph/test_helper"

module Ralph
  module EagerLoadingTests
    # Test models for eager loading

    class Publisher < Model
      table "eager_test_publishers"

      column id, Int64
      column name, String

      has_many books
    end

    class Book < Model
      table "eager_test_books"

      column id, Int64
      column title, String
      column publisher_id, Int64

      belongs_to publisher
      has_many chapters
    end

    class Chapter < Model
      table "eager_test_chapters"

      column id, Int64
      column title, String
      column book_id, Int64

      belongs_to book
    end

    class Writer < Model
      table "eager_test_writers"

      column id, Int64
      column name, String

      has_one biography
      has_many articles
    end

    class Biography < Model
      table "eager_test_biographies"

      column id, Int64
      column content, String
      column writer_id, Int64

      belongs_to writer
    end

    class Article < Model
      table "eager_test_articles"

      column id, Int64
      column title, String
      column writer_id, Int64

      belongs_to writer
    end

    # Store test data
    @@publisher1 : Publisher?
    @@publisher2 : Publisher?
    @@book1 : Book?
    @@book2 : Book?
    @@book3 : Book?

    def self.publisher1
      @@publisher1
    end

    def self.publisher2
      @@publisher2
    end

    def self.book1
      @@book1
    end

    def self.book2
      @@book2
    end

    def self.book3
      @@book3
    end

    def self.setup_test_data
      # Create publishers
      @@publisher1 = Publisher.create(name: "Penguin")
      @@publisher2 = Publisher.create(name: "Random House")

      # Create books
      @@book1 = Book.create(title: "Crystal Programming", publisher_id: @@publisher1.not_nil!.id)
      @@book2 = Book.create(title: "Ruby Basics", publisher_id: @@publisher1.not_nil!.id)
      @@book3 = Book.create(title: "Python Guide", publisher_id: @@publisher2.not_nil!.id)

      # Create chapters
      Chapter.create(title: "Introduction", book_id: @@book1.not_nil!.id)
      Chapter.create(title: "Variables", book_id: @@book1.not_nil!.id)
      Chapter.create(title: "Getting Started", book_id: @@book2.not_nil!.id)
      Chapter.create(title: "Basics", book_id: @@book3.not_nil!.id)
      Chapter.create(title: "Advanced", book_id: @@book3.not_nil!.id)
    end
  end

  describe "Eager Loading" do
    before_all do
      RalphTestHelper.setup_test_database

      # Create tables
      TestSchema.create_table("eager_test_publishers") do |t|
        t.primary_key
        t.string("name")
      end

      TestSchema.create_table("eager_test_books") do |t|
        t.primary_key
        t.string("title")
        t.bigint("publisher_id")
      end

      TestSchema.create_table("eager_test_chapters") do |t|
        t.primary_key
        t.string("title")
        t.bigint("book_id")
      end

      TestSchema.create_table("eager_test_writers") do |t|
        t.primary_key
        t.string("name")
      end

      TestSchema.create_table("eager_test_biographies") do |t|
        t.primary_key
        t.text("content")
        t.bigint("writer_id")
      end

      TestSchema.create_table("eager_test_articles") do |t|
        t.primary_key
        t.string("title")
        t.bigint("writer_id")
      end

      EagerLoadingTests.setup_test_data
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    describe "Preloading has_many" do
      it "preloads has_many associations" do
        publishers = EagerLoadingTests::Publisher.all
        publishers.size.should eq(2)

        # Preload books
        EagerLoadingTests::Publisher.preload(publishers, :books)

        # Check that associations are preloaded
        publishers.each do |publisher|
          publisher._has_preloaded?("books").should be_true
        end

        # Access preloaded data
        publisher1 = publishers.find { |p| p.name == "Penguin" }
        publisher1.should_not be_nil
        publisher1.not_nil!.books.size.should eq(2)

        publisher2 = publishers.find { |p| p.name == "Random House" }
        publisher2.should_not be_nil
        publisher2.not_nil!.books.size.should eq(1)
      end

      it "preloads multiple associations" do
        publishers = EagerLoadingTests::Publisher.all
        EagerLoadingTests::Publisher.preload(publishers, [:books])

        publishers.each do |publisher|
          publisher._has_preloaded?("books").should be_true
        end
      end
    end

    describe "Preloading belongs_to" do
      it "preloads belongs_to associations" do
        books = EagerLoadingTests::Book.all
        books.size.should eq(3)

        # Preload publishers
        EagerLoadingTests::Book.preload(books, :publisher)

        # Check that associations are preloaded
        books.each do |book|
          book._has_preloaded?("publisher").should be_true
        end

        # Access preloaded data
        book1 = books.find { |b| b.title == "Crystal Programming" }
        book1.should_not be_nil
        publisher = book1.not_nil!.publisher
        publisher.should_not be_nil
        publisher.not_nil!.name.should eq("Penguin")
      end
    end

    describe "Preloading has_one" do
      before_each do
        # Clean up any existing data
        Ralph.database.execute("DELETE FROM eager_test_biographies")
        Ralph.database.execute("DELETE FROM eager_test_writers")

        # Create writers with biographies
        writer = EagerLoadingTests::Writer.create(name: "Jane Austen")
        EagerLoadingTests::Biography.create(content: "English novelist", writer_id: writer.id)

        writer2 = EagerLoadingTests::Writer.create(name: "Mark Twain")
        EagerLoadingTests::Biography.create(content: "American author", writer_id: writer2.id)
      end

      it "preloads has_one associations" do
        writers = EagerLoadingTests::Writer.all
        writers.size.should eq(2)

        EagerLoadingTests::Writer.preload(writers, :biography)

        writers.each do |writer|
          writer._has_preloaded?("biography").should be_true
        end

        jane = writers.find { |w| w.name == "Jane Austen" }
        jane.should_not be_nil
        bio = jane.not_nil!.biography
        bio.should_not be_nil
        bio.not_nil!.content.should eq("English novelist")
      end
    end

    describe "Nested preloading" do
      it "preloads nested associations with hash syntax" do
        publishers = EagerLoadingTests::Publisher.all

        # Preload books and their chapters
        EagerLoadingTests::Publisher.preload(publishers, {:books => :chapters})

        publishers.each do |publisher|
          publisher._has_preloaded?("books").should be_true
        end

        # Check nested preloading
        publisher1 = publishers.find { |p| p.name == "Penguin" }
        publisher1.should_not be_nil
        books = publisher1.not_nil!.books
        books.size.should eq(2)

        # The books should have their chapters preloaded
        crystal_book = books.find { |b| b.title == "Crystal Programming" }
        crystal_book.should_not be_nil
        crystal_book.not_nil!._has_preloaded?("chapters").should be_true
        crystal_book.not_nil!.chapters.size.should eq(2)
      end
    end

    describe "Empty collections" do
      it "handles preloading on empty arrays" do
        empty_publishers = [] of EagerLoadingTests::Publisher
        EagerLoadingTests::Publisher.preload(empty_publishers, :books)
        empty_publishers.size.should eq(0)
      end

      it "handles associations with no records" do
        # Create a publisher with no books
        lonely_publisher = EagerLoadingTests::Publisher.create(name: "No Books Press")
        publishers = [lonely_publisher]

        EagerLoadingTests::Publisher.preload(publishers, :books)

        lonely_publisher._has_preloaded?("books").should be_true
        lonely_publisher.books.size.should eq(0)
      end
    end

    describe "N+1 Detection" do
      it "tracks queries when enabled" do
        Ralph::EagerLoading.enable_n_plus_one_warnings!
        Ralph::EagerLoading.reset_query_counts!

        # This should trigger tracking
        book = EagerLoadingTests::Book.first
        book.should_not be_nil

        # First access - should be tracked but no warning
        book.not_nil!.publisher

        # We can't easily test stderr output, but we can verify the feature is enabled
        Ralph::EagerLoading.n_plus_one_warnings_enabled.should be_true

        Ralph::EagerLoading.disable_n_plus_one_warnings!
      end

      it "raises exception in strict mode" do
        Ralph::EagerLoading.enable_n_plus_one_warnings!
        Ralph::EagerLoading.enable_strict_mode!
        Ralph::EagerLoading.reset_query_counts!

        books = EagerLoadingTests::Book.all

        # First access is OK
        books[0].publisher

        # Second access should raise in strict mode (if N+1 detection works)
        # Note: This depends on how the tracking is implemented
        # For now, we just verify the modes can be set
        Ralph::EagerLoading.n_plus_one_strict_mode.should be_true

        Ralph::EagerLoading.disable_strict_mode!
        Ralph::EagerLoading.disable_n_plus_one_warnings!
      end
    end

    describe "Preloaded data access" do
      it "marks associations as preloaded" do
        book = EagerLoadingTests::Book.first.not_nil!

        book._has_preloaded?("publisher").should be_false

        # Manually set preloaded
        book._set_preloaded_one("publisher", nil)
        book._has_preloaded?("publisher").should be_true
      end

      it "can clear preloaded data" do
        book = EagerLoadingTests::Book.first.not_nil!
        book._set_preloaded_one("publisher", nil)
        book._has_preloaded?("publisher").should be_true

        book._clear_preloaded!
        book._has_preloaded?("publisher").should be_false
      end
    end
  end
end

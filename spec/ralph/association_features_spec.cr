require "../spec_helper"
require "../ralph/test_helper"

# =============================================================================
# Phase 3.3: Association Features Tests
# =============================================================================
#
# This file tests the 5 new association features:
# 1. Automatic Foreign Key Management
# 2. Counter Cache
# 3. Touch Option
# 4. Association Scoping
# 5. Through Associations
#

module Ralph
  module AssociationFeaturesTests
    # =========================================================================
    # Test Models for Counter Cache
    # =========================================================================

    class Publisher < Model
      table "af_publishers"

      column id, Int64, primary: true
      column name, String
      column books_count, Int32, default: 0
      column updated_at, Time?

      has_many books
    end

    class Book < Model
      table "af_books"

      column id, Int64, primary: true
      column title, String
      column published, Bool, default: false
      column publisher_id, Int64

      # counter_cache: true automatically generates increment/decrement callbacks
      # touch: true updates parent's updated_at on save
      belongs_to publisher, counter_cache: true, touch: true

      # Touch parent after save (still need this for touch to work with our callback system)
      @[Ralph::Callbacks::AfterSave]
      def touch_publisher_after_save
        _touch_publisher_association!
      end

      # IMPORTANT: setup_validations and setup_callbacks MUST be called AFTER
      # all callback methods are defined, because the macros iterate over
      # @type.methods which only includes methods defined before the macro call.
    end

    # =========================================================================
    # Test Models for Association Scoping
    # =========================================================================

    class Library < Model
      table "af_libraries"

      column id, Int64, primary: true
      column name, String

      # Regular has_many
      has_many magazines

      # Scoped has_many - only published magazines
      has_many published_magazines, ->(q : Ralph::Query::Builder) { q.where("\"published\" = ?", true) }, class_name: "Ralph::AssociationFeaturesTests::Magazine"

      # Scoped has_many - only recent magazines
      has_many recent_magazines, ->(q : Ralph::Query::Builder) { q.where("\"year\" > ?", 2020) }, class_name: "Ralph::AssociationFeaturesTests::Magazine"
    end

    class Magazine < Model
      table "af_magazines"

      column id, Int64, primary: true
      column name, String
      column published, Bool, default: false
      column year, Int32, default: 2024
      column library_id, Int64

      belongs_to library
    end

    # =========================================================================
    # Test Models for Through Associations
    # =========================================================================

    class Student < Model
      table "af_students"

      column id, Int64, primary: true
      column name, String

      has_many enrollments
      has_many courses, through: :enrollments, source: :course
    end

    class Course < Model
      table "af_courses"

      column id, Int64, primary: true
      column title, String

      has_many enrollments
      has_many students, through: :enrollments, source: :student
    end

    class Enrollment < Model
      table "af_enrollments"

      column id, Int64, primary: true
      column grade, String?
      column student_id, Int64
      column course_id, Int64

      belongs_to student
      belongs_to course
    end

    # =========================================================================
    # Test Models for Automatic FK Management
    # =========================================================================

    class Author < Model
      table "af_authors"

      column id, Int64, primary: true
      column name, String

      has_many articles
    end

    class Article < Model
      table "af_articles"

      column id, Int64, primary: true
      column title, String
      column author_id, Int64

      belongs_to author
    end
  end

  # ===========================================================================
  # Test Suite
  # ===========================================================================

  describe "Association Features (Phase 3.3)" do
    before_all do
      RalphTestHelper.setup_test_database

      # Create tables for counter cache tests
      TestSchema.create_table("af_publishers") do |t|
        t.primary_key
        t.string("name")
        t.integer("books_count", default: 0)
        t.timestamp("updated_at")
      end

      TestSchema.create_table("af_books") do |t|
        t.primary_key
        t.string("title")
        t.boolean("published", default: false)
        t.bigint("publisher_id")
      end

      # Create tables for association scoping tests
      TestSchema.create_table("af_libraries") do |t|
        t.primary_key
        t.string("name")
      end

      TestSchema.create_table("af_magazines") do |t|
        t.primary_key
        t.string("name")
        t.boolean("published", default: false)
        t.integer("year", default: 2024)
        t.bigint("library_id")
      end

      # Create tables for through association tests
      TestSchema.create_table("af_students") do |t|
        t.primary_key
        t.string("name")
      end

      TestSchema.create_table("af_courses") do |t|
        t.primary_key
        t.string("title")
      end

      TestSchema.create_table("af_enrollments") do |t|
        t.primary_key
        t.string("grade", size: 10)
        t.bigint("student_id")
        t.bigint("course_id")
      end

      # Create tables for auto FK tests
      TestSchema.create_table("af_authors") do |t|
        t.primary_key
        t.string("name")
      end

      TestSchema.create_table("af_articles") do |t|
        t.primary_key
        t.string("title")
        t.bigint("author_id")
      end
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    # Clear tables before each test group
    before_each do
      Ralph.database.execute("DELETE FROM af_books")
      Ralph.database.execute("DELETE FROM af_publishers")
      Ralph.database.execute("DELETE FROM af_magazines")
      Ralph.database.execute("DELETE FROM af_libraries")
      Ralph.database.execute("DELETE FROM af_enrollments")
      Ralph.database.execute("DELETE FROM af_courses")
      Ralph.database.execute("DELETE FROM af_students")
      Ralph.database.execute("DELETE FROM af_articles")
      Ralph.database.execute("DELETE FROM af_authors")
    end

    # =========================================================================
    # Feature 1: Automatic Foreign Key Management
    # =========================================================================

    describe "Automatic Foreign Key Management" do
      it "auto-sets FK when assigning belongs_to association" do
        author = AssociationFeaturesTests::Author.create(name: "Jane Doe")
        article = AssociationFeaturesTests::Article.new(title: "My Article")

        article.author = author
        article.author_id.should eq author.id
      end

      it "tracks FK changes in dirty tracking" do
        author1 = AssociationFeaturesTests::Author.create(name: "Author 1")
        author2 = AssociationFeaturesTests::Author.create(name: "Author 2")

        article = AssociationFeaturesTests::Article.new(title: "Test Article")
        article.author = author1
        article.save

        # Change the author
        article.author = author2
        article.author_id_changed?.should be_true
      end

      it "clears FK when setting association to nil" do
        author = AssociationFeaturesTests::Author.create(name: "Jane Doe")
        article = AssociationFeaturesTests::Article.new(title: "My Article")

        article.author = author
        article.author_id.should eq author.id

        # Note: This will set FK to nil, which may fail validation
        # depending on the column definition
        article.author = nil
        article.author_id.should be_nil
      end

      it "auto-sets FK when using build_* method on has_many" do
        author = AssociationFeaturesTests::Author.create(name: "John Smith")

        article = author.build_article(title: "Built Article")
        article.author_id.should eq author.id
        article.new_record?.should be_true
      end

      it "auto-sets FK when using create_* method on has_many" do
        author = AssociationFeaturesTests::Author.create(name: "John Smith")

        article = author.create_article(title: "Created Article")
        article.author_id.should eq author.id
        article.persisted?.should be_true
      end
    end

    # =========================================================================
    # Feature 2: Counter Cache
    # =========================================================================

    describe "Counter Cache" do
      it "increments counter on create" do
        publisher = AssociationFeaturesTests::Publisher.create(name: "Penguin")
        publisher.books_count.should eq 0

        AssociationFeaturesTests::Book.create(title: "Book 1", publisher_id: publisher.id.not_nil!)

        # Reload to get updated count
        publisher.reload
        publisher.books_count.should eq 1
      end

      it "increments counter for multiple creates" do
        publisher = AssociationFeaturesTests::Publisher.create(name: "Random House")
        publisher.books_count.should eq 0

        3.times do |i|
          AssociationFeaturesTests::Book.create(title: "Book #{i + 1}", publisher_id: publisher.id.not_nil!)
        end

        publisher.reload
        publisher.books_count.should eq 3
      end

      it "decrements counter on destroy" do
        publisher = AssociationFeaturesTests::Publisher.create(name: "HarperCollins")

        book1 = AssociationFeaturesTests::Book.create(title: "Book 1", publisher_id: publisher.id.not_nil!)
        book2 = AssociationFeaturesTests::Book.create(title: "Book 2", publisher_id: publisher.id.not_nil!)

        publisher.reload
        publisher.books_count.should eq 2

        book1.destroy
        publisher.reload
        publisher.books_count.should eq 1

        book2.destroy
        publisher.reload
        publisher.books_count.should eq 0
      end

      it "does not decrement counter below zero" do
        publisher = AssociationFeaturesTests::Publisher.create(name: "Test Publisher")

        # Manually set counter to 0
        Ralph.database.execute("UPDATE af_publishers SET books_count = 0 WHERE id = ?", args: [publisher.id])

        book = AssociationFeaturesTests::Book.create(title: "Test Book", publisher_id: publisher.id.not_nil!)
        publisher.reload
        publisher.books_count.should eq 1

        # Force counter to 0 again (simulating inconsistency)
        Ralph.database.execute("UPDATE af_publishers SET books_count = 0 WHERE id = ?", args: [publisher.id])

        book.destroy
        publisher.reload
        publisher.books_count.should eq 0 # Should not go negative
      end

      it "provides reset counter method on parent" do
        publisher = AssociationFeaturesTests::Publisher.create(name: "Reset Test")

        # Create books
        3.times { |i| AssociationFeaturesTests::Book.create(title: "Book #{i}", publisher_id: publisher.id.not_nil!) }

        # Manually corrupt the counter
        Ralph.database.execute("UPDATE af_publishers SET books_count = 99 WHERE id = ?", args: [publisher.id])

        publisher.reload
        publisher.books_count.should eq 99

        # Reset the counter using the new generic method
        publisher.reset_counter_cache!("books_count", AssociationFeaturesTests::Book, "publisher_id")
        publisher.books_count.should eq 3
      end
    end

    # =========================================================================
    # Feature 3: Touch Option
    # =========================================================================

    describe "Touch Option" do
      it "updates parent updated_at on save" do
        publisher = AssociationFeaturesTests::Publisher.create(name: "Touchable Publisher")
        original_updated_at = publisher.updated_at

        # Wait a bit to ensure time difference
        sleep 10.milliseconds

        book = AssociationFeaturesTests::Book.create(title: "Touching Book", publisher_id: publisher.id.not_nil!)

        publisher.reload
        # updated_at should have changed
        if original_updated_at
          publisher.updated_at.should_not eq original_updated_at
        else
          publisher.updated_at.should_not be_nil
        end
      end

      it "updates parent updated_at on child update" do
        publisher = AssociationFeaturesTests::Publisher.create(name: "Touch Update Test")
        book = AssociationFeaturesTests::Book.create(title: "Original Title", publisher_id: publisher.id.not_nil!)

        publisher.reload
        original_updated_at = publisher.updated_at

        # Wait a bit
        sleep 10.milliseconds

        # Update the book
        book.title = "Updated Title"
        book.save

        publisher.reload
        if original_updated_at
          publisher.updated_at.should_not eq original_updated_at
        end
      end
    end

    # =========================================================================
    # Feature 4: Association Scoping
    # =========================================================================

    describe "Association Scoping" do
      it "returns all records without scope" do
        library = AssociationFeaturesTests::Library.create(name: "City Library")

        AssociationFeaturesTests::Magazine.create(name: "Mag 1", published: true, year: 2024, library_id: library.id.not_nil!)
        AssociationFeaturesTests::Magazine.create(name: "Mag 2", published: false, year: 2020, library_id: library.id.not_nil!)
        AssociationFeaturesTests::Magazine.create(name: "Mag 3", published: true, year: 2019, library_id: library.id.not_nil!)

        library.magazines.size.should eq 3
      end

      it "filters records with scope" do
        library = AssociationFeaturesTests::Library.create(name: "Scoped Library")

        AssociationFeaturesTests::Magazine.create(name: "Published Mag", published: true, year: 2024, library_id: library.id.not_nil!)
        AssociationFeaturesTests::Magazine.create(name: "Draft Mag", published: false, year: 2024, library_id: library.id.not_nil!)
        AssociationFeaturesTests::Magazine.create(name: "Old Published", published: true, year: 2019, library_id: library.id.not_nil!)

        # published_magazines should only return published ones
        library.published_magazines.size.should eq 2
        library.published_magazines.all? { |m| m.published == true }.should be_true
      end

      it "applies multiple scopes independently" do
        library = AssociationFeaturesTests::Library.create(name: "Multi-Scope Library")

        AssociationFeaturesTests::Magazine.create(name: "New Published", published: true, year: 2024, library_id: library.id.not_nil!)
        AssociationFeaturesTests::Magazine.create(name: "New Draft", published: false, year: 2024, library_id: library.id.not_nil!)
        AssociationFeaturesTests::Magazine.create(name: "Old Published", published: true, year: 2019, library_id: library.id.not_nil!)
        AssociationFeaturesTests::Magazine.create(name: "Old Draft", published: false, year: 2018, library_id: library.id.not_nil!)

        library.magazines.size.should eq 4
        library.published_magazines.size.should eq 2
        library.recent_magazines.size.should eq 2 # year > 2020
      end

      it "provides unscoped method to bypass scope" do
        library = AssociationFeaturesTests::Library.create(name: "Unscoped Test")

        AssociationFeaturesTests::Magazine.create(name: "Published", published: true, year: 2024, library_id: library.id.not_nil!)
        AssociationFeaturesTests::Magazine.create(name: "Draft", published: false, year: 2024, library_id: library.id.not_nil!)

        library.published_magazines.size.should eq 1
        library.published_magazines_unscoped.size.should eq 2
      end

      it "applies scope to count method" do
        library = AssociationFeaturesTests::Library.create(name: "Count Test")

        3.times { |i| AssociationFeaturesTests::Magazine.create(name: "Pub #{i}", published: true, year: 2024, library_id: library.id.not_nil!) }
        2.times { |i| AssociationFeaturesTests::Magazine.create(name: "Draft #{i}", published: false, year: 2024, library_id: library.id.not_nil!) }

        library.magazines.size.should eq 5
        library.published_magazines.size.should eq 3
      end
    end

    # =========================================================================
    # Feature 5: Through Associations
    # =========================================================================

    describe "Through Associations" do
      it "retrieves associated records through intermediate model" do
        student = AssociationFeaturesTests::Student.create(name: "Alice")
        course1 = AssociationFeaturesTests::Course.create(title: "Math 101")
        course2 = AssociationFeaturesTests::Course.create(title: "Physics 101")

        # Create enrollments
        AssociationFeaturesTests::Enrollment.create(
          student_id: student.id.not_nil!,
          course_id: course1.id.not_nil!,
          grade: "A"
        )
        AssociationFeaturesTests::Enrollment.create(
          student_id: student.id.not_nil!,
          course_id: course2.id.not_nil!,
          grade: "B"
        )

        # Student should have 2 courses through enrollments
        student.courses.size.should eq 2
        student.courses.map(&.title).should contain "Math 101"
        student.courses.map(&.title).should contain "Physics 101"
      end

      it "retrieves from the other direction" do
        student1 = AssociationFeaturesTests::Student.create(name: "Bob")
        student2 = AssociationFeaturesTests::Student.create(name: "Charlie")
        course = AssociationFeaturesTests::Course.create(title: "History 101")

        # Enroll both students in the course
        AssociationFeaturesTests::Enrollment.create(
          student_id: student1.id.not_nil!,
          course_id: course.id.not_nil!,
          grade: "A"
        )
        AssociationFeaturesTests::Enrollment.create(
          student_id: student2.id.not_nil!,
          course_id: course.id.not_nil!,
          grade: "B"
        )

        # Course should have 2 students through enrollments
        course.students.size.should eq 2
        course.students.map(&.name).should contain "Bob"
        course.students.map(&.name).should contain "Charlie"
      end

      it "returns empty array when no through records exist" do
        student = AssociationFeaturesTests::Student.create(name: "Lonely Student")
        student.courses.size.should eq 0
        student.courses.should be_empty
      end

      it "provides intermediate association access" do
        student = AssociationFeaturesTests::Student.create(name: "Dana")
        course = AssociationFeaturesTests::Course.create(title: "Chemistry 101")

        enrollment = AssociationFeaturesTests::Enrollment.create(
          student_id: student.id.not_nil!,
          course_id: course.id.not_nil!,
          grade: "A+"
        )

        # Can access enrollments directly
        student.enrollments.size.should eq 1
        student.enrollments.first.grade.should eq "A+"

        # And through to courses
        student.courses.size.should eq 1
        student.courses.first.title.should eq "Chemistry 101"
      end

      it "handles count correctly for through associations" do
        student = AssociationFeaturesTests::Student.create(name: "Eve")

        3.times do |i|
          course = AssociationFeaturesTests::Course.create(title: "Course #{i}")
          AssociationFeaturesTests::Enrollment.create(
            student_id: student.id.not_nil!,
            course_id: course.id.not_nil!
          )
        end

        student.courses.size.should eq 3
      end
    end
  end
end

require "../spec_helper"
require "../ralph/test_helper"

module Ralph
  module AssociationOptionsTests
    # ========================================
    # Models for class_name option tests
    # ========================================

    class Person < Model
      table "assoc_opts_persons"

      column id, Int64
      column name, String

      # Use class_name to reference a differently-named model
      has_many written_articles, class_name: "BlogPost", foreign_key: "author_id"
      has_one avatar, class_name: "UserImage", foreign_key: "owner_id"

      setup_validations
      setup_callbacks
    end

    class BlogPost < Model
      table "assoc_opts_blog_posts"

      column id, Int64
      column title, String
      column author_id, Int64?

      # Use class_name to reference Person as "writer"
      belongs_to writer, class_name: "Person", foreign_key: "author_id"

      setup_validations
      setup_callbacks
    end

    class UserImage < Model
      table "assoc_opts_user_images"

      column id, Int64
      column url, String
      column owner_id, Int64?

      setup_validations
      setup_callbacks
    end

    # ========================================
    # Models for foreign_key option tests
    # ========================================

    class Company < Model
      table "assoc_opts_companies"

      column id, Int64
      column name, String

      # Custom foreign key on the employees table
      has_many workers, class_name: "Employee", foreign_key: "employer_id"

      setup_validations
      setup_callbacks
    end

    class Employee < Model
      table "assoc_opts_employees"

      column id, Int64
      column name, String
      column employer_id, Int64?

      # Custom foreign_key to match company's has_many
      belongs_to employer, class_name: "Company", foreign_key: "employer_id"

      setup_validations
      setup_callbacks
    end

    # ========================================
    # Models for dependent option tests
    # ========================================

    class Publisher < Model
      table "assoc_opts_publishers"

      column id, Int64
      column name, String

      # dependent: :destroy - runs callbacks on each book
      has_many books, dependent: :destroy

      setup_validations
      setup_callbacks
    end

    class Book < Model
      table "assoc_opts_books"

      column id, Int64
      column title, String
      column publisher_id, Int64?

      @@destroyed_titles = [] of String

      def self.destroyed_titles
        @@destroyed_titles
      end

      def self.clear_destroyed_titles
        @@destroyed_titles.clear
      end

      @[AfterDestroy]
      def track_destruction
        @@destroyed_titles << title.to_s if title
      end

      setup_validations
      setup_callbacks
    end

    class Library < Model
      table "assoc_opts_libraries"

      column id, Int64
      column name, String

      # dependent: :delete_all - deletes without callbacks
      has_many magazines, dependent: :delete_all

      setup_validations
      setup_callbacks
    end

    class Magazine < Model
      table "assoc_opts_magazines"

      column id, Int64
      column title, String
      column library_id, Int64?

      @@destroyed_titles = [] of String

      def self.destroyed_titles
        @@destroyed_titles
      end

      def self.clear_destroyed_titles
        @@destroyed_titles.clear
      end

      @[AfterDestroy]
      def track_destruction
        @@destroyed_titles << title.to_s if title
      end

      setup_validations
      setup_callbacks
    end

    class Author < Model
      table "assoc_opts_authors"

      column id, Int64
      column name, String

      # dependent: :nullify - sets foreign key to NULL
      has_many essays, dependent: :nullify

      setup_validations
      setup_callbacks
    end

    class Essay < Model
      table "assoc_opts_essays"

      column id, Int64
      column title, String
      column author_id, Int64?

      setup_validations
      setup_callbacks
    end

    class RestrictedPublisher < Model
      table "assoc_opts_restricted_publishers"

      column id, Int64
      column name, String

      # dependent: :restrict_with_error - prevents destroy if associations exist
      has_many documents, class_name: "Document", foreign_key: "restricted_publisher_id", dependent: :restrict_with_error

      setup_validations
      setup_callbacks
    end

    class Document < Model
      table "assoc_opts_documents"

      column id, Int64
      column title, String
      column restricted_publisher_id, Int64?

      setup_validations
      setup_callbacks
    end

    class StrictPublisher < Model
      table "assoc_opts_strict_publishers"

      column id, Int64
      column name, String

      # dependent: :restrict_with_exception - raises exception if associations exist
      has_many papers, class_name: "Paper", foreign_key: "strict_publisher_id", dependent: :restrict_with_exception

      setup_validations
      setup_callbacks
    end

    class Paper < Model
      table "assoc_opts_papers"

      column id, Int64
      column title, String
      column strict_publisher_id, Int64?

      setup_validations
      setup_callbacks
    end

    # ========================================
    # Models for has_one dependent tests
    # ========================================

    class User < Model
      table "assoc_opts_users"

      column id, Int64
      column name, String

      # dependent: :destroy for has_one
      has_one profile, dependent: :destroy

      setup_validations
      setup_callbacks
    end

    class Profile < Model
      table "assoc_opts_profiles"

      column id, Int64
      column bio, String
      column user_id, Int64?

      @@destroyed_bios = [] of String

      def self.destroyed_bios
        @@destroyed_bios
      end

      def self.clear_destroyed_bios
        @@destroyed_bios.clear
      end

      @[AfterDestroy]
      def track_destruction
        @@destroyed_bios << bio.to_s if bio
      end

      setup_validations
      setup_callbacks
    end

    class Account < Model
      table "assoc_opts_accounts"

      column id, Int64
      column name, String

      # dependent: :nullify for has_one
      has_one settings, class_name: "AccountSettings", foreign_key: "account_id", dependent: :nullify

      setup_validations
      setup_callbacks
    end

    class AccountSettings < Model
      table "assoc_opts_account_settings"

      column id, Int64
      column theme, String
      column account_id, Int64?

      setup_validations
      setup_callbacks
    end
  end

  describe "Association Options" do
    before_all do
      RalphTestHelper.setup_test_database

      # Create tables for class_name tests
      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_persons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(255) NOT NULL
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_blog_posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title VARCHAR(255) NOT NULL,
        author_id INTEGER
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_user_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url VARCHAR(255) NOT NULL,
        owner_id INTEGER
      )
      SQL

      # Create tables for foreign_key tests
      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_companies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(255) NOT NULL
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(255) NOT NULL,
        employer_id INTEGER
      )
      SQL

      # Create tables for dependent tests
      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_publishers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(255) NOT NULL
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title VARCHAR(255) NOT NULL,
        publisher_id INTEGER
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_libraries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(255) NOT NULL
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_magazines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title VARCHAR(255) NOT NULL,
        library_id INTEGER
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_authors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(255) NOT NULL
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_essays (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title VARCHAR(255) NOT NULL,
        author_id INTEGER
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_restricted_publishers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(255) NOT NULL
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title VARCHAR(255) NOT NULL,
        restricted_publisher_id INTEGER
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_strict_publishers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(255) NOT NULL
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_papers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title VARCHAR(255) NOT NULL,
        strict_publisher_id INTEGER
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(255) NOT NULL
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bio VARCHAR(500),
        user_id INTEGER
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(255) NOT NULL
      )
      SQL

      Ralph.database.execute <<-SQL
      CREATE TABLE IF NOT EXISTS assoc_opts_account_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        theme VARCHAR(255),
        account_id INTEGER
      )
      SQL
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    describe "class_name option" do
      describe "belongs_to" do
        it "uses custom class name for association" do
          person = AssociationOptionsTests::Person.create(name: "Alice")
          post = AssociationOptionsTests::BlogPost.create(title: "My Post", author_id: person.id)

          # writer should return a Person, not a Writer class
          writer = post.writer
          writer.should_not be_nil
          writer.not_nil!.should be_a(AssociationOptionsTests::Person)
          writer.not_nil!.name.should eq("Alice")
        end
      end

      describe "has_many" do
        it "uses custom class name for association" do
          person = AssociationOptionsTests::Person.create(name: "Bob")
          post1 = AssociationOptionsTests::BlogPost.create(title: "Post 1", author_id: person.id)
          post2 = AssociationOptionsTests::BlogPost.create(title: "Post 2", author_id: person.id)

          # written_articles should return BlogPost objects
          articles = person.written_articles
          articles.size.should eq(2)
          articles[0].should be_a(AssociationOptionsTests::BlogPost)
        end
      end

      describe "has_one" do
        it "uses custom class name for association" do
          person = AssociationOptionsTests::Person.create(name: "Charlie")
          image = AssociationOptionsTests::UserImage.create(url: "avatar.jpg", owner_id: person.id)

          # avatar should return a UserImage, not an Avatar class
          avatar = person.avatar
          avatar.should_not be_nil
          avatar.not_nil!.should be_a(AssociationOptionsTests::UserImage)
          avatar.not_nil!.url.should eq("avatar.jpg")
        end
      end
    end

    describe "foreign_key option" do
      it "uses custom foreign key for belongs_to" do
        company = AssociationOptionsTests::Company.create(name: "Acme Corp")
        employee = AssociationOptionsTests::Employee.create(name: "John", employer_id: company.id)

        # Should use employer_id as the foreign key
        employer = employee.employer
        employer.should_not be_nil
        employer.not_nil!.name.should eq("Acme Corp")
      end

      it "uses custom foreign key for has_many" do
        company = AssociationOptionsTests::Company.create(name: "Tech Inc")
        emp1 = AssociationOptionsTests::Employee.create(name: "Jane", employer_id: company.id)
        emp2 = AssociationOptionsTests::Employee.create(name: "Jim", employer_id: company.id)

        # Should use employer_id as the foreign key
        workers = company.workers
        workers.size.should eq(2)
      end
    end

    describe "dependent option" do
      describe "has_many dependent: :destroy" do
        it "destroys associated records with callbacks" do
          AssociationOptionsTests::Book.clear_destroyed_titles

          publisher = AssociationOptionsTests::Publisher.create(name: "Big Publisher")
          book1 = AssociationOptionsTests::Book.create(title: "Book One", publisher_id: publisher.id)
          book2 = AssociationOptionsTests::Book.create(title: "Book Two", publisher_id: publisher.id)

          # Verify books exist
          publisher.books.size.should eq(2)

          # Destroy publisher - should destroy books with callbacks
          publisher.destroy

          # Books should be destroyed
          AssociationOptionsTests::Book.find(book1.id).should be_nil
          AssociationOptionsTests::Book.find(book2.id).should be_nil

          # Callbacks should have been called
          AssociationOptionsTests::Book.destroyed_titles.should contain("Book One")
          AssociationOptionsTests::Book.destroyed_titles.should contain("Book Two")
        end
      end

      describe "has_many dependent: :delete_all" do
        it "deletes associated records without callbacks" do
          AssociationOptionsTests::Magazine.clear_destroyed_titles

          library = AssociationOptionsTests::Library.create(name: "City Library")
          mag1 = AssociationOptionsTests::Magazine.create(title: "Mag One", library_id: library.id)
          mag2 = AssociationOptionsTests::Magazine.create(title: "Mag Two", library_id: library.id)

          # Verify magazines exist
          library.magazines.size.should eq(2)

          # Destroy library - should delete magazines WITHOUT callbacks
          library.destroy

          # Magazines should be deleted
          AssociationOptionsTests::Magazine.find(mag1.id).should be_nil
          AssociationOptionsTests::Magazine.find(mag2.id).should be_nil

          # Callbacks should NOT have been called (delete_all skips callbacks)
          AssociationOptionsTests::Magazine.destroyed_titles.should be_empty
        end
      end

      describe "has_many dependent: :nullify" do
        it "sets foreign key to NULL on associated records" do
          author = AssociationOptionsTests::Author.create(name: "Essay Writer")
          essay1 = AssociationOptionsTests::Essay.create(title: "Essay One", author_id: author.id)
          essay2 = AssociationOptionsTests::Essay.create(title: "Essay Two", author_id: author.id)

          # Verify essays are associated
          author.essays.size.should eq(2)

          # Destroy author - should nullify essay foreign keys
          author.destroy

          # Essays should still exist but with NULL author_id
          reloaded1 = AssociationOptionsTests::Essay.find(essay1.id)
          reloaded2 = AssociationOptionsTests::Essay.find(essay2.id)

          reloaded1.should_not be_nil
          reloaded2.should_not be_nil
          reloaded1.not_nil!.author_id.should be_nil
          reloaded2.not_nil!.author_id.should be_nil
        end
      end

      describe "has_many dependent: :restrict_with_error" do
        it "prevents destroy and adds error if associations exist" do
          publisher = AssociationOptionsTests::RestrictedPublisher.create(name: "Restricted Pub")
          doc = AssociationOptionsTests::Document.create(title: "Important Doc", restricted_publisher_id: publisher.id)

          # Try to destroy - should fail
          result = publisher.destroy
          result.should be_false

          # Publisher should still exist
          AssociationOptionsTests::RestrictedPublisher.find(publisher.id).should_not be_nil

          # Error should be present
          publisher.errors.empty?.should be_false
        end

        it "allows destroy if no associations exist" do
          publisher = AssociationOptionsTests::RestrictedPublisher.create(name: "Empty Pub")

          # No documents associated
          publisher.documents.size.should eq(0)

          # Should be able to destroy
          result = publisher.destroy
          result.should be_true

          AssociationOptionsTests::RestrictedPublisher.find(publisher.id).should be_nil
        end
      end

      describe "has_many dependent: :restrict_with_exception" do
        it "raises exception if associations exist" do
          publisher = AssociationOptionsTests::StrictPublisher.create(name: "Strict Pub")
          paper = AssociationOptionsTests::Paper.create(title: "Scientific Paper", strict_publisher_id: publisher.id)

          # Try to destroy - should raise
          expect_raises(Ralph::DeleteRestrictionError) do
            publisher.destroy
          end

          # Publisher should still exist
          AssociationOptionsTests::StrictPublisher.find(publisher.id).should_not be_nil
        end

        it "allows destroy if no associations exist" do
          publisher = AssociationOptionsTests::StrictPublisher.create(name: "Empty Strict Pub")

          # No papers associated
          publisher.papers.size.should eq(0)

          # Should be able to destroy without exception
          result = publisher.destroy
          result.should be_true

          AssociationOptionsTests::StrictPublisher.find(publisher.id).should be_nil
        end
      end

      describe "has_one dependent: :destroy" do
        it "destroys associated record with callbacks" do
          AssociationOptionsTests::Profile.clear_destroyed_bios

          user = AssociationOptionsTests::User.create(name: "Test User")
          profile = AssociationOptionsTests::Profile.create(bio: "My bio", user_id: user.id)

          # Verify profile exists
          user.profile.should_not be_nil

          # Destroy user - should destroy profile with callbacks
          user.destroy

          # Profile should be destroyed
          AssociationOptionsTests::Profile.find(profile.id).should be_nil

          # Callback should have been called
          AssociationOptionsTests::Profile.destroyed_bios.should contain("My bio")
        end
      end

      describe "has_one dependent: :nullify" do
        it "sets foreign key to NULL on associated record" do
          account = AssociationOptionsTests::Account.create(name: "Test Account")
          settings = AssociationOptionsTests::AccountSettings.create(theme: "dark", account_id: account.id)

          # Verify settings are associated
          account.settings.should_not be_nil

          # Destroy account - should nullify settings foreign key
          account.destroy

          # Settings should still exist but with NULL account_id
          reloaded = AssociationOptionsTests::AccountSettings.find(settings.id)
          reloaded.should_not be_nil
          reloaded.not_nil!.account_id.should be_nil
        end
      end
    end

    describe "association metadata" do
      it "stores class_name override flag" do
        associations = Ralph::Associations.associations
        person_assocs = associations["Ralph::AssociationOptionsTests::Person"]?
        person_assocs.should_not be_nil

        # written_articles has class_name override
        articles_meta = person_assocs.not_nil!["written_articles"]?
        articles_meta.should_not be_nil
        articles_meta.not_nil!.class_name_override.should be_true
        articles_meta.not_nil!.class_name.should eq("BlogPost")
      end

      it "stores foreign_key override flag" do
        associations = Ralph::Associations.associations
        person_assocs = associations["Ralph::AssociationOptionsTests::Person"]?
        person_assocs.should_not be_nil

        # written_articles has foreign_key override
        articles_meta = person_assocs.not_nil!["written_articles"]?
        articles_meta.should_not be_nil
        articles_meta.not_nil!.foreign_key_override.should be_true
        articles_meta.not_nil!.foreign_key.should eq("author_id")
      end

      it "stores dependent behavior" do
        associations = Ralph::Associations.associations

        # Publisher has dependent: :destroy
        publisher_assocs = associations["Ralph::AssociationOptionsTests::Publisher"]?
        publisher_assocs.should_not be_nil
        books_meta = publisher_assocs.not_nil!["books"]?
        books_meta.should_not be_nil
        books_meta.not_nil!.dependent.should eq(Ralph::DependentBehavior::Destroy)

        # Library has dependent: :delete_all
        library_assocs = associations["Ralph::AssociationOptionsTests::Library"]?
        library_assocs.should_not be_nil
        mags_meta = library_assocs.not_nil!["magazines"]?
        mags_meta.should_not be_nil
        mags_meta.not_nil!.dependent.should eq(Ralph::DependentBehavior::Delete)
      end
    end
  end
end

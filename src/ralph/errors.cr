# Ralph Error Hierarchy
#
# All Ralph exceptions inherit from `Ralph::Error` for easy rescue.
#
# ## Exception Hierarchy
#
# ```
# Exception
# └── Ralph::Error                       # Base class for all Ralph errors
# ├── Ralph::ConfigurationError          # Configuration/setup issues
# ├── Ralph::BackendError                # Backend-specific feature on wrong backend
# ├── Ralph::QueryError                  # Query building/execution errors
# ├── Ralph::MigrationError              # Migration execution errors
# │ └── Ralph::UnsupportedOperationError # Operation not supported by backend
# ├── Ralph::RecordNotFound              # find!() with no results
# ├── Ralph::RecordInvalid               # save!() with validation errors
# └── Ralph::DeleteRestrictionError      # dependent: :restrict_with_exception
# ```
#
# ## Example
#
# ```
# begin
#   User.find!(999)
# rescue Ralph::RecordNotFound
#   puts "User not found"
# rescue Ralph::Error => e
#   puts "Ralph error: #{e.message}"
# end
# ```
module Ralph
  # Base class for all Ralph errors
  #
  # Rescue this to catch any Ralph-specific exception.
  class Error < Exception
  end

  # Raised when Ralph is not properly configured
  #
  # ## Common Causes
  #
  # - Accessing database before calling `Ralph.configure`
  # - Invalid database URL
  # - Missing database driver
  class ConfigurationError < Error
  end

  # Raised when using a backend-specific feature on an unsupported backend
  #
  # ## Example
  #
  # ```
  # # Using SQLite backend
  # User.query { |q| q.where_search("name", "john") }
  # # => Ralph::BackendError: Full-text search is only available on PostgreSQL backend
  # ```
  class BackendError < Error
  end

  # Raised when a query cannot be built or executed
  class QueryError < Error
    getter sql : String?
    getter args : Array(DB::Any)?

    def initialize(message : String, @sql : String? = nil, @args : Array(DB::Any)? = nil, cause : Exception? = nil)
      full_message = String.build do |str|
        str << message
        if sql = @sql
          str << "\n\nSQL:\n  " << sql
        end
        if args = @args
          str << "\n\nParameters:\n  " << args.inspect
        end
        if cause
          str << "\n\nCaused by:\n  " << cause.class.name << ": " << cause.message
        end
      end
      super(full_message, cause)
    end
  end

  # Raised when a migration fails to execute
  #
  # Wraps the underlying database error with context about what operation
  # was being attempted and helpful suggestions for resolution.
  class MigrationError < Error
    getter operation : String
    getter table : String?
    getter sql : String?
    getter backend : Symbol?

    def initialize(
      message : String,
      @operation : String,
      @table : String? = nil,
      @sql : String? = nil,
      @backend : Symbol? = nil,
      cause : Exception? = nil,
    )
      full_message = String.build do |str|
        str << "Migration failed: " << message
        str << "\n\nOperation: " << @operation
        str << " on table '#{@table}'" if @table
        str << "\nBackend: " << @backend.to_s if @backend

        if sql = @sql
          str << "\n\nSQL:\n  " << sql
        end

        if cause
          str << "\n\nDatabase error:\n  " << cause.message
        end

        # Add helpful suggestions based on the error
        if suggestion = suggest_fix(message, cause)
          str << "\n\n" << suggestion
        end
      end
      super(full_message, cause)
    end

    private def suggest_fix(message : String, cause : Exception?) : String?
      cause_msg = cause.try(&.message) || ""

      # SQLite CONSTRAINT errors often mean ALTER TABLE limitations
      if @backend == :sqlite && cause_msg.includes?("CONSTRAINT")
        return <<-HINT
        Hint: SQLite does not support adding constraints via ALTER TABLE.
        
        For foreign keys, define them inline when creating the table:
        
          create_table "posts" do |t|
            t.primary_key
            t.string "user_id"
            t.foreign_key "users", column: "user_id", on_delete: :cascade
          end
        
        Instead of:
        
          create_table "posts" do |t|
            t.primary_key
            t.string "user_id"
          end
          add_foreign_key "posts", "users"  # This won't work in SQLite!
        HINT
      end

      # SQLite doesn't support DROP COLUMN in older versions
      if @backend == :sqlite && (cause_msg.includes?("DROP COLUMN") || cause_msg.includes?("no such column"))
        return <<-HINT
        Hint: SQLite has limited ALTER TABLE support.
        
        To remove a column, you may need to:
        1. Create a new table without the column
        2. Copy data from the old table
        3. Drop the old table
        4. Rename the new table
        
        Consider using `execute` with raw SQL for complex schema changes.
        HINT
      end

      # Type mismatch
      if cause_msg.includes?("datatype mismatch") || cause_msg.includes?("type mismatch")
        return <<-HINT
        Hint: The data type doesn't match the column type.
        
        Check that:
        - Default values match the column type
        - Migration data is properly cast
        HINT
      end

      # Table already exists
      if cause_msg.includes?("already exists")
        return <<-HINT
        Hint: The table already exists.
        
        Use `create_table ... do |t|` which generates `CREATE TABLE IF NOT EXISTS`,
        or check if the migration has already been run with `ralph db:status`.
        HINT
      end

      # Table doesn't exist
      if cause_msg.includes?("no such table") || cause_msg.includes?("does not exist")
        return <<-HINT
        Hint: The table doesn't exist.
        
        Check that:
        - The table was created in a previous migration
        - Migrations are running in the correct order
        - The table name is spelled correctly
        HINT
      end

      nil
    end
  end

  # Raised when an operation is not supported by the current backend
  #
  # This is a specialized `MigrationError` for operations that are fundamentally
  # incompatible with certain databases (e.g., SQLite's ALTER TABLE limitations).
  class UnsupportedOperationError < MigrationError
    def initialize(operation : String, backend : Symbol, alternative : String? = nil)
      message = "#{operation} is not supported by #{backend}"

      full_message = String.build do |str|
        str << message
        if alt = alternative
          str << "\n\nAlternative: " << alt
        end
      end

      super(full_message, operation, backend: backend)
    end
  end

  # Raised when `find!` or `first!` returns no results
  #
  # ## Example
  #
  # ```
  # User.find!(999) # => Ralph::RecordNotFound: User with id=999 not found
  # ```
  class RecordNotFound < Error
    getter model : String
    getter id : String?
    getter conditions : String?

    def initialize(@model : String, @id : String? = nil, @conditions : String? = nil)
      message = String.build do |str|
        str << @model
        if id = @id
          str << " with id=" << id
        elsif conditions = @conditions
          str << " with " << conditions
        end
        str << " not found"
      end
      super(message)
    end
  end

  # Raised when `save!` or `create!` fails due to validation errors
  #
  # ## Example
  #
  # ```
  # user = User.new(name: "")
  # user.save! # => Ralph::RecordInvalid: Validation failed: name can't be blank
  # ```
  class RecordInvalid < Error
    getter errors : Array(String)

    def initialize(@errors : Array(String))
      message = "Validation failed: #{@errors.join(", ")}"
      super(message)
    end

    def initialize(errors_object)
      @errors = errors_object.full_messages
      message = "Validation failed: #{@errors.join(", ")}"
      super(message)
    end
  end

  # Raised when trying to destroy a record with `dependent: :restrict_with_exception`
  #
  # ## Example
  #
  # ```
  # class User < Ralph::Model
  #   has_many :posts, dependent: :restrict_with_exception
  # end
  #
  # user.destroy # => Ralph::DeleteRestrictionError: Cannot delete User because posts exist
  # ```
  class DeleteRestrictionError < Error
    def initialize(association : String)
      super("Cannot delete record because #{association} exist")
    end
  end

  # Raised when model columns don't match database schema
  #
  # This error indicates that the model definition has columns that don't exist
  # in the database, or the database has columns not defined in the model.
  # This commonly causes cryptic "column type mismatch" errors at runtime.
  #
  # ## Example
  #
  # ```
  # # Call at startup to catch mismatches early:
  # Supply.validate_schema!
  # # => Ralph::SchemaMismatchError: Schema mismatch for Supply (table: supplies):
  # #      Model has columns not in database: catalog_supply_id
  # #      This will cause column type mismatch errors when reading records.
  # ```
  class SchemaMismatchError < Error
  end
end

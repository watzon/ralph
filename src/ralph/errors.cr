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

  # Raised when model columns don't match the ResultSet columns during hydration
  #
  # This error catches mismatches between what a model expects and what the
  # database actually returns. Common causes:
  # - Model is missing columns that exist in the database
  # - Model has extra columns not in the database
  # - Column order mismatch (when using SELECT * or wrong column order)
  # - Schema drift after database migrations
  #
  # ## Example
  #
  # ```
  # # When loading a Supply record with mismatched schema:
  # Supply.find(id)
  # # => Ralph::SchemaMismatchError: ResultSet mismatch for Supply (table: supplies)
  # #
  # #    Expected 16 columns, got 18 from database
  # #
  # #    Missing in model (add these columns):
  # #      - catalog_supply_id
  # #      - tenant_catalog_supply_id
  # #
  # #    First mismatch at index 0:
  # #      Expected: id
  # #      Got: created_at
  # #
  # #    Hint: Run `ralph db:pull` to regenerate your model from the database schema,
  # #    or manually add the missing columns to your model definition.
  # ```
  class SchemaMismatchError < Error
    getter model_name : String
    getter table_name : String
    getter expected_columns : Array(String)
    getter actual_columns : Array(String)

    def initialize(
      @model_name : String,
      @table_name : String,
      @expected_columns : Array(String),
      @actual_columns : Array(String),
    )
      super(build_message)
    end

    private def build_message : String
      String.build do |str|
        str << "ResultSet mismatch for " << @model_name << " (table: " << @table_name << ")\n\n"

        # Count mismatch
        if @expected_columns.size != @actual_columns.size
          str << "Expected " << @expected_columns.size << " columns, got " << @actual_columns.size << " from database\n\n"
        end

        # Find missing columns (in DB but not in model)
        missing_in_model = @actual_columns - @expected_columns
        if missing_in_model.any?
          str << "Missing in model (add these columns):\n"
          missing_in_model.each do |col|
            str << "  - " << col << "\n"
          end
          str << "\n"
        end

        # Find extra columns (in model but not in DB)
        extra_in_model = @expected_columns - @actual_columns
        if extra_in_model.any?
          str << "Extra in model (remove these columns or add to database):\n"
          extra_in_model.each do |col|
            str << "  - " << col << "\n"
          end
          str << "\n"
        end

        # Find first positional mismatch
        first_mismatch_idx = find_first_mismatch
        if first_mismatch_idx && first_mismatch_idx < @expected_columns.size && first_mismatch_idx < @actual_columns.size
          str << "First mismatch at index " << first_mismatch_idx << ":\n"
          str << "  Expected: " << @expected_columns[first_mismatch_idx] << "\n"
          str << "  Got: " << @actual_columns[first_mismatch_idx] << "\n\n"
        end

        # Helpful hints
        str << "To fix this:\n"
        str << "  1. Manually update your model's column definitions to match the database\n"
        str << "  2. Or run `ralph db:pull --overwrite` to regenerate (WARNING: loses custom code)"
      end
    end

    private def find_first_mismatch : Int32?
      max_len = Math.min(@expected_columns.size, @actual_columns.size)
      max_len.times do |i|
        return i if @expected_columns[i] != @actual_columns[i]
      end
      # If lengths differ but all common elements match, mismatch is at the shorter length
      return max_len if @expected_columns.size != @actual_columns.size
      nil
    end

    # Get a summary suitable for logging
    def summary : String
      missing = (@actual_columns - @expected_columns).size
      extra = (@expected_columns - @actual_columns).size
      "#{@model_name}: expected #{@expected_columns.size} columns, got #{@actual_columns.size} (#{missing} missing, #{extra} extra)"
    end
  end

  # Raised when a column type from the database doesn't match the model's expected type
  #
  # This wraps `DB::ColumnTypeMismatchError` with additional context about which
  # model column was being read and helpful hints for fixing the type mismatch.
  #
  # ## Example
  #
  # ```
  # Supply.find(id)
  # # => Ralph::TypeMismatchError: Type mismatch reading Supply#stock_quantity
  # #
  # #    Column: stock_quantity (index 6)
  # #    Expected type: Float64 | PG::Numeric | Nil
  # #    Actual type: Float32
  # #
  # #    Hint: PostgreSQL 'real' type maps to Float32 in Crystal.
  # #    Change your model column from `Float64` to `Float32`:
  # #
  # #      column stock_quantity : Float32
  # #
  # #    Or change your database column to 'double precision' or 'numeric'.
  # ```
  class TypeMismatchError < Error
    getter model_name : String
    getter column_name : String
    getter column_index : Int32
    getter expected_type : String
    getter actual_type : String
    getter resultset_column_name : String?

    # Common PostgreSQL type to Crystal type mappings for hints
    TYPE_HINTS = {
      "Float32" => {
        "db_types"    => ["real", "float4"],
        "crystal"     => "Float32",
        "alternative" => "double precision or numeric",
      },
      "Float64" => {
        "db_types"    => ["double precision", "float8"],
        "crystal"     => "Float64",
        "alternative" => "real (but loses precision)",
      },
      "PG::Numeric" => {
        "db_types"    => ["numeric", "decimal"],
        "crystal"     => "Float64 (or PG::Numeric for exact precision)",
        "alternative" => "double precision (but loses exact precision)",
      },
      "Int32" => {
        "db_types"    => ["integer", "int4", "serial"],
        "crystal"     => "Int32",
        "alternative" => "bigint for larger values",
      },
      "Int64" => {
        "db_types"    => ["bigint", "int8", "bigserial"],
        "crystal"     => "Int64",
        "alternative" => "integer if values fit in 32 bits",
      },
    }

    def initialize(
      @model_name : String,
      @column_name : String,
      @column_index : Int32,
      @expected_type : String,
      @actual_type : String,
      @resultset_column_name : String? = nil,
      cause : Exception? = nil,
    )
      super(build_message, cause)
    end

    private def build_message : String
      String.build do |str|
        str << "Type mismatch reading " << @model_name << "#" << @column_name << "\n\n"

        str << "Column: " << @column_name
        if rs_col = @resultset_column_name
          str << " (ResultSet column: '" << rs_col << "'"
        end
        str << ", index " << @column_index << ")\n"

        str << "Expected type: " << @expected_type << "\n"
        str << "Actual type: " << @actual_type << "\n\n"

        # Check if ResultSet column name differs from model column name
        if (rs_col = @resultset_column_name) && rs_col != @column_name
          str << "WARNING: Column name mismatch!\n"
          str << "  Model expects column '" << @column_name << "' at index " << @column_index << "\n"
          str << "  But ResultSet has column '" << rs_col << "' at that position\n"
          str << "  This suggests a column order mismatch - check your model's column order.\n\n"
        end

        # Add type-specific hints
        if hint = type_hint
          str << hint
        else
          str << "Hint: Update your model's column type to match the database:\n\n"
          str << "  column " << @column_name << " : " << suggested_crystal_type << "\n"
        end
      end
    end

    private def type_hint : String?
      if info = TYPE_HINTS[@actual_type]?
        String.build do |str|
          str << "Hint: PostgreSQL types " << info["db_types"].as(Array).join(", ") << " map to " << @actual_type << " in Crystal.\n"
          str << "Change your model column to use " << info["crystal"] << ":\n\n"
          str << "  column " << @column_name << " : " << info["crystal"] << "\n\n"
          str << "Or change your database column to " << info["alternative"].as(String) << "."
        end
      end
    end

    private def suggested_crystal_type : String
      # Remove union types and Nil for suggestion
      @actual_type.gsub(" | Nil", "").gsub("Nil | ", "")
    end
  end
end

module Ralph
  # Union type for primary key values returned from bulk operations
  # Supports both integer and UUID primary keys
  alias BulkOperationId = Int64 | String

  # Result of a bulk insert operation
  #
  # Contains information about the inserted records, including IDs if available.
  struct BulkInsertResult
    # Number of records inserted
    getter count : Int32

    # IDs of inserted records (only available on PostgreSQL with RETURNING clause)
    # For SQLite, this will be empty as SQLite doesn't support RETURNING for multi-row inserts
    # Returns String for UUID columns, Int64 for integer columns
    getter ids : Array(BulkOperationId)

    def initialize(@count : Int32, @ids : Array(BulkOperationId) = [] of BulkOperationId)
    end
  end

  # Result of a bulk upsert operation
  struct BulkUpsertResult
    # Number of records affected (inserted + updated)
    getter count : Int32

    # IDs of affected records (only available on PostgreSQL)
    # Returns String for UUID columns, Int64 for integer columns
    getter ids : Array(BulkOperationId)

    def initialize(@count : Int32, @ids : Array(BulkOperationId) = [] of BulkOperationId)
    end
  end

  # Options for upsert conflict resolution
  struct UpsertOptions
    # Column(s) to check for conflicts
    getter conflict_columns : Array(String)

    # Columns to update on conflict (if empty, updates all non-conflict columns)
    getter update_columns : Array(String)

    # Whether to update nothing on conflict (INSERT IGNORE behavior)
    getter do_nothing : Bool

    def initialize(
      @conflict_columns : Array(String) = [] of String,
      @update_columns : Array(String) = [] of String,
      @do_nothing : Bool = false,
    )
    end
  end

  # Bulk operations mixin for Ralph::Model
  #
  # Provides efficient batch insert, update, and delete operations that
  # execute in a single database round-trip.
  #
  # ## Example
  #
  # ```
  # # Bulk insert
  # User.insert_all([
  #   {name: "John", email: "john@example.com"},
  #   {name: "Jane", email: "jane@example.com"},
  # ])
  #
  # # Upsert (insert or update on conflict)
  # User.upsert_all([
  #   {email: "john@example.com", name: "John Updated"},
  # ], on_conflict: :email, update: [:name])
  #
  # # Bulk update
  # User.update_all({active: false}, where: {role: "guest"})
  #
  # # Bulk delete
  # User.delete_all(where: {role: "guest"})
  # ```
  module BulkOperations
    macro included
      extend BulkOperationsMethods
    end

    module BulkOperationsMethods
      # Bulk insert multiple records in a single query
      #
      # Executes a multi-row INSERT statement for efficient batch inserts.
      # This is significantly faster than inserting records one by one.
      #
      # ## Parameters
      #
      # - `records`: Array of NamedTuples or Hashes with column-value pairs
      # - `returning`: Whether to return inserted IDs (PostgreSQL only, default: false)
      #
      # ## Returns
      #
      # BulkInsertResult with count and optionally IDs
      #
      # ## Example
      #
      # ```
      # result = User.insert_all([
      #   {name: "Alice", email: "alice@example.com"},
      #   {name: "Bob", email: "bob@example.com"},
      # ])
      # puts result.count # => 2
      # ```
      #
      # ## Notes
      #
      # - Does NOT run validations or callbacks (bypasses model layer)
      # - All records must have the same columns
      # - Uses a single INSERT statement with multiple value tuples
      def insert_all(records : Array(NamedTuple), returning : Bool = false) : BulkInsertResult
        return BulkInsertResult.new(0) if records.empty?

        # Convert NamedTuples to Hashes
        hashes = records.map { |r| named_tuple_to_hash(r) }
        _insert_all_hashes(hashes, returning)
      end

      def insert_all(records : Array(Hash(String, DB::Any)), returning : Bool = false) : BulkInsertResult
        return BulkInsertResult.new(0) if records.empty?
        _insert_all_hashes(records, returning)
      end

      private def _insert_all_hashes(records : Array(Hash(String, DB::Any)), returning : Bool) : BulkInsertResult
        return BulkInsertResult.new(0) if records.empty?

        # Get columns from first record
        columns = records.first.keys

        # Build multi-row INSERT
        sql, args = build_multi_insert(self.table_name, columns, records)

        dialect = Ralph.database.dialect

        case dialect
        when :postgres
          if returning
            sql += " RETURNING \"#{self.primary_key}\""
            ids = [] of BulkOperationId
            rs = Ralph.database.query_all(sql, args: args)
            rs.each do
              ids << read_primary_key_value(rs)
            end
            rs.close
            BulkInsertResult.new(ids.size, ids)
          else
            Ralph.database.execute(sql, args: args)
            BulkInsertResult.new(records.size)
          end
        else
          # SQLite doesn't support RETURNING for multi-row inserts easily
          Ralph.database.execute(sql, args: args)
          BulkInsertResult.new(records.size)
        end
      end

      # Read primary key value from result set based on model's primary key type.
      # Returns String for UUID primary keys, Int64 for integer primary keys.
      #
      # Note: Uses untyped read for UUID because PostgreSQL returns native UUID
      # while SQLite returns String. The untyped read handles both cases and we
      # convert to String for the return type.
      private def read_primary_key_value(rs : ::DB::ResultSet) : BulkOperationId
        case self.primary_key_type
        when "UUID"
          # Untyped read handles both PostgreSQL (UUID) and SQLite (String)
          rs.read.to_s
        else
          rs.read(Int64)
        end
      end

      # Upsert (insert or update on conflict) multiple records
      #
      # Performs an INSERT with ON CONFLICT handling. If a record with the
      # same conflict key already exists, it updates the specified columns.
      #
      # ## Parameters
      #
      # - `records`: Array of NamedTuples or Hashes with column-value pairs
      # - `on_conflict`: Column(s) to check for conflicts (Symbol, String, or Array)
      # - `update`: Columns to update on conflict (if nil, updates all non-conflict columns)
      # - `do_nothing`: If true, skip conflicting records without updating
      #
      # ## Returns
      #
      # BulkUpsertResult with count and optionally IDs
      #
      # ## Example
      #
      # ```
      # # Update name on email conflict
      # User.upsert_all([
      #   {email: "alice@example.com", name: "Alice Updated"},
      #   {email: "bob@example.com", name: "Bob Updated"},
      # ], on_conflict: :email, update: [:name])
      #
      # # Do nothing on conflict (INSERT IGNORE behavior)
      # User.upsert_all([
      #   {email: "alice@example.com", name: "Alice"},
      # ], on_conflict: :email, do_nothing: true)
      # ```
      def upsert_all(
        records : Array(NamedTuple),
        on_conflict : Symbol | String | Array(Symbol) | Array(String),
        update : Array(Symbol) | Array(String) | Nil = nil,
        do_nothing : Bool = false,
      ) : BulkUpsertResult
        return BulkUpsertResult.new(0) if records.empty?

        hashes = records.map { |r| named_tuple_to_hash(r) }
        conflict_cols = normalize_columns(on_conflict)
        update_cols = update ? normalize_columns(update) : nil

        _upsert_all_hashes(hashes, conflict_cols, update_cols, do_nothing)
      end

      def upsert_all(
        records : Array(Hash(String, DB::Any)),
        on_conflict : Symbol | String | Array(Symbol) | Array(String),
        update : Array(Symbol) | Array(String) | Nil = nil,
        do_nothing : Bool = false,
      ) : BulkUpsertResult
        return BulkUpsertResult.new(0) if records.empty?

        conflict_cols = normalize_columns(on_conflict)
        update_cols = update ? normalize_columns(update) : nil

        _upsert_all_hashes(records, conflict_cols, update_cols, do_nothing)
      end

      private def _upsert_all_hashes(
        records : Array(Hash(String, DB::Any)),
        conflict_columns : Array(String),
        update_columns : Array(String)?,
        do_nothing : Bool,
      ) : BulkUpsertResult
        return BulkUpsertResult.new(0) if records.empty?

        columns = records.first.keys
        dialect = Ralph.database.dialect

        # Build the base INSERT part
        sql, args = build_multi_insert(self.table_name, columns, records)

        # Determine which columns to update
        cols_to_update = if do_nothing
                           [] of String
                         elsif update_columns
                           update_columns
                         else
                           # Update all columns except conflict columns and primary key
                           columns.reject { |c| conflict_columns.includes?(c) || c == self.primary_key }
                         end

        # Add conflict handling clause
        case dialect
        when :postgres
          conflict_col_list = conflict_columns.map { |c| "\"#{c}\"" }.join(", ")
          if do_nothing
            sql += " ON CONFLICT (#{conflict_col_list}) DO NOTHING"
          else
            update_clauses = cols_to_update.map { |c| "\"#{c}\" = EXCLUDED.\"#{c}\"" }.join(", ")
            sql += " ON CONFLICT (#{conflict_col_list}) DO UPDATE SET #{update_clauses}"
          end
          sql += " RETURNING \"#{self.primary_key}\""

          ids = [] of BulkOperationId
          rs = Ralph.database.query_all(sql, args: args)
          rs.each do
            ids << read_primary_key_value(rs)
          end
          rs.close
          BulkUpsertResult.new(ids.size, ids)
        else
          # SQLite
          conflict_col_list = conflict_columns.map { |c| "\"#{c}\"" }.join(", ")
          if do_nothing
            sql = sql.gsub("INSERT INTO", "INSERT OR IGNORE INTO")
          else
            update_clauses = cols_to_update.map { |c| "\"#{c}\" = excluded.\"#{c}\"" }.join(", ")
            sql += " ON CONFLICT (#{conflict_col_list}) DO UPDATE SET #{update_clauses}"
          end

          Ralph.database.execute(sql, args: args)
          BulkUpsertResult.new(records.size)
        end
      end

      # Bulk update records matching conditions
      #
      # Updates multiple records in a single UPDATE statement without
      # loading them into memory.
      #
      # ## Parameters
      #
      # - `updates`: Hash of column-value pairs to set
      # - `where`: Hash of column-value conditions (all conditions ANDed)
      #
      # ## Returns
      #
      # Number of records updated (when supported by backend)
      #
      # ## Example
      #
      # ```
      # # Deactivate all guest users
      # User.update_all({active: false}, where: {role: "guest"})
      #
      # # Set all posts to draft
      # Post.update_all({published: false, status: "draft"}, where: {author_id: 123})
      # ```
      #
      # ## Notes
      #
      # - Does NOT run validations or callbacks
      # - Does NOT update timestamps automatically
      def update_all(updates : NamedTuple, where conditions : NamedTuple) : Int64
        update_hash = named_tuple_to_hash(updates)
        where_hash = named_tuple_to_hash(conditions)
        _update_all_hashes(update_hash, where_hash)
      end

      def update_all(updates : Hash(String, DB::Any), where conditions : Hash(String, DB::Any)) : Int64
        _update_all_hashes(updates, conditions)
      end

      # Update all records without conditions (use with caution!)
      def update_all(updates : NamedTuple) : Int64
        update_hash = named_tuple_to_hash(updates)
        _update_all_hashes(update_hash, {} of String => DB::Any)
      end

      def update_all(updates : Hash(String, DB::Any)) : Int64
        _update_all_hashes(updates, {} of String => DB::Any)
      end

      private def _update_all_hashes(updates : Hash(String, DB::Any), conditions : Hash(String, DB::Any)) : Int64
        return 0_i64 if updates.empty?

        query = Ralph::Query::Builder.new(self.table_name)

        # Add WHERE conditions
        conditions.each do |column, value|
          query = query.where("\"#{column}\" = ?", value)
        end

        sql, args = query.build_update(updates)
        Ralph.database.execute(sql, args: args)

        # Most backends don't return affected row count easily
        # For now, we return 0 and document that count may not be accurate
        0_i64
      end

      # Bulk delete records matching conditions
      #
      # Deletes multiple records in a single DELETE statement without
      # loading them into memory.
      #
      # ## Parameters
      #
      # - `where`: Hash of column-value conditions (all conditions ANDed)
      #
      # ## Returns
      #
      # Number of records deleted (when supported by backend)
      #
      # ## Example
      #
      # ```
      # # Delete all guest users
      # User.delete_all(where: {role: "guest"})
      #
      # # Delete old posts
      # Post.delete_all(where: {status: "archived"})
      # ```
      #
      # ## Notes
      #
      # - Does NOT run callbacks (use destroy on instances if you need callbacks)
      # - Does NOT handle dependent associations
      # - For soft deletes, use `update_all` to set deleted_at instead
      def delete_all(where conditions : NamedTuple) : Int64
        where_hash = named_tuple_to_hash(conditions)
        _delete_all_hashes(where_hash)
      end

      def delete_all(where conditions : Hash(String, DB::Any)) : Int64
        _delete_all_hashes(conditions)
      end

      # Delete all records without conditions (DANGEROUS - deletes everything!)
      def delete_all : Int64
        _delete_all_hashes({} of String => DB::Any)
      end

      private def _delete_all_hashes(conditions : Hash(String, DB::Any)) : Int64
        query = Ralph::Query::Builder.new(self.table_name)

        conditions.each do |column, value|
          query = query.where("\"#{column}\" = ?", value)
        end

        sql, args = query.build_delete
        Ralph.database.execute(sql, args: args)

        0_i64
      end

      # Build a multi-row INSERT statement
      private def build_multi_insert(
        table_name : String,
        columns : Array(String),
        records : Array(Hash(String, DB::Any)),
      ) : Tuple(String, Array(DB::Any))
        column_list = columns.map { |c| "\"#{c}\"" }.join(", ")

        dialect = Ralph.database.dialect
        args = [] of DB::Any
        value_tuples = [] of String

        records.each do |record|
          placeholders = columns.map_with_index do |col, i|
            args << record[col]
            case dialect
            when :postgres
              "$#{args.size}"
            else
              "?"
            end
          end
          value_tuples << "(#{placeholders.join(", ")})"
        end

        sql = "INSERT INTO \"#{table_name}\" (#{column_list}) VALUES #{value_tuples.join(", ")}"
        {sql, args}
      end

      # Convert a NamedTuple to a Hash
      private def named_tuple_to_hash(tuple : NamedTuple) : Hash(String, DB::Any)
        hash = {} of String => DB::Any
        tuple.each do |key, value|
          hash[key.to_s] = value.as(DB::Any)
        end
        hash
      end

      # Normalize column specification to Array(String)
      private def normalize_columns(cols) : Array(String)
        case cols
        when Symbol
          [cols.to_s]
        when String
          [cols]
        when Array(Symbol)
          cols.map(&.to_s)
        when Array(String)
          cols
        else
          [] of String
        end
      end
    end
  end
end

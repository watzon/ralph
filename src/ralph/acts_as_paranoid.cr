# Soft Deletes (Acts As Paranoid) Module for Ralph ORM
#
# Provides soft delete functionality where records are marked as deleted
# rather than being permanently removed from the database.
#
# ## Usage
#
# ```
# class User < Ralph::Model
#   include Ralph::ActsAsParanoid
#
#   table :users
#   column id, Int64, primary: true
#   column name, String
# end
#
# user = User.create(name: "Alice")
# user.destroy  # Sets deleted_at, doesn't actually delete
# user.deleted? # => true
#
# User.all.count    # => 0 (excludes soft-deleted)
# User.with_deleted # => includes soft-deleted records
# User.only_deleted # => only soft-deleted records
#
# user.restore         # Clears deleted_at
# user.really_destroy! # Permanently deletes from database
# ```
#
# ## Migration
#
# ```
# create_table :users do |t|
#   t.primary_key
#   t.string :name
#   t.soft_deletes # creates deleted_at column
# end
# ```

module Ralph
  module ActsAsParanoid
    macro included
      # Mark this model as using soft deletes
      PARANOID_MODE = true

      # Add the deleted_at column
      column deleted_at, Time?

      # Class-level accessor to check if soft deletes are enabled
      def self.paranoid? : Bool
        true
      end

      # Check if record is soft-deleted
      def deleted? : Bool
        !deleted_at.nil?
      end

      # Override base_query to exclude soft-deleted records by default
      protected def self.base_query : Ralph::Query::Builder
        Ralph::Query::Builder.new(self.table_name)
          .select(column_names_ordered)
          .where("\"#{self.table_name}\".\"deleted_at\" IS NULL")
      end

      # Query scope that includes ALL records (soft-deleted and not)
      #
      # Returns a query builder without the soft delete filter.
      #
      # Example:
      # ```
      # User.with_deleted.all        # includes soft-deleted records
      # User.with_deleted.find(1)    # finds even if soft-deleted
      # User.with_deleted.where(...) # query all records
      # ```
      def self.with_deleted : Ralph::Query::Builder
        Ralph::Query::Builder.new(self.table_name).select(column_names_ordered)
      end

      # Query scope that returns ONLY soft-deleted records
      #
      # Example:
      # ```
      # User.only_deleted.all   # only soft-deleted records
      # User.only_deleted.count # count of deleted records
      # ```
      def self.only_deleted : Ralph::Query::Builder
        Ralph::Query::Builder.new(self.table_name)
          .select(column_names_ordered)
          .where("\"#{self.table_name}\".\"deleted_at\" IS NOT NULL")
      end

      # Find a record by ID, including soft-deleted records
      def self.find_with_deleted(id)
        query = with_deleted.where("\"#{@@primary_key}\" = ?", id)
        result = Ralph.database.query_one(query.build_select, args: query.where_args)
        return nil unless result

        record = from_result_set(result)
        result.close
        record
      end

      # Override count to exclude soft-deleted records by default
      def self.count : Int64
        query = Ralph::Query::Builder.new(self.table_name)
          .where("\"#{self.table_name}\".\"deleted_at\" IS NULL")
        result = Ralph.database.scalar(query.build_count, args: query.where_args)
        return 0_i64 unless result

        case result
        when Int32 then result.to_i64
        when Int64 then result.as(Int64)
        else            0_i64
        end
      end

      # Restore a soft-deleted record
      #
      # Sets `deleted_at` to nil and persists the change.
      # Returns true if successful, false otherwise.
      #
      # Example:
      # ```
      # user.destroy  # soft delete
      # user.deleted? # => true
      # user.restore  # undelete
      # user.deleted? # => false
      # ```
      def restore : Bool
        return true unless deleted?

        self.deleted_at = nil
        sql = "UPDATE \"#{self.class.table_name}\" SET \"deleted_at\" = NULL WHERE \"#{self.class.primary_key}\" = $1"
        Ralph.database.execute(sql, args: [primary_key_value.as(Ralph::Query::DBValue)])
        true
      end

      # Permanently delete the record from the database
      #
      # This bypasses soft deletes and actually removes the record.
      # Use with caution - this cannot be undone!
      #
      # Returns true if successful, false otherwise.
      # Runs before_destroy and after_destroy callbacks.
      #
      # Example:
      # ```
      # user.really_destroy!            # permanently removes from DB
      # User.find(user.id)              # => nil
      # User.find_with_deleted(user.id) # => nil
      # ```
      def really_destroy! : Bool
        return false if new_record?

        _run_before_destroy_callbacks
        _run_dependent_handlers

        query = Ralph::Query::Builder.new(self.class.table_name)
          .where("\"#{self.class.primary_key}\" = ?", primary_key_value)

        sql, args = query.build_delete
        Ralph.database.execute(sql, args: args)

        _run_after_destroy_callbacks
        true
      end

      # Internal: Run before_destroy callbacks
      private def _run_before_destroy_callbacks
        \{% for meth in @type.methods %}
          \{% if meth.annotation(Ralph::Callbacks::BeforeDestroy) %}
            \{% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
            \{% if options %}
              \{% if_method = options[:if] %}
              \{% unless_method = options[:unless] %}
              \{% if if_method && unless_method %}
                if \{{if_method.id}} && !\{{unless_method.id}}
                  \{{meth.name}}
                end
              \{% elsif if_method %}
                if \{{if_method.id}}
                  \{{meth.name}}
                end
              \{% elsif unless_method %}
                unless \{{unless_method.id}}
                  \{{meth.name}}
                end
              \{% else %}
                \{{meth.name}}
              \{% end %}
            \{% else %}
              \{{meth.name}}
            \{% end %}
          \{% end %}
        \{% end %}
      end

      # Internal: Run after_destroy callbacks
      private def _run_after_destroy_callbacks
        \{% for meth in @type.methods %}
          \{% if meth.annotation(Ralph::Callbacks::AfterDestroy) %}
            \{% options = meth.annotation(Ralph::Callbacks::CallbackOptions) %}
            \{% if options %}
              \{% if_method = options[:if] %}
              \{% unless_method = options[:unless] %}
              \{% if if_method && unless_method %}
                if \{{if_method.id}} && !\{{unless_method.id}}
                  \{{meth.name}}
                end
              \{% elsif if_method %}
                if \{{if_method.id}}
                  \{{meth.name}}
                end
              \{% elsif unless_method %}
                unless \{{unless_method.id}}
                  \{{meth.name}}
                end
              \{% else %}
                \{{meth.name}}
              \{% end %}
            \{% else %}
              \{{meth.name}}
            \{% end %}
          \{% end %}
        \{% end %}
      end

      # Internal: Run dependent association handlers
      private def _run_dependent_handlers
        \{% for meth in @type.methods %}
          \{% if meth.name.starts_with?("_handle_dependent_") %}
            \{{meth.name}}
          \{% end %}
        \{% end %}
      end

      # Override destroy to perform soft delete instead of actual deletion
      #
      # Sets `deleted_at` to current UTC time and updates `updated_at` if present.
      # Runs before_destroy and after_destroy callbacks.
      #
      # Returns true if successful, false otherwise.
      def destroy : Bool
        return false if new_record?

        _run_before_destroy_callbacks
        _run_dependent_handlers

        # Soft delete: set deleted_at timestamp
        self.deleted_at = Time.utc

        # Also update updated_at if the model has timestamps
        \{% if @type.has_method?(:updated_at=) %}
          self.updated_at = Time.utc
        \{% end %}

        # Build UPDATE query instead of DELETE
        columns = ["\"deleted_at\""]
        values = [] of Ralph::Query::DBValue
        values << deleted_at

        \{% if @type.has_method?(:updated_at=) %}
          columns << "\"updated_at\""
          values << updated_at
        \{% end %}

        set_clause = columns.map_with_index { |col, i| "#{col} = $#{i + 1}" }.join(", ")
        where_param_index = values.size + 1
        sql = "UPDATE \"#{self.class.table_name}\" SET #{set_clause} WHERE \"#{self.class.primary_key}\" = $#{where_param_index}"
        # UUID primary keys are automatically converted to strings by the database backend
        pk_val = primary_key_value
        values << (pk_val.is_a?(UUID) ? pk_val : pk_val.as(Ralph::Query::DBValue))

        Ralph.database.execute(sql, args: values)

        _run_after_destroy_callbacks
        true
      end
    end
  end
end

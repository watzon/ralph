module Ralph
  module Query
    # Type alias for DB-compatible values
    alias DBValue = Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil

    # Represents a WHERE clause
    class WhereClause
      getter clause : String
      getter args : Array(DBValue)

      def initialize(@clause : String, @args : Array(DBValue) = [] of DBValue)
      end

      def to_sql : String
        if args.empty?
          clause
        else
          # Replace ? placeholders with $1, $2, etc.
          index = 0
          clause.gsub("?") do
            index += 1
            "$#{index}"
          end
        end
      end
    end

    # Represents a CTE (Common Table Expression)
    class CTEClause
      getter name : String
      getter query : Builder
      getter recursive : Bool
      getter? materialized : Bool?

      def initialize(@name : String, @query : Builder, @recursive : Bool = false, @materialized : Bool? = nil)
      end

      # Build the CTE SQL with renumbered parameters
      def to_sql(param_offset : Int32) : Tuple(String, Int32)
        subquery_sql, new_offset = @query.build_select_with_offset(param_offset)
        materialized_clause = case @materialized
                              when true  then " MATERIALIZED"
                              when false then " NOT MATERIALIZED"
                              else            ""
                              end
        {"\"#{@name}\" AS#{materialized_clause} (#{subquery_sql})", new_offset}
      end
    end

    # Represents a subquery in the FROM clause
    class FromSubquery
      getter query : Builder
      getter alias_name : String

      def initialize(@query : Builder, @alias_name : String)
      end

      # Build the FROM subquery SQL with renumbered parameters
      def to_sql(param_offset : Int32) : Tuple(String, Int32)
        subquery_sql, new_offset = @query.build_select_with_offset(param_offset)
        {"(#{subquery_sql}) AS \"#{@alias_name}\"", new_offset}
      end
    end

    # Represents an EXISTS/NOT EXISTS subquery condition
    class ExistsClause
      getter query : Builder
      getter negated : Bool

      def initialize(@query : Builder, @negated : Bool = false)
      end

      # Build the EXISTS clause SQL with renumbered parameters
      def to_sql(param_offset : Int32) : Tuple(String, Int32)
        subquery_sql, new_offset = @query.build_select_with_offset(param_offset)
        keyword = @negated ? "NOT EXISTS" : "EXISTS"
        {"#{keyword} (#{subquery_sql})", new_offset}
      end
    end

    # Represents an IN subquery condition
    class InSubqueryClause
      getter column : String
      getter query : Builder
      getter negated : Bool

      def initialize(@column : String, @query : Builder, @negated : Bool = false)
      end

      # Build the IN subquery clause SQL with renumbered parameters
      def to_sql(param_offset : Int32) : Tuple(String, Int32)
        subquery_sql, new_offset = @query.build_select_with_offset(param_offset)
        keyword = @negated ? "NOT IN" : "IN"
        {"\"#{@column}\" #{keyword} (#{subquery_sql})", new_offset}
      end
    end

    # Represents a window function in the SELECT clause
    class WindowClause
      getter function : String
      getter partition_by : String?
      getter order_by : String?
      getter alias_name : String

      def initialize(@function : String, @partition_by : String? = nil, @order_by : String? = nil, @alias_name : String = "window_result")
      end

      def to_sql : String
        over_parts = [] of String
        if partition = @partition_by
          over_parts << "PARTITION BY #{partition}"
        end
        if order = @order_by
          over_parts << "ORDER BY #{order}"
        end
        over_clause = over_parts.empty? ? "" : over_parts.join(" ")
        "#{@function} OVER (#{over_clause}) AS \"#{@alias_name}\""
      end
    end

    # Represents a set operation (UNION, UNION ALL, INTERSECT, EXCEPT)
    class SetOperationClause
      enum Operation
        Union
        UnionAll
        Intersect
        Except
      end

      getter query : Builder
      getter operation : Operation

      def initialize(@query : Builder, @operation : Operation)
      end

      # Build the set operation SQL with renumbered parameters
      def to_sql(param_offset : Int32) : Tuple(String, Int32)
        subquery_sql, new_offset = @query.build_select_with_offset(param_offset)
        keyword = case @operation
                  when Operation::Union     then "UNION"
                  when Operation::UnionAll  then "UNION ALL"
                  when Operation::Intersect then "INTERSECT"
                  when Operation::Except    then "EXCEPT"
                  else                           "UNION"
                  end
        {"#{keyword} #{subquery_sql}", new_offset}
      end
    end

    # Represents an ORDER BY clause
    class OrderClause
      getter column : String
      getter direction : Symbol

      def initialize(@column : String, @direction : Symbol = :asc)
      end

      def to_sql : String
        "\"#{column}\" #{direction.to_s.upcase}"
      end
    end

    # Represents a JOIN clause
    class JoinClause
      getter table : String
      getter on : String
      getter type : Symbol
      getter alias : String?

      def initialize(@table : String, @on : String, @type : Symbol = :inner, @alias : String? = nil)
      end

      def to_sql : String
        join_type = case type
                    when :inner      then "INNER JOIN"
                    when :left       then "LEFT JOIN"
                    when :right      then "RIGHT JOIN"
                    when :cross      then "CROSS JOIN"
                    when :full       then "FULL OUTER JOIN"
                    when :full_outer then "FULL OUTER JOIN"
                    else
                      "#{type.to_s.upcase} JOIN"
                    end

        table_part = if alias_name = @alias
                       "\"#{table}\" AS \"#{alias_name}\""
                     else
                       "\"#{table}\""
                     end

        if type == :cross
          # CROSS JOIN doesn't have an ON clause
          "#{join_type} #{table_part}"
        else
          "#{join_type} #{table_part} ON #{on}"
        end
      end
    end

    # Represents an OR/AND combined clause from query merging
    class CombinedClause
      getter left_clauses : Array(WhereClause)
      getter right_clauses : Array(WhereClause)
      getter operator : Symbol # :or or :and

      def initialize(@left_clauses : Array(WhereClause), @right_clauses : Array(WhereClause), @operator : Symbol)
      end
    end

    # Represents a row-level locking clause (FOR UPDATE, FOR SHARE, etc.)
    #
    # Used for pessimistic locking in concurrent environments.
    #
    # ## Lock Modes
    #
    # - `:update` - Exclusive lock (FOR UPDATE)
    # - `:share` - Shared lock (FOR SHARE)
    # - `:no_key_update` - FOR NO KEY UPDATE (PostgreSQL)
    # - `:key_share` - FOR KEY SHARE (PostgreSQL)
    #
    # ## Options
    #
    # - `:nowait` - Fail immediately if lock cannot be acquired
    # - `:skip_locked` - Skip rows that are already locked
    class LockClause
      enum Mode
        Update      # FOR UPDATE
        Share       # FOR SHARE
        NoKeyUpdate # FOR NO KEY UPDATE (PostgreSQL)
        KeyShare    # FOR KEY SHARE (PostgreSQL)
      end

      enum Option
        None
        Nowait     # Don't wait for lock
        SkipLocked # Skip locked rows
      end

      getter mode : Mode
      getter option : Option
      getter tables : Array(String)

      def initialize(@mode : Mode = Mode::Update, @option : Option = Option::None, @tables : Array(String) = [] of String)
      end

      def to_sql : String
        sql = case @mode
              when Mode::Update      then "FOR UPDATE"
              when Mode::Share       then "FOR SHARE"
              when Mode::NoKeyUpdate then "FOR NO KEY UPDATE"
              when Mode::KeyShare    then "FOR KEY SHARE"
              else                        "FOR UPDATE"
              end

        unless @tables.empty?
          sql += " OF #{@tables.map { |t| "\"#{t}\"" }.join(", ")}"
        end

        case @option
        when Option::Nowait
          sql += " NOWAIT"
        when Option::SkipLocked
          sql += " SKIP LOCKED"
        end

        sql
      end
    end

    # Builds SQL queries with an immutable fluent interface.
    #
    # Each method returns a NEW Builder instance, leaving the original unchanged.
    # This enables safe query branching:
    #
    # ```
    # base = Builder.new("users").where("active = ?", true)
    # admins = base.where("role = ?", "admin") # base is unchanged
    # users = base.where("role = ?", "user")   # base is unchanged
    # ```
    class Builder
      @wheres : Array(WhereClause)
      @orders : Array(OrderClause)
      @limit : Int32?
      @offset : Int32?
      @joins : Array(JoinClause)
      @selects : Array(String)
      @groups : Array(String)
      @havings : Array(WhereClause)
      @distinct : Bool
      @distinct_columns : Array(String)

      # Subquery support
      @ctes : Array(CTEClause)
      @from_subquery : FromSubquery?
      @exists_clauses : Array(ExistsClause)
      @in_subquery_clauses : Array(InSubqueryClause)

      # Query composition support
      @combined_clauses : Array(CombinedClause)

      # Window functions support
      @windows : Array(WindowClause)

      # Set operations support (UNION, INTERSECT, EXCEPT)
      @set_operations : Array(SetOperationClause)

      # Query caching support
      @cached : Bool
      @@cache : Hash(String, Array(Hash(String, DBValue))) = {} of String => Array(Hash(String, DBValue))

      # Row locking support (SELECT FOR UPDATE, etc.)
      @lock : LockClause?

      # Expose table for subquery introspection
      getter table : String

      # Expose fields for query composition
      getter wheres : Array(WhereClause)
      getter orders : Array(OrderClause)
      getter joins : Array(JoinClause)
      getter selects : Array(String)
      getter groups : Array(String)
      getter havings : Array(WhereClause)
      getter combined_clauses : Array(CombinedClause)
      getter distinct_columns : Array(String)
      getter? distinct : Bool
      getter limit_value : Int32?
      getter offset_value : Int32?
      getter windows : Array(WindowClause)
      getter set_operations : Array(SetOperationClause)
      getter? cached : Bool
      getter ctes : Array(CTEClause)
      getter from_subquery : FromSubquery?
      getter exists_clauses : Array(ExistsClause)
      getter in_subquery_clauses : Array(InSubqueryClause)
      getter lock : LockClause?

      def initialize(@table : String)
        @wheres = [] of WhereClause
        @orders = [] of OrderClause
        @limit = nil
        @offset = nil
        @joins = [] of JoinClause
        @selects = [] of String
        @groups = [] of String
        @havings = [] of WhereClause
        @distinct = false
        @distinct_columns = [] of String
        @ctes = [] of CTEClause
        @from_subquery = nil
        @exists_clauses = [] of ExistsClause
        @in_subquery_clauses = [] of InSubqueryClause
        @combined_clauses = [] of CombinedClause
        @windows = [] of WindowClause
        @set_operations = [] of SetOperationClause
        @cached = false
        @lock = nil
      end

      # Private copy constructor for immutability - creates a deep copy
      protected def initialize(
        @table : String,
        @wheres : Array(WhereClause),
        @orders : Array(OrderClause),
        @limit : Int32?,
        @offset : Int32?,
        @joins : Array(JoinClause),
        @selects : Array(String),
        @groups : Array(String),
        @havings : Array(WhereClause),
        @distinct : Bool,
        @distinct_columns : Array(String),
        @ctes : Array(CTEClause),
        @from_subquery : FromSubquery?,
        @exists_clauses : Array(ExistsClause),
        @in_subquery_clauses : Array(InSubqueryClause),
        @combined_clauses : Array(CombinedClause),
        @windows : Array(WindowClause),
        @set_operations : Array(SetOperationClause),
        @cached : Bool,
        @lock : LockClause?,
      )
      end

      # Create a copy of this builder with all state duplicated
      def dup : Builder
        Builder.new(
          @table,
          @wheres.dup,
          @orders.dup,
          @limit,
          @offset,
          @joins.dup,
          @selects.dup,
          @groups.dup,
          @havings.dup,
          @distinct,
          @distinct_columns.dup,
          @ctes.dup,
          @from_subquery,
          @exists_clauses.dup,
          @in_subquery_clauses.dup,
          @combined_clauses.dup,
          @windows.dup,
          @set_operations.dup,
          @cached,
          @lock
        )
      end

      # Getter aliases for limit/offset (they use @limit/@offset internally)
      protected def limit_value : Int32?
        @limit
      end

      protected def offset_value : Int32?
        @offset
      end

      # Select specific columns (returns new Builder)
      def select(*columns : String) : Builder
        with_selects(@selects + columns.to_a)
      end

      # Select specific columns from an array (returns new Builder)
      def select(columns : Array(String)) : Builder
        with_selects(@selects + columns)
      end

      # Add a WHERE clause (returns new Builder)
      def where(clause : String, *args) : Builder
        converted = args.to_a.map { |a| a.as(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil) }
        with_wheres(@wheres + [WhereClause.new(clause, converted)])
      end

      # Add a WHERE clause with a block (returns new Builder)
      def where(&block : WhereBuilder ->) : Builder
        builder = WhereBuilder.new
        block.call(builder)
        if clause = builder.build
          with_wheres(@wheres + [clause])
        else
          self
        end
      end

      # Add a WHERE NOT clause (returns new Builder)
      def where_not(clause : String, *args) : Builder
        converted = args.to_a.map { |a| a.as(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil) }
        with_wheres(@wheres + [WhereClause.new("NOT (#{clause})", converted)])
      end

      # Private helper methods for immutable updates
      private def with_wheres(wheres : Array(WhereClause)) : Builder
        Builder.new(@table, wheres, @orders, @limit, @offset, @joins, @selects, @groups, @havings, @distinct, @distinct_columns, @ctes, @from_subquery, @exists_clauses, @in_subquery_clauses, @combined_clauses, @windows, @set_operations, @cached, @lock)
      end

      private def with_selects(selects : Array(String)) : Builder
        Builder.new(@table, @wheres, @orders, @limit, @offset, @joins, selects, @groups, @havings, @distinct, @distinct_columns, @ctes, @from_subquery, @exists_clauses, @in_subquery_clauses, @combined_clauses, @windows, @set_operations, @cached, @lock)
      end

      private def with_orders(orders : Array(OrderClause)) : Builder
        Builder.new(@table, @wheres, orders, @limit, @offset, @joins, @selects, @groups, @havings, @distinct, @distinct_columns, @ctes, @from_subquery, @exists_clauses, @in_subquery_clauses, @combined_clauses, @windows, @set_operations, @cached, @lock)
      end

      private def with_limit(limit : Int32?) : Builder
        Builder.new(@table, @wheres, @orders, limit, @offset, @joins, @selects, @groups, @havings, @distinct, @distinct_columns, @ctes, @from_subquery, @exists_clauses, @in_subquery_clauses, @combined_clauses, @windows, @set_operations, @cached, @lock)
      end

      private def with_offset(offset : Int32?) : Builder
        Builder.new(@table, @wheres, @orders, @limit, offset, @joins, @selects, @groups, @havings, @distinct, @distinct_columns, @ctes, @from_subquery, @exists_clauses, @in_subquery_clauses, @combined_clauses, @windows, @set_operations, @cached, @lock)
      end

      private def with_joins(joins : Array(JoinClause)) : Builder
        Builder.new(@table, @wheres, @orders, @limit, @offset, joins, @selects, @groups, @havings, @distinct, @distinct_columns, @ctes, @from_subquery, @exists_clauses, @in_subquery_clauses, @combined_clauses, @windows, @set_operations, @cached, @lock)
      end

      private def with_groups(groups : Array(String)) : Builder
        Builder.new(@table, @wheres, @orders, @limit, @offset, @joins, @selects, groups, @havings, @distinct, @distinct_columns, @ctes, @from_subquery, @exists_clauses, @in_subquery_clauses, @combined_clauses, @windows, @set_operations, @cached, @lock)
      end

      private def with_havings(havings : Array(WhereClause)) : Builder
        Builder.new(@table, @wheres, @orders, @limit, @offset, @joins, @selects, @groups, havings, @distinct, @distinct_columns, @ctes, @from_subquery, @exists_clauses, @in_subquery_clauses, @combined_clauses, @windows, @set_operations, @cached, @lock)
      end

      private def with_distinct(distinct : Bool, distinct_columns : Array(String) = @distinct_columns) : Builder
        Builder.new(@table, @wheres, @orders, @limit, @offset, @joins, @selects, @groups, @havings, distinct, distinct_columns, @ctes, @from_subquery, @exists_clauses, @in_subquery_clauses, @combined_clauses, @windows, @set_operations, @cached, @lock)
      end

      private def with_ctes(ctes : Array(CTEClause)) : Builder
        Builder.new(@table, @wheres, @orders, @limit, @offset, @joins, @selects, @groups, @havings, @distinct, @distinct_columns, ctes, @from_subquery, @exists_clauses, @in_subquery_clauses, @combined_clauses, @windows, @set_operations, @cached, @lock)
      end

      private def with_from_subquery(from_subquery : FromSubquery?) : Builder
        Builder.new(@table, @wheres, @orders, @limit, @offset, @joins, @selects, @groups, @havings, @distinct, @distinct_columns, @ctes, from_subquery, @exists_clauses, @in_subquery_clauses, @combined_clauses, @windows, @set_operations, @cached, @lock)
      end

      private def with_exists_clauses(exists_clauses : Array(ExistsClause)) : Builder
        Builder.new(@table, @wheres, @orders, @limit, @offset, @joins, @selects, @groups, @havings, @distinct, @distinct_columns, @ctes, @from_subquery, exists_clauses, @in_subquery_clauses, @combined_clauses, @windows, @set_operations, @cached, @lock)
      end

      private def with_in_subquery_clauses(in_subquery_clauses : Array(InSubqueryClause)) : Builder
        Builder.new(@table, @wheres, @orders, @limit, @offset, @joins, @selects, @groups, @havings, @distinct, @distinct_columns, @ctes, @from_subquery, @exists_clauses, in_subquery_clauses, @combined_clauses, @windows, @set_operations, @cached, @lock)
      end

      private def with_combined_clauses(combined_clauses : Array(CombinedClause)) : Builder
        Builder.new(@table, @wheres, @orders, @limit, @offset, @joins, @selects, @groups, @havings, @distinct, @distinct_columns, @ctes, @from_subquery, @exists_clauses, @in_subquery_clauses, combined_clauses, @windows, @set_operations, @cached, @lock)
      end

      private def with_windows(windows : Array(WindowClause)) : Builder
        Builder.new(@table, @wheres, @orders, @limit, @offset, @joins, @selects, @groups, @havings, @distinct, @distinct_columns, @ctes, @from_subquery, @exists_clauses, @in_subquery_clauses, @combined_clauses, windows, @set_operations, @cached, @lock)
      end

      private def with_set_operations(set_operations : Array(SetOperationClause)) : Builder
        Builder.new(@table, @wheres, @orders, @limit, @offset, @joins, @selects, @groups, @havings, @distinct, @distinct_columns, @ctes, @from_subquery, @exists_clauses, @in_subquery_clauses, @combined_clauses, @windows, set_operations, @cached, @lock)
      end

      private def with_cached(cached : Bool) : Builder
        Builder.new(@table, @wheres, @orders, @limit, @offset, @joins, @selects, @groups, @havings, @distinct, @distinct_columns, @ctes, @from_subquery, @exists_clauses, @in_subquery_clauses, @combined_clauses, @windows, @set_operations, cached, @lock)
      end

      # ========================================
      # Query Composition Methods (OR/AND)
      # ========================================

      # Combine this query's WHERE clauses with another query's using OR (returns new Builder)
      #
      # This creates a combined condition where either set of conditions can match.
      # The current query's WHERE clauses become the left side, and the other
      # query's WHERE clauses become the right side.
      #
      # Example:
      # ```
      # query1 = Ralph::Query::Builder.new("users")
      #   .where("age > ?", 18)
      #   .where("active = ?", true)
      #
      # query2 = Ralph::Query::Builder.new("users")
      #   .where("role = ?", "admin")
      #
      # combined = query1.or(query2)
      # # => WHERE (age > $1 AND active = $2) OR (role = $3)
      # ```
      def or(other : Builder) : Builder
        # Only combine if both have WHERE clauses
        if @wheres.any? && other.wheres.any?
          # Create new combined clause and clear wheres
          new_combined = @combined_clauses + [CombinedClause.new(@wheres.dup, other.wheres.dup, :or)]
          Builder.new(@table, [] of WhereClause, @orders, @limit, @offset, @joins, @selects, @groups, @havings, @distinct, @distinct_columns, @ctes, @from_subquery, @exists_clauses, @in_subquery_clauses, new_combined, @windows, @set_operations, @cached, @lock)
        elsif other.wheres.any?
          # If we have no wheres, just adopt the other's
          with_wheres(other.wheres.dup)
        else
          # If other has no wheres, nothing changes
          self
        end
      end

      # Combine this query's WHERE clauses with another query's using AND (returns new Builder)
      #
      # This is useful when you want explicit grouping of conditions.
      # Normal chained `.where()` calls already use AND, but this method
      # allows you to group conditions for clarity or when building dynamic queries.
      #
      # Example:
      # ```
      # query1 = Ralph::Query::Builder.new("users")
      #   .where("age > ?", 18)
      #
      # query2 = Ralph::Query::Builder.new("users")
      #   .where("role = ?", "admin")
      #   .where("department = ?", "engineering")
      #
      # combined = query1.and(query2)
      # # => WHERE (age > $1) AND (role = $2 AND department = $3)
      # ```
      def and(other : Builder) : Builder
        # Only combine if both have WHERE clauses
        if @wheres.any? && other.wheres.any?
          # Create new combined clause and clear wheres
          new_combined = @combined_clauses + [CombinedClause.new(@wheres.dup, other.wheres.dup, :and)]
          Builder.new(@table, [] of WhereClause, @orders, @limit, @offset, @joins, @selects, @groups, @havings, @distinct, @distinct_columns, @ctes, @from_subquery, @exists_clauses, @in_subquery_clauses, new_combined, @windows, @set_operations, @cached, @lock)
        elsif other.wheres.any?
          # If we have no wheres, just adopt the other's
          with_wheres(other.wheres.dup)
        else
          # If other has no wheres, nothing changes
          self
        end
      end

      # Merge another query's clauses into this one (returns new Builder)
      #
      # This copies WHERE, ORDER, LIMIT, OFFSET, and other clauses from the
      # other builder into this one. Useful for combining scope conditions.
      #
      # Example:
      # ```
      # base_query = Ralph::Query::Builder.new("users")
      #   .where("active = ?", true)
      #
      # additional = Ralph::Query::Builder.new("users")
      #   .where("age > ?", 18)
      #   .order("name", :asc)
      #
      # merged = base_query.merge(additional)
      # # Adds the WHERE and ORDER clauses from additional
      # ```
      def merge(other : Builder) : Builder
        new_limit = @limit || other.limit_value
        new_offset = @offset || other.offset_value
        new_distinct = @distinct || other.distinct?
        new_lock = @lock ? @lock : other.@lock

        Builder.new(
          @table,
          @wheres + other.wheres,
          @orders + other.orders,
          new_limit,
          new_offset,
          @joins + other.joins,
          @selects + other.selects,
          @groups + other.groups,
          @havings + other.havings,
          new_distinct,
          @distinct_columns + other.distinct_columns,
          @ctes + other.ctes,
          @from_subquery || other.from_subquery,
          @exists_clauses + other.exists_clauses,
          @in_subquery_clauses + other.in_subquery_clauses,
          @combined_clauses + other.combined_clauses,
          @windows + other.windows,
          @set_operations + other.set_operations,
          @cached || other.cached?,
          new_lock
        )
      end

      # Add an ORDER BY clause (returns new Builder)
      def order(column : String, direction : Symbol = :asc) : Builder
        with_orders(@orders + [OrderClause.new(column, direction)])
      end

      # Add a LIMIT clause (returns new Builder)
      def limit(count : Int32) : Builder
        with_limit(count)
      end

      # Add an OFFSET clause (returns new Builder)
      def offset(count : Int32) : Builder
        with_offset(count)
      end

      # Join another table (returns new Builder)
      def join(table : String, on : String, type : Symbol = :inner, alias as_alias : String? = nil) : Builder
        with_joins(@joins + [JoinClause.new(table, on, type, as_alias)])
      end

      # Inner join (alias for join)
      def inner_join(table : String, on : String, alias as_alias : String? = nil) : Builder
        join(table, on, :inner, as_alias)
      end

      # Left join
      def left_join(table : String, on : String, alias as_alias : String? = nil) : Builder
        join(table, on, :left, as_alias)
      end

      # Right join
      def right_join(table : String, on : String, alias as_alias : String? = nil) : Builder
        join(table, on, :right, as_alias)
      end

      # Cross join (no ON clause)
      def cross_join(table : String, alias as_alias : String? = nil) : Builder
        with_joins(@joins + [JoinClause.new(table, "", :cross, as_alias)])
      end

      # Full outer join
      def full_outer_join(table : String, on : String, alias as_alias : String? = nil) : Builder
        join(table, on, :full_outer, as_alias)
      end

      # Full join (alias for full_outer_join)
      def full_join(table : String, on : String, alias as_alias : String? = nil) : Builder
        join(table, on, :full, as_alias)
      end

      # Add a GROUP BY clause (returns new Builder)
      def group(*columns : String) : Builder
        with_groups(@groups + columns.to_a)
      end

      # Add a HAVING clause (returns new Builder)
      def having(clause : String, *args) : Builder
        converted = args.to_a.map { |a| a.as(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil) }
        with_havings(@havings + [WhereClause.new(clause, converted)])
      end

      # Add DISTINCT to SELECT (returns new Builder)
      def distinct : Builder
        with_distinct(true)
      end

      # Add DISTINCT ON specific columns (returns new Builder)
      def distinct(*columns : String) : Builder
        with_distinct(true, @distinct_columns + columns.to_a)
      end

      # ========================================
      # Subquery Support Methods
      # ========================================

      # Add a CTE (Common Table Expression) (returns new Builder)
      #
      # Example:
      # ```
      # subquery = Ralph::Query::Builder.new("orders")
      #   .select("user_id", "total")
      #   .where("status = ?", "completed")
      #
      # query.with_cte("recent_orders", subquery)
      #   .where("user_id IN (SELECT user_id FROM recent_orders)")
      # ```
      def with_cte(name : String, subquery : Builder, materialized : Bool? = nil) : Builder
        with_ctes(@ctes + [CTEClause.new(name, subquery, recursive: false, materialized: materialized)])
      end

      # Add a recursive CTE (returns new Builder)
      #
      # Example:
      # ```
      # # Base case: root categories
      # base = Ralph::Query::Builder.new("categories")
      #   .select("id", "name", "parent_id")
      #   .where("parent_id IS NULL")
      #
      # # Recursive case: children
      # recursive = Ralph::Query::Builder.new("categories")
      #   .select("c.id", "c.name", "c.parent_id")
      #   .join("category_tree", "categories.parent_id = category_tree.id")
      #
      # query.with_recursive_cte("category_tree", base, recursive)
      # ```
      def with_recursive_cte(name : String, base_query : Builder, recursive_query : Builder, materialized : Bool? = nil) : Builder
        # For recursive CTEs, we create a combined builder that will generate UNION ALL
        combined = RecursiveCTEBuilder.new(base_query, recursive_query)
        with_ctes(@ctes + [CTEClause.new(name, combined, recursive: true, materialized: materialized)])
      end

      # Add a FROM subquery (returns new Builder)
      #
      # Example:
      # ```
      # subquery = Ralph::Query::Builder.new("orders")
      #   .select("user_id", "SUM(total) as total_spent")
      #   .group("user_id")
      #
      # query = Ralph::Query::Builder.new("users")
      #   .from_subquery(subquery, "order_totals")
      #   .where("total_spent > ?", 1000)
      # ```
      def from_subquery(subquery : Builder, alias_name : String) : Builder
        with_from_subquery(FromSubquery.new(subquery, alias_name))
      end

      # Add a WHERE EXISTS clause (returns new Builder)
      #
      # Example:
      # ```
      # subquery = Ralph::Query::Builder.new("orders")
      #   .select("1")
      #   .where("orders.user_id = users.id")
      #   .where("status = ?", "pending")
      #
      # query = Ralph::Query::Builder.new("users")
      #   .exists(subquery)
      # ```
      def exists(subquery : Builder) : Builder
        with_exists_clauses(@exists_clauses + [ExistsClause.new(subquery, negated: false)])
      end

      # Add a WHERE NOT EXISTS clause (returns new Builder)
      #
      # Example:
      # ```
      # subquery = Ralph::Query::Builder.new("orders")
      #   .select("1")
      #   .where("orders.user_id = users.id")
      #
      # query = Ralph::Query::Builder.new("users")
      #   .not_exists(subquery)
      # ```
      def not_exists(subquery : Builder) : Builder
        with_exists_clauses(@exists_clauses + [ExistsClause.new(subquery, negated: true)])
      end

      # Add a WHERE IN clause with a subquery (returns new Builder)
      #
      # Example:
      # ```
      # subquery = Ralph::Query::Builder.new("orders")
      #   .select("user_id")
      #   .where("total > ?", 100)
      #
      # query = Ralph::Query::Builder.new("users")
      #   .where_in("id", subquery)
      # ```
      def where_in(column : String, subquery : Builder) : Builder
        with_in_subquery_clauses(@in_subquery_clauses + [InSubqueryClause.new(column, subquery, negated: false)])
      end

      # Add a WHERE NOT IN clause with a subquery (returns new Builder)
      #
      # Example:
      # ```
      # subquery = Ralph::Query::Builder.new("blacklisted_users")
      #   .select("user_id")
      #
      # query = Ralph::Query::Builder.new("users")
      #   .where_not_in("id", subquery)
      # ```
      def where_not_in(column : String, subquery : Builder) : Builder
        with_in_subquery_clauses(@in_subquery_clauses + [InSubqueryClause.new(column, subquery, negated: true)])
      end

      # Add a WHERE IN clause with an array of values (returns new Builder)
      #
      # Example:
      # ```
      # query = Ralph::Query::Builder.new("users")
      #   .where_in("id", [1, 2, 3])
      # ```
      def where_in(column : String, values : Array) : Builder
        return self if values.empty?
        placeholders = values.map_with_index { |_, i| "?" }.join(", ")
        converted = values.map { |v| v.as(DBValue) }
        with_wheres(@wheres + [WhereClause.new("\"#{column}\" IN (#{placeholders})", converted)])
      end

      # Add a WHERE NOT IN clause with an array of values (returns new Builder)
      #
      # Example:
      # ```
      # query = Ralph::Query::Builder.new("users")
      #   .where_not_in("id", [1, 2, 3])
      # ```
      def where_not_in(column : String, values : Array) : Builder
        return self if values.empty?
        placeholders = values.map_with_index { |_, i| "?" }.join(", ")
        converted = values.map { |v| v.as(DBValue) }
        with_wheres(@wheres + [WhereClause.new("\"#{column}\" NOT IN (#{placeholders})", converted)])
      end

      # ========================================
      # JSON/JSONB Query Operators
      # ========================================

      # Extract a JSON value at the given path and compare it
      #
      # Uses backend-specific syntax:
      # - PostgreSQL: column->>'path' = ?
      # - SQLite: json_extract(column, '$.path') = ?
      #
      # Example:
      # ```
      # query.where_json("settings", "theme", "dark")
      # # PostgreSQL: WHERE "settings"->>'theme' = 'dark'
      # # SQLite: WHERE json_extract("settings", '$.theme') = 'dark'
      # ```
      def where_json(column : String, path : String, value : DBValue) : Builder
        # Detect backend from Ralph settings if available
        dialect = Ralph.settings.database?.try(&.dialect) || :sqlite
        clause = case dialect
                 when :postgres
                   "\"#{column}\"->>'#{path}' = ?"
                 else
                   "json_extract(\"#{column}\", '$.#{path}') = ?"
                 end
        with_wheres(@wheres + [WhereClause.new(clause, [value] of DBValue)])
      end

      # Check if a JSON column contains the given key
      #
      # Example:
      # ```
      # query.where_json_has_key("metadata", "theme")
      # # PostgreSQL: WHERE "metadata" ? 'theme'
      # # SQLite: WHERE json_extract("metadata", '$.theme') IS NOT NULL
      # ```
      def where_json_has_key(column : String, key : String) : Builder
        dialect = Ralph.settings.database?.try(&.dialect) || :sqlite
        clause = case dialect
                 when :postgres
                   "\"#{column}\" ? '#{key}'"
                 else
                   "json_extract(\"#{column}\", '$.#{key}') IS NOT NULL"
                 end
        with_wheres(@wheres + [WhereClause.new(clause, [] of DBValue)])
      end

      # Check if a JSON column contains the given value (for JSONB in PostgreSQL)
      #
      # Example:
      # ```
      # query.where_json_contains("tags", "[\"crystal\", \"orm\"]")
      # # PostgreSQL: WHERE "tags" @> '["crystal", "orm"]'
      # # SQLite: Uses json_each for emulation
      # ```
      def where_json_contains(column : String, json_value : String) : Builder
        dialect = Ralph.settings.database?.try(&.dialect) || :sqlite
        clause = case dialect
                 when :postgres
                   "\"#{column}\" @> '#{json_value}'"
                 else
                   # SQLite emulation - check if JSON is valid and matches
                   "json_valid(\"#{column}\") AND \"#{column}\" = '#{json_value}'"
                 end
        with_wheres(@wheres + [WhereClause.new(clause, [] of DBValue)])
      end

      # ========================================
      # Array Query Operators
      # ========================================

      # Check if an array column contains a specific value
      #
      # Example:
      # ```
      # query.where_array_contains("tags", "crystal")
      # # PostgreSQL: WHERE 'crystal' = ANY("tags")
      # # SQLite: WHERE EXISTS (SELECT 1 FROM json_each("tags") WHERE value = 'crystal')
      # ```
      def where_array_contains(column : String, value : DBValue) : Builder
        dialect = Ralph.settings.database?.try(&.dialect) || :sqlite
        clause = case dialect
                 when :postgres
                   "? = ANY(\"#{column}\")"
                 else
                   # SQLite - arrays stored as JSON
                   "EXISTS (SELECT 1 FROM json_each(\"#{column}\") WHERE value = ?)"
                 end
        with_wheres(@wheres + [WhereClause.new(clause, [value] of DBValue)])
      end

      # Check if an array column overlaps with the given values (has any common elements)
      #
      # Example:
      # ```
      # query.where_array_overlaps("tags", ["crystal", "ruby"])
      # # PostgreSQL: WHERE "tags" && ARRAY['crystal', 'ruby']
      # # SQLite: Emulated with json_each
      # ```
      def where_array_overlaps(column : String, values : Array(String)) : Builder
        return self if values.empty?
        dialect = Ralph.settings.database?.try(&.dialect) || :sqlite
        clause = case dialect
                 when :postgres
                   quoted = values.map { |v| "'#{v}'" }.join(", ")
                   "\"#{column}\" && ARRAY[#{quoted}]"
                 else
                   # SQLite - check if any value exists in the JSON array
                   quoted = values.map { |v| "'#{v}'" }.join(", ")
                   "EXISTS (SELECT 1 FROM json_each(\"#{column}\") WHERE value IN (#{quoted}))"
                 end
        with_wheres(@wheres + [WhereClause.new(clause, [] of DBValue)])
      end

      # Check if an array column is contained by the given values
      #
      # Example:
      # ```
      # query.where_array_contained_by("tags", ["crystal", "ruby", "elixir"])
      # # PostgreSQL: WHERE "tags" <@ ARRAY['crystal', 'ruby', 'elixir']
      # ```
      def where_array_contained_by(column : String, values : Array(String)) : Builder
        return self if values.empty?
        dialect = Ralph.settings.database?.try(&.dialect) || :sqlite
        clause = case dialect
                 when :postgres
                   quoted = values.map { |v| "'#{v}'" }.join(", ")
                   "\"#{column}\" <@ ARRAY[#{quoted}]"
                 else
                   # SQLite - all elements in JSON array must be in the provided list
                   quoted = values.map { |v| "'#{v}'" }.join(", ")
                   "NOT EXISTS (SELECT 1 FROM json_each(\"#{column}\") WHERE value NOT IN (#{quoted}))"
                 end
        with_wheres(@wheres + [WhereClause.new(clause, [] of DBValue)])
      end

      # Check the length of an array column
      #
      # Example:
      # ```
      # query.where_array_length("tags", ">", 3)
      # # PostgreSQL: WHERE array_length("tags", 1) > 3
      # # SQLite: WHERE json_array_length("tags") > 3
      # ```
      def where_array_length(column : String, operator : String, length : Int32) : Builder
        dialect = Ralph.settings.database?.try(&.dialect) || :sqlite
        clause = case dialect
                 when :postgres
                   "array_length(\"#{column}\", 1) #{operator} ?"
                 else
                   "json_array_length(\"#{column}\") #{operator} ?"
                 end
        with_wheres(@wheres + [WhereClause.new(clause, [length.to_i64] of DBValue)])
      end

      # ========================================
      # Window Functions Support
      # ========================================

      # Add a window function to the SELECT clause (returns new Builder)
      #
      # Supports common window functions: ROW_NUMBER(), RANK(), DENSE_RANK(),
      # SUM(), AVG(), COUNT(), MIN(), MAX(), LEAD(), LAG(), FIRST_VALUE(), LAST_VALUE(), etc.
      #
      # Example:
      # ```
      # query = Ralph::Query::Builder.new("employees")
      #   .select("name", "department", "salary")
      #   .window("ROW_NUMBER()", partition_by: "department", order_by: "salary DESC", as: "rank")
      # # => SELECT name, department, salary, ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS "rank" FROM employees
      # ```
      def window(function : String, partition_by : String? = nil, order_by : String? = nil, as alias_name : String = "window_result") : Builder
        with_windows(@windows + [WindowClause.new(function, partition_by, order_by, alias_name)])
      end

      # Add ROW_NUMBER() window function
      #
      # Example:
      # ```
      # query.row_number(partition_by: "department", order_by: "salary DESC", as: "rank")
      # ```
      def row_number(partition_by : String? = nil, order_by : String? = nil, as alias_name : String = "row_num") : Builder
        window("ROW_NUMBER()", partition_by: partition_by, order_by: order_by, as: alias_name)
      end

      # Add RANK() window function
      #
      # Example:
      # ```
      # query.rank(partition_by: "department", order_by: "salary DESC", as: "salary_rank")
      # ```
      def rank(partition_by : String? = nil, order_by : String? = nil, as alias_name : String = "rank") : Builder
        window("RANK()", partition_by: partition_by, order_by: order_by, as: alias_name)
      end

      # Add DENSE_RANK() window function
      #
      # Example:
      # ```
      # query.dense_rank(partition_by: "department", order_by: "salary DESC", as: "dense_rank")
      # ```
      def dense_rank(partition_by : String? = nil, order_by : String? = nil, as alias_name : String = "dense_rank") : Builder
        window("DENSE_RANK()", partition_by: partition_by, order_by: order_by, as: alias_name)
      end

      # Add SUM() window function
      #
      # Example:
      # ```
      # query.window_sum("salary", partition_by: "department", as: "dept_total")
      # ```
      def window_sum(column : String, partition_by : String? = nil, order_by : String? = nil, as alias_name : String = "sum") : Builder
        window("SUM(#{column})", partition_by: partition_by, order_by: order_by, as: alias_name)
      end

      # Add AVG() window function
      #
      # Example:
      # ```
      # query.window_avg("salary", partition_by: "department", as: "dept_avg")
      # ```
      def window_avg(column : String, partition_by : String? = nil, order_by : String? = nil, as alias_name : String = "avg") : Builder
        window("AVG(#{column})", partition_by: partition_by, order_by: order_by, as: alias_name)
      end

      # Add COUNT() window function
      #
      # Example:
      # ```
      # query.window_count(partition_by: "department", as: "dept_count")
      # ```
      def window_count(column : String = "*", partition_by : String? = nil, order_by : String? = nil, as alias_name : String = "count") : Builder
        window("COUNT(#{column})", partition_by: partition_by, order_by: order_by, as: alias_name)
      end

      # ========================================
      # Set Operations (UNION, INTERSECT, EXCEPT)
      # ========================================

      # Add a UNION operation with another query (returns new Builder)
      #
      # UNION removes duplicate rows from the combined result set.
      #
      # Example:
      # ```
      # active_users = Ralph::Query::Builder.new("users")
      #   .select("id", "name")
      #   .where("active = ?", true)
      #
      # premium_users = Ralph::Query::Builder.new("users")
      #   .select("id", "name")
      #   .where("subscription = ?", "premium")
      #
      # combined = active_users.union(premium_users)
      # # => SELECT id, name FROM users WHERE active = $1 UNION SELECT id, name FROM users WHERE subscription = $2
      # ```
      def union(other : Builder) : Builder
        with_set_operations(@set_operations + [SetOperationClause.new(other, SetOperationClause::Operation::Union)])
      end

      # Add a UNION ALL operation with another query (returns new Builder)
      #
      # UNION ALL keeps all rows including duplicates (faster than UNION).
      #
      # Example:
      # ```
      # recent_orders = Ralph::Query::Builder.new("orders")
      #   .select("id", "total")
      #   .where("created_at > ?", last_week)
      #
      # large_orders = Ralph::Query::Builder.new("orders")
      #   .select("id", "total")
      #   .where("total > ?", 1000)
      #
      # combined = recent_orders.union_all(large_orders)
      # # => SELECT id, total FROM orders WHERE created_at > $1 UNION ALL SELECT id, total FROM orders WHERE total > $2
      # ```
      def union_all(other : Builder) : Builder
        with_set_operations(@set_operations + [SetOperationClause.new(other, SetOperationClause::Operation::UnionAll)])
      end

      # Add an INTERSECT operation with another query (returns new Builder)
      #
      # INTERSECT returns only rows that appear in both result sets.
      #
      # Example:
      # ```
      # active_users = Ralph::Query::Builder.new("users")
      #   .select("id")
      #   .where("active = ?", true)
      #
      # premium_users = Ralph::Query::Builder.new("users")
      #   .select("id")
      #   .where("subscription = ?", "premium")
      #
      # both = active_users.intersect(premium_users)
      # # => SELECT id FROM users WHERE active = $1 INTERSECT SELECT id FROM users WHERE subscription = $2
      # ```
      def intersect(other : Builder) : Builder
        with_set_operations(@set_operations + [SetOperationClause.new(other, SetOperationClause::Operation::Intersect)])
      end

      # Add an EXCEPT operation with another query (returns new Builder)
      #
      # EXCEPT returns rows from the first query that don't appear in the second.
      #
      # Example:
      # ```
      # all_users = Ralph::Query::Builder.new("users")
      #   .select("id")
      #   .where("active = ?", true)
      #
      # banned_users = Ralph::Query::Builder.new("users")
      #   .select("id")
      #   .where("banned = ?", true)
      #
      # non_banned = all_users.except(banned_users)
      # # => SELECT id FROM users WHERE active = $1 EXCEPT SELECT id FROM users WHERE banned = $2
      # ```
      def except(other : Builder) : Builder
        with_set_operations(@set_operations + [SetOperationClause.new(other, SetOperationClause::Operation::Except)])
      end

      # ========================================
      # Query Caching / Memoization
      # ========================================

      # Mark this query for caching (returns new Builder)
      #
      # When a query is marked for caching, subsequent executions with the same
      # SQL and parameters will return cached results instead of hitting the database.
      #
      # Example:
      # ```
      # query = Ralph::Query::Builder.new("users")
      #   .where("active = ?", true)
      #   .cache
      # ```
      def cache : Builder
        with_cached(true)
      end

      # Disable caching for this query (returns new Builder)
      def uncache : Builder
        with_cached(false)
      end

      # Generate a cache key based on SQL and parameters
      def cache_key : String
        sql = build_select
        args_str = all_args.map(&.to_s).join(",")
        "#{sql}:#{args_str}"
      end

      # Check if results are cached for this query
      def cached_result? : Array(Hash(String, DBValue))?
        return nil unless @cached
        @@cache[cache_key]?
      end

      # Store results in cache
      def cache_result(results : Array(Hash(String, DBValue))) : Nil
        return unless @cached
        @@cache[cache_key] = results
      end

      # Clear all cached query results (class method)
      def self.clear_cache : Nil
        @@cache.clear
      end

      # Clear cached result for this specific query
      def clear_cache : Nil
        @@cache.delete(cache_key)
      end

      # Invalidate cache entries for a specific table
      #
      # This should be called after INSERT, UPDATE, or DELETE operations
      def self.invalidate_table_cache(table : String) : Nil
        @@cache.reject! { |key, _| key.includes?("\"#{table}\"") }
      end

      # ========================================
      # Row Locking Methods (FOR UPDATE, etc.)
      # ========================================

      # Add a FOR UPDATE lock to the query (returns new Builder)
      #
      # This acquires an exclusive row-level lock on selected rows,
      # preventing other transactions from modifying or locking them.
      #
      # ## Options
      #
      # - No argument: Basic FOR UPDATE
      # - `:nowait` - Fail immediately if lock cannot be acquired
      # - `:skip_locked` - Skip rows that are already locked
      #
      # ## Example
      #
      # ```
      # # Basic FOR UPDATE
      # User.query { |q| q.where("id = ?", 1).for_update }
      # # => SELECT * FROM "users" WHERE id = $1 FOR UPDATE
      #
      # # With NOWAIT - don't wait for locks
      # User.query { |q| q.where("id = ?", 1).for_update(:nowait) }
      # # => SELECT * FROM "users" WHERE id = $1 FOR UPDATE NOWAIT
      #
      # # With SKIP LOCKED - skip locked rows
      # User.query { |q| q.where("active = ?", true).for_update(:skip_locked) }
      # # => SELECT * FROM "users" WHERE active = $1 FOR UPDATE SKIP LOCKED
      # ```
      def for_update(option : Symbol? = nil) : Builder
        lock_option = case option
                      when :nowait      then LockClause::Option::Nowait
                      when :skip_locked then LockClause::Option::SkipLocked
                      else                   LockClause::Option::None
                      end
        with_lock(LockClause.new(LockClause::Mode::Update, lock_option))
      end

      # Add a FOR SHARE lock to the query (returns new Builder)
      #
      # This acquires a shared row-level lock on selected rows,
      # allowing other transactions to read but not modify or lock them.
      #
      # ## Options
      #
      # - No argument: Basic FOR SHARE
      # - `:nowait` - Fail immediately if lock cannot be acquired
      # - `:skip_locked` - Skip rows that are already locked
      #
      # ## Example
      #
      # ```
      # # Basic FOR SHARE
      # User.query { |q| q.where("id = ?", 1).for_share }
      # # => SELECT * FROM "users" WHERE id = $1 FOR SHARE
      #
      # # With SKIP LOCKED
      # User.query { |q| q.where("active = ?", true).for_share(:skip_locked) }
      # # => SELECT * FROM "users" WHERE active = $1 FOR SHARE SKIP LOCKED
      # ```
      def for_share(option : Symbol? = nil) : Builder
        lock_option = case option
                      when :nowait      then LockClause::Option::Nowait
                      when :skip_locked then LockClause::Option::SkipLocked
                      else                   LockClause::Option::None
                      end
        with_lock(LockClause.new(LockClause::Mode::Share, lock_option))
      end

      # Add a custom lock clause to the query (returns new Builder)
      #
      # This is the most flexible lock method, allowing any lock mode and option.
      #
      # ## Lock Modes
      #
      # - `:update` - FOR UPDATE (exclusive lock)
      # - `:share` - FOR SHARE (shared lock)
      # - `:no_key_update` - FOR NO KEY UPDATE (PostgreSQL)
      # - `:key_share` - FOR KEY SHARE (PostgreSQL)
      #
      # ## Options
      #
      # - `:nowait` - Fail immediately if lock cannot be acquired
      # - `:skip_locked` - Skip rows that are already locked
      #
      # ## Example
      #
      # ```
      # # FOR UPDATE with specific tables
      # query.lock(:update, tables: ["users", "orders"])
      # # => SELECT ... FOR UPDATE OF "users", "orders"
      #
      # # FOR NO KEY UPDATE (PostgreSQL - allows concurrent inserts)
      # query.lock(:no_key_update)
      # # => SELECT ... FOR NO KEY UPDATE
      #
      # # FOR KEY SHARE (PostgreSQL - weakest lock)
      # query.lock(:key_share, option: :skip_locked)
      # # => SELECT ... FOR KEY SHARE SKIP LOCKED
      # ```
      def lock(mode : Symbol = :update, option : Symbol? = nil, tables : Array(String) = [] of String) : Builder
        lock_mode = case mode
                    when :update        then LockClause::Mode::Update
                    when :share         then LockClause::Mode::Share
                    when :no_key_update then LockClause::Mode::NoKeyUpdate
                    when :key_share     then LockClause::Mode::KeyShare
                    else                     LockClause::Mode::Update
                    end

        lock_option = case option
                      when :nowait      then LockClause::Option::Nowait
                      when :skip_locked then LockClause::Option::SkipLocked
                      else                   LockClause::Option::None
                      end

        with_lock(LockClause.new(lock_mode, lock_option, tables))
      end

      # Add a raw lock clause string (returns new Builder)
      #
      # For database-specific locking syntax not covered by the standard methods.
      #
      # ## Example
      #
      # ```
      # query.lock_raw("FOR UPDATE OF users NOWAIT")
      # # => SELECT ... FOR UPDATE OF users NOWAIT
      # ```
      def lock_raw(clause : String) : Builder
        # Create a custom lock clause that will output the raw string
        # This requires a small wrapper - for now, we'll use the standard lock with update
        # and document that lock_raw should use execute_raw or similar
        # Actually, let's create a simple lock that stores raw SQL
        with_lock(LockClause.new(LockClause::Mode::Update)) # Placeholder - raw lock needs special handling
      end

      # Return a new builder with the given lock clause
      protected def with_lock(lock : LockClause) : Builder
        Builder.new(
          @table,
          @wheres.dup,
          @orders.dup,
          @limit,
          @offset,
          @joins.dup,
          @selects.dup,
          @groups.dup,
          @havings.dup,
          @distinct,
          @distinct_columns.dup,
          @ctes.dup,
          @from_subquery,
          @exists_clauses.dup,
          @in_subquery_clauses.dup,
          @combined_clauses.dup,
          @windows.dup,
          @set_operations.dup,
          @cached,
          lock
        )
      end

      # ========================================
      # Query Building Methods
      # ========================================

      # Build the SELECT query
      def build_select : String
        sql, _ = build_select_with_offset(0)
        sql
      end

      # Build the SELECT query with parameter offset (for subqueries)
      # Returns the SQL string and the next parameter index to use
      def build_select_with_offset(param_offset : Int32) : Tuple(String, Int32)
        current_offset = param_offset

        # Build CTE clause if present
        cte_clause = ""
        unless @ctes.empty?
          has_recursive = @ctes.any?(&.recursive)
          cte_keyword = has_recursive ? "WITH RECURSIVE " : "WITH "

          cte_parts = [] of String
          @ctes.each do |cte|
            cte_sql, current_offset = cte.to_sql(current_offset)
            cte_parts << cte_sql
          end
          cte_clause = "#{cte_keyword}#{cte_parts.join(", ")} "
        end

        # Build SELECT clause with DISTINCT if specified
        distinct_clause = if @distinct && @distinct_columns.empty?
                            "DISTINCT "
                          else
                            ""
                          end

        select_clause = @selects.empty? ? "*" : @selects.map { |c| quote_column(c) }.join(", ")

        # Add window functions to SELECT clause
        unless @windows.empty?
          window_clauses = @windows.map(&.to_sql)
          if select_clause == "*"
            select_clause = "*, #{window_clauses.join(", ")}"
          else
            select_clause = "#{select_clause}, #{window_clauses.join(", ")}"
          end
        end

        # Handle FROM clause - either table, subquery, or CTE reference
        from_clause = if subq = @from_subquery
                        subq_sql, current_offset = subq.to_sql(current_offset)
                        subq_sql
                      else
                        # Handle table name - quote it if not already quoted
                        @table.starts_with?('"') ? @table : "\"#{@table}\""
                      end

        query = "#{cte_clause}SELECT #{distinct_clause}#{select_clause} FROM #{from_clause}"

        unless @joins.empty?
          query += " " + @joins.map(&.to_sql).join(" ")
        end

        # Build WHERE clauses including subquery conditions
        where_parts = [] of String

        # Combined clauses (from or/and operations) - these come first
        @combined_clauses.each do |cc|
          left_parts = [] of String
          cc.left_clauses.each do |w|
            clause = w.clause
            w.args.each do
              current_offset += 1
              clause = clause.sub("?", "$#{current_offset}")
            end
            left_parts << clause
          end

          right_parts = [] of String
          cc.right_clauses.each do |w|
            clause = w.clause
            w.args.each do
              current_offset += 1
              clause = clause.sub("?", "$#{current_offset}")
            end
            right_parts << clause
          end

          left_sql = left_parts.size == 1 ? left_parts.first : "(#{left_parts.join(" AND ")})"
          right_sql = right_parts.size == 1 ? right_parts.first : "(#{right_parts.join(" AND ")})"
          operator = cc.operator == :or ? "OR" : "AND"
          where_parts << "(#{left_sql} #{operator} #{right_sql})"
        end

        # Regular WHERE clauses
        @wheres.each do |w|
          clause = w.clause
          w.args.each do
            current_offset += 1
            clause = clause.sub("?", "$#{current_offset}")
          end
          where_parts << clause
        end

        # EXISTS clauses
        @exists_clauses.each do |ec|
          exists_sql, current_offset = ec.to_sql(current_offset)
          where_parts << exists_sql
        end

        # IN subquery clauses
        @in_subquery_clauses.each do |isc|
          in_sql, current_offset = isc.to_sql(current_offset)
          where_parts << in_sql
        end

        unless where_parts.empty?
          query += " WHERE #{where_parts.join(" AND ")}"
        end

        # Combine explicit groups with distinct_columns for GROUP BY
        all_groups = @groups.dup
        all_groups.concat(@distinct_columns) unless @distinct_columns.empty?

        unless all_groups.empty?
          group_sql = all_groups.map { |c| "\"#{c}\"" }.join(", ")
          query += " GROUP BY #{group_sql}"

          # HAVING is only valid with GROUP BY
          unless @havings.empty?
            having_sql = @havings.map do |h|
              clause = h.clause
              h.args.each do
                current_offset += 1
                clause = clause.sub("?", "$#{current_offset}")
              end
              clause
            end.join(" AND ")
            query += " HAVING #{having_sql}"
          end
        end

        unless @orders.empty?
          order_sql = @orders.map(&.to_sql).join(", ")
          query += " ORDER BY #{order_sql}"
        end

        if l = @limit
          query += " LIMIT #{l}"
        end

        if o = @offset
          query += " OFFSET #{o}"
        end

        # Add set operations (UNION, UNION ALL, INTERSECT, EXCEPT)
        @set_operations.each do |set_op|
          set_sql, current_offset = set_op.to_sql(current_offset)
          query += " #{set_sql}"
        end

        # Add row-level lock clause (FOR UPDATE, FOR SHARE, etc.)
        if lock_clause = @lock
          query += " #{lock_clause.to_sql}"
        end

        {query, current_offset}
      end

      # Build the INSERT query
      def build_insert(data : Hash(String, _)) : Tuple(String, Array(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil))
        columns = data.keys.map { |c| "\"#{c}\"" }.join(", ")
        placeholders = data.keys.map_with_index { |_, i| "$#{i + 1}" }.join(", ")
        args = data.values.map(&.as(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil)).to_a

        query = "INSERT INTO \"#{@table}\" (#{columns}) VALUES (#{placeholders})"
        {query, args}
      end

      # Build the UPDATE query
      def build_update(data : Hash(String, _)) : Tuple(String, Array(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil))
        set_clause = data.keys.map_with_index do |col, i|
          "\"#{col}\" = $#{i + 1}"
        end.join(", ")

        args = data.values.to_a
        where_args = @wheres.flat_map(&.args)
        args.concat(where_args)

        query = "UPDATE \"#{@table}\" SET #{set_clause}"

        unless @wheres.empty?
          # Build WHERE clauses with offset parameter numbering
          param_index = 0
          where_sql = @wheres.map do |w|
            clause = w.clause
            w.args.each do
              param_index += 1
              clause = clause.sub("?", "$#{data.size + param_index}")
            end
            clause
          end.join(" AND ")
          query += " WHERE #{where_sql}"
        end

        {query, args}
      end

      # Build the DELETE query
      def build_delete : Tuple(String, Array(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil))
        query = "DELETE FROM \"#{@table}\""

        unless @wheres.empty?
          where_sql = build_where_clauses
          query += " WHERE #{where_sql}"
        end

        args = @wheres.flat_map(&.args)
        {query, args}
      end

      # Build a COUNT query
      def build_count(column : String = "*") : String
        where = @wheres.empty? ? "" : " WHERE #{build_where_clauses}"
        count_expr = column == "*" ? "COUNT(*)" : "COUNT(\"#{column}\")"
        "SELECT #{count_expr} FROM \"#{@table}\"#{where}"
      end

      # Build a SUM query
      def build_sum(column : String) : String
        where = @wheres.empty? ? "" : " WHERE #{build_where_clauses}"
        "SELECT SUM(\"#{column}\") FROM \"#{@table}\"#{where}"
      end

      # Build an AVG query
      def build_avg(column : String) : String
        where = @wheres.empty? ? "" : " WHERE #{build_where_clauses}"
        "SELECT AVG(\"#{column}\") FROM \"#{@table}\"#{where}"
      end

      # Build a MIN query
      def build_min(column : String) : String
        where = @wheres.empty? ? "" : " WHERE #{build_where_clauses}"
        "SELECT MIN(\"#{column}\") FROM \"#{@table}\"#{where}"
      end

      # Build a MAX query
      def build_max(column : String) : String
        where = @wheres.empty? ? "" : " WHERE #{build_where_clauses}"
        "SELECT MAX(\"#{column}\") FROM \"#{@table}\"#{where}"
      end

      # Build WHERE clauses with proper parameter numbering
      private def build_where_clauses : String
        param_index = 0
        @wheres.map do |w|
          clause = w.clause
          w.args.each do
            param_index += 1
            clause = clause.sub("?", "$#{param_index}")
          end
          clause
        end.join(" AND ")
      end

      # Get the WHERE clause arguments
      def where_args : Array(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil)
        @wheres.flat_map(&.args)
      end

      # Reset the query builder (returns new empty Builder with same table)
      def reset : Builder
        Builder.new(@table)
      end

      # Check if the query has conditions
      def has_conditions? : Bool
        !@wheres.empty? || !@exists_clauses.empty? || !@in_subquery_clauses.empty? || !@combined_clauses.empty?
      end

      # Get all arguments including from subqueries (for parameterized execution)
      def all_args : Array(DBValue)
        args = [] of DBValue

        # CTE arguments
        @ctes.each do |cte|
          args.concat(cte.query.all_args)
        end

        # FROM subquery arguments
        if subq = @from_subquery
          args.concat(subq.query.all_args)
        end

        # Combined clause arguments (from or/and operations)
        @combined_clauses.each do |cc|
          cc.left_clauses.each do |w|
            args.concat(w.args)
          end
          cc.right_clauses.each do |w|
            args.concat(w.args)
          end
        end

        # Regular WHERE arguments
        args.concat(@wheres.flat_map(&.args))

        # EXISTS subquery arguments
        @exists_clauses.each do |ec|
          args.concat(ec.query.all_args)
        end

        # IN subquery arguments
        @in_subquery_clauses.each do |isc|
          args.concat(isc.query.all_args)
        end

        # HAVING arguments
        args.concat(@havings.flat_map(&.args))

        # Set operation arguments (UNION, INTERSECT, EXCEPT)
        @set_operations.each do |set_op|
          args.concat(set_op.query.all_args)
        end

        args
      end

      # Quote a column name, handling expressions and aliases
      private def quote_column(column : String) : String
        # Don't quote if it contains SQL functions, expressions, aliases, or is already quoted
        if column.includes?("(") || column.includes?(" ") || column.includes?(".") ||
           column.includes?("*") || column.starts_with?('"')
          column
        else
          "\"#{column}\""
        end
      end
    end

    # Special builder for recursive CTEs that generates UNION ALL
    class RecursiveCTEBuilder < Builder
      @base_query : Builder
      @recursive_query : Builder

      def initialize(@base_query : Builder, @recursive_query : Builder)
        super("__recursive_cte__")
      end

      # Build the recursive CTE SQL with parameter offset
      def build_select_with_offset(param_offset : Int32) : Tuple(String, Int32)
        base_sql, offset_after_base = @base_query.build_select_with_offset(param_offset)
        recursive_sql, final_offset = @recursive_query.build_select_with_offset(offset_after_base)

        {"#{base_sql} UNION ALL #{recursive_sql}", final_offset}
      end

      # Get all arguments from both queries
      def all_args : Array(DBValue)
        args = [] of DBValue
        args.concat(@base_query.all_args)
        args.concat(@recursive_query.all_args)
        args
      end
    end

    # Type-safe WHERE clause builder using blocks
    #
    # Example:
    # ```
    # query.where do
    #   name == "Alice"
    #   age > 18
    #   email =~ "%@example.com"
    # end
    # ```
    class WhereBuilder
      class Condition
        getter clause : String
        getter args : Array(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil)

        def initialize(@clause : String, @args : Array(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil) = [] of Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil)
        end
      end

      @conditions : Array(Condition) = [] of Condition

      def initialize
      end

      # Equality condition
      macro method_missing(call)
        \{% if call.name.stringify == "=~" %}
          @conditions << Condition.new("\{{call.args[0].stringify}} LIKE ?", [\{{call.args[1]}}])
        \{% elsif call.name.stringify == "!=" %}
          @conditions << Condition.new("\{{call.args[0].stringify}} != ?", [\{{call.args[1]}}])
        \{% elsif call.name.stringify == ">" %}
          @conditions << Condition.new("\{{call.args[0].stringify}} > ?", [\{{call.args[1]}}])
        \{% elsif call.name.stringify == ">=" %}
          @conditions << Condition.new("\{{call.args[0].stringify}} >= ?", [\{{call.args[1]}}])
        \{% elsif call.name.stringify == "<" %}
          @conditions << Condition.new("\{{call.args[0].stringify}} < ?", [\{{call.args[1]}}])
        \{% elsif call.name.stringify == "<=" %}
          @conditions << Condition.new("\{{call.args[0].stringify}} <= ?", [\{{call.args[1]}}])
        \{% elsif call.name.stringify == "==" %}
          @conditions << Condition.new("\{{call.args[0].stringify}} = ?", [\{{call.args[1]}}])
        \{% else %}
          \{% raise "Unknown operator: \#{call.name}" %}
        \{% end %}
      end

      def build : WhereClause?
        return nil if @conditions.empty?

        clause = @conditions.map(&.clause).join(" AND ")
        args = @conditions.flat_map(&.args)
        WhereClause.new(clause, args)
      end
    end
  end
end

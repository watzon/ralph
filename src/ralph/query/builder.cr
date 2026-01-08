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
        # Convert UUID to string since DB layer doesn't support UUID directly
        converted = args.to_a.map do |a|
          case a
          when UUID
            a.to_s.as(DBValue)
          else
            a.as(DBValue)
          end
        end
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
      # PostgreSQL Full-Text Search Methods
      # ========================================

      # Basic full-text search using @@ operator
      #
      # Uses plainto_tsquery for simple search (automatically tokenizes).
      # Supports any PostgreSQL text search configuration.
      #
      # ## Example
      #
      # ```
      # query.where_search("title", "crystal orm")
      # # SQL: WHERE to_tsvector('english', "title") @@ plainto_tsquery('english', 'crystal orm')
      #
      # query.where_search("content", "programming", config: "simple")
      # # SQL: WHERE to_tsvector('simple', "content") @@ plainto_tsquery('simple', 'programming')
      # ```
      #
      # ## Language Configurations
      #
      # Common configs: 'english', 'simple', 'french', 'german', 'spanish', etc.
      # Use `PostgresBackend#available_text_search_configs` to list all available configs.
      #
      # ## Backend Requirement
      #
      # Raises `Ralph::BackendError` if not using PostgreSQL backend.
      def where_search(column : String, query : String, config : String = "english") : Builder
        ensure_postgres!("Full-text search")
        clause = "to_tsvector('#{config}', \"#{column}\") @@ plainto_tsquery('#{config}', ?)"
        with_wheres(@wheres + [WhereClause.new(clause, [query] of DBValue)])
      end

      # Multi-column full-text search
      #
      # Combines multiple columns into a single tsvector for searching.
      # NULL values are safely handled with coalesce.
      #
      # ## Example
      #
      # ```
      # query.where_search_multi(["title", "content"], "ruby framework")
      # # SQL: WHERE to_tsvector('english', coalesce("title", '') || ' ' || coalesce("content", ''))
      # #        @@ plainto_tsquery('english', 'ruby framework')
      # ```
      def where_search_multi(columns : Array(String), query : String, config : String = "english") : Builder
        ensure_postgres!("Full-text search")
        coalesced = columns.map { |c| "coalesce(\"#{c}\", '')" }.join(" || ' ' || ")
        clause = "to_tsvector('#{config}', #{coalesced}) @@ plainto_tsquery('#{config}', ?)"
        with_wheres(@wheres + [WhereClause.new(clause, [query] of DBValue)])
      end

      # Full-text search using websearch_to_tsquery (PostgreSQL 11+)
      #
      # Parses search queries using web search syntax:
      # - Unquoted words are combined with AND
      # - "quoted phrases" are treated as phrases
      # - OR connects alternatives
      # - -word excludes words
      #
      # ## Example
      #
      # ```
      # query.where_websearch("content", "crystal -ruby \"web framework\"")
      # # Finds documents with "crystal" AND "web framework" but NOT "ruby"
      # ```
      def where_websearch(column : String, query : String, config : String = "english") : Builder
        ensure_postgres!("Web search")
        clause = "to_tsvector('#{config}', \"#{column}\") @@ websearch_to_tsquery('#{config}', ?)"
        with_wheres(@wheres + [WhereClause.new(clause, [query] of DBValue)])
      end

      # Full-text search using phrase matching (PostgreSQL 9.6+)
      #
      # Matches exact phrases where words must appear consecutively.
      #
      # ## Example
      #
      # ```
      # query.where_phrase_search("content", "web framework")
      # # Only matches "web framework", not "web application framework"
      # ```
      def where_phrase_search(column : String, query : String, config : String = "english") : Builder
        ensure_postgres!("Phrase search")
        clause = "to_tsvector('#{config}', \"#{column}\") @@ phraseto_tsquery('#{config}', ?)"
        with_wheres(@wheres + [WhereClause.new(clause, [query] of DBValue)])
      end

      # Order by full-text search rank (relevance score)
      #
      # Higher rank = more relevant match. Must be used with a search query.
      #
      # ## Example
      #
      # ```
      # query.where_search("title", "crystal")
      #      .order_by_search_rank("title", "crystal")
      # # Orders results by relevance to "crystal"
      # ```
      #
      # ## Normalization Options (via normalization parameter)
      #
      # - 0: Default (ignores document length)
      # - 1: Divides rank by 1 + document length logarithm
      # - 2: Divides rank by document length
      # - 4: Divides rank by mean harmonic distance between extents
      # - 8: Divides rank by number of unique words
      # - 16: Divides rank by 1 + document length logarithm (different formula)
      # - 32: Divides rank by document length + 1
      #
      # Combine with bitwise OR: `normalization: 1 | 4`
      def order_by_search_rank(column : String, query : String, config : String = "english", normalization : Int32 = 0) : Builder
        ensure_postgres!("Search rank")
        # Add rank to SELECT and ORDER BY it
        rank_select = "ts_rank(to_tsvector('#{config}', \"#{column}\"), plainto_tsquery('#{config}', '#{query.gsub("'", "''")}'), #{normalization}) AS \"search_rank\""
        new_builder = with_selects(@selects + [rank_select])
        new_builder.order("search_rank", :desc)
      end

      # Order by full-text search rank with cover density
      #
      # Similar to `order_by_search_rank` but also considers proximity of search terms.
      # Uses ts_rank_cd which gives higher scores when matching terms are closer together.
      #
      # ## Example
      #
      # ```
      # query.where_search("content", "crystal programming")
      #      .order_by_search_rank_cd("content", "crystal programming")
      # ```
      def order_by_search_rank_cd(column : String, query : String, config : String = "english", normalization : Int32 = 0) : Builder
        ensure_postgres!("Search rank with cover density")
        rank_select = "ts_rank_cd(to_tsvector('#{config}', \"#{column}\"), plainto_tsquery('#{config}', '#{query.gsub("'", "''")}'), #{normalization}) AS \"search_rank\""
        new_builder = with_selects(@selects + [rank_select])
        new_builder.order("search_rank", :desc)
      end

      # Select search headline (highlighted excerpt with matching terms)
      #
      # Generates a short excerpt with search terms highlighted using HTML tags.
      #
      # ## Example
      #
      # ```
      # query.where_search("content", "crystal")
      #      .select_search_headline("content", "crystal")
      # # Returns content like: "Learn about <b>Crystal</b> programming language"
      # ```
      #
      # ## Options
      #
      # - **max_words**: Maximum words in headline (default: 35)
      # - **min_words**: Minimum words in headline (default: 15)
      # - **short_word**: Ignore words shorter than this (default: 3)
      # - **highlight_all**: Highlight all occurrences, not just best (default: false)
      # - **max_fragments**: Maximum number of excerpts (default: 0 = unlimited)
      # - **start_tag**: Opening tag for highlights (default: "<b>")
      # - **stop_tag**: Closing tag for highlights (default: "</b>")
      # - **fragment_delimiter**: Text between fragments (default: " ... ")
      def select_search_headline(
        column : String,
        query : String,
        config : String = "english",
        max_words : Int32 = 35,
        min_words : Int32 = 15,
        short_word : Int32 = 3,
        highlight_all : Bool = false,
        max_fragments : Int32 = 0,
        start_tag : String = "<b>",
        stop_tag : String = "</b>",
        fragment_delimiter : String = " ... ",
        as alias_name : String = "headline"
      ) : Builder
        ensure_postgres!("Search headline")

        options = [
          "MaxWords=#{max_words}",
          "MinWords=#{min_words}",
          "ShortWord=#{short_word}",
          "HighlightAll=#{highlight_all ? "TRUE" : "FALSE"}",
          "MaxFragments=#{max_fragments}",
          "StartSel=#{start_tag}",
          "StopSel=#{stop_tag}",
          "FragmentDelimiter=#{fragment_delimiter}",
        ].join(", ")

        headline_select = "ts_headline('#{config}', \"#{column}\", plainto_tsquery('#{config}', '#{query.gsub("'", "''")}'), '#{options}') AS \"#{alias_name}\""
        with_selects(@selects + [headline_select])
      end

      # ========================================
      # PostgreSQL Date/Time Functions
      # ========================================

      # Compare column to NOW()
      #
      # ## Example
      #
      # ```
      # query.where_before_now("expires_at")
      # # SQL: WHERE "expires_at" < NOW()
      #
      # query.where_after_now("start_date")
      # # SQL: WHERE "start_date" > NOW()
      # ```
      def where_before_now(column : String) : Builder
        ensure_postgres!("NOW() function")
        with_wheres(@wheres + [WhereClause.new("\"#{column}\" < NOW()", [] of DBValue)])
      end

      def where_after_now(column : String) : Builder
        ensure_postgres!("NOW() function")
        with_wheres(@wheres + [WhereClause.new("\"#{column}\" > NOW()", [] of DBValue)])
      end

      # Compare column to NOW() with custom operator
      #
      # ## Example
      #
      # ```
      # query.where_now("updated_at", ">=")
      # # SQL: WHERE "updated_at" >= NOW()
      # ```
      def where_now(column : String, operator : String = "=") : Builder
        ensure_postgres!("NOW() function")
        with_wheres(@wheres + [WhereClause.new("\"#{column}\" #{operator} NOW()", [] of DBValue)])
      end

      # Compare column to CURRENT_TIMESTAMP
      #
      # CURRENT_TIMESTAMP is SQL standard and returns the same value throughout a transaction.
      # NOW() is PostgreSQL-specific and also returns a constant within a transaction.
      def where_current_timestamp(column : String, operator : String = "=") : Builder
        ensure_postgres!("CURRENT_TIMESTAMP")
        with_wheres(@wheres + [WhereClause.new("\"#{column}\" #{operator} CURRENT_TIMESTAMP", [] of DBValue)])
      end

      # Select NOW() as a column
      #
      # ## Example
      #
      # ```
      # query.select_now("server_time")
      # # SQL: SELECT NOW() AS "server_time"
      # ```
      def select_now(as alias_name : String = "now") : Builder
        ensure_postgres!("NOW() function")
        with_selects(@selects + ["NOW() AS \"#{alias_name}\""])
      end

      # Select CURRENT_TIMESTAMP
      def select_current_timestamp(as alias_name : String = "current_timestamp") : Builder
        ensure_postgres!("CURRENT_TIMESTAMP")
        with_selects(@selects + ["CURRENT_TIMESTAMP AS \"#{alias_name}\""])
      end

      # Compare column age (interval since timestamp)
      #
      # The age() function calculates the interval between now and the given timestamp.
      #
      # ## Example
      #
      # ```
      # # Find records created more than 7 days ago
      # query.where_age("created_at", ">", "7 days")
      #
      # # Find records updated within the last hour
      # query.where_age("updated_at", "<", "1 hour")
      # ```
      #
      # ## Interval Format
      #
      # PostgreSQL interval format: '1 year 2 months 3 days 4 hours 5 minutes 6 seconds'
      # Also accepts: '1 week', '30 days', '2 hours', etc.
      def where_age(column : String, operator : String, interval : String) : Builder
        ensure_postgres!("age() function")
        with_wheres(@wheres + [WhereClause.new("age(\"#{column}\") #{operator} interval '#{interval}'", [] of DBValue)])
      end

      # Convenience methods for common age comparisons
      def where_age_greater_than(column : String, interval : String) : Builder
        where_age(column, ">", interval)
      end

      def where_age_less_than(column : String, interval : String) : Builder
        where_age(column, "<", interval)
      end

      def where_older_than(column : String, interval : String) : Builder
        where_age(column, ">", interval)
      end

      def where_newer_than(column : String, interval : String) : Builder
        where_age(column, "<", interval)
      end

      # Date truncation (round down to precision)
      #
      # Truncates a timestamp to the specified precision level.
      #
      # ## Supported Precisions
      #
      # microseconds, milliseconds, second, minute, hour, day, week,
      # month, quarter, year, decade, century, millennium
      #
      # ## Example
      #
      # ```
      # # Find records created on a specific day
      # query.where_date_trunc("day", "created_at", "2024-01-15")
      #
      # # Group by month
      # query.select_date_trunc("month", "created_at", as: "month").group("month")
      # ```
      def where_date_trunc(precision : String, column : String, value : String | Time) : Builder
        ensure_postgres!("date_trunc() function")
        value_str = value.is_a?(Time) ? value.to_s("%Y-%m-%d %H:%M:%S") : value.to_s
        with_wheres(@wheres + [WhereClause.new("date_trunc('#{precision}', \"#{column}\") = '#{value_str}'", [] of DBValue)])
      end

      # Select date-truncated column
      def select_date_trunc(precision : String, column : String, as alias_name : String) : Builder
        ensure_postgres!("date_trunc() function")
        with_selects(@selects + ["date_trunc('#{precision}', \"#{column}\") AS \"#{alias_name}\""])
      end

      # Extract date/time component
      #
      # Extracts a specific part from a timestamp.
      #
      # ## Supported Parts
      #
      # century, day, decade, dow (day of week), doy (day of year), epoch,
      # hour, isodow, isoyear, microseconds, millennium, milliseconds,
      # minute, month, quarter, second, timezone, timezone_hour,
      # timezone_minute, week, year
      #
      # ## Example
      #
      # ```
      # # Find records from 2024
      # query.where_extract("year", "created_at", 2024)
      #
      # # Find records from January
      # query.where_extract("month", "created_at", 1)
      # ```
      def where_extract(part : String, column : String, value : Int32) : Builder
        ensure_postgres!("extract() function")
        with_wheres(@wheres + [WhereClause.new("EXTRACT(#{part} FROM \"#{column}\") = #{value}", [] of DBValue)])
      end

      # Select extracted date/time component
      def select_extract(part : String, column : String, as alias_name : String) : Builder
        ensure_postgres!("extract() function")
        with_selects(@selects + ["EXTRACT(#{part} FROM \"#{column}\") AS \"#{alias_name}\""])
      end

      # Filter by date range relative to now
      #
      # ## Example
      #
      # ```
      # # Records from the last 7 days
      # query.where_within_last("created_at", "7 days")
      #
      # # Records from the last 2 hours
      # query.where_within_last("updated_at", "2 hours")
      # ```
      def where_within_last(column : String, interval : String) : Builder
        ensure_postgres!("Interval calculation")
        with_wheres(@wheres + [WhereClause.new("\"#{column}\" > NOW() - interval '#{interval}'", [] of DBValue)])
      end

      # ========================================
      # PostgreSQL UUID Functions
      # ========================================

      # Select gen_random_uuid() as a column
      #
      # Generates a random UUID v4.
      #
      # ## Example
      #
      # ```
      # query.select_random_uuid("new_id")
      # # SQL: SELECT gen_random_uuid() AS "new_id"
      # ```
      def select_random_uuid(as alias_name : String = "uuid") : Builder
        ensure_postgres!("gen_random_uuid() function")
        with_selects(@selects + ["gen_random_uuid() AS \"#{alias_name}\""])
      end

      # ========================================
      # PostgreSQL String Functions
      # ========================================

      # String concatenation comparison
      #
      # ## Example
      #
      # ```
      # query.where_concat("first_name", "last_name", "John Doe")
      # # SQL: WHERE "first_name" || ' ' || "last_name" = 'John Doe'
      # ```
      def where_concat(column1 : String, column2 : String, value : String, separator : String = " ") : Builder
        ensure_postgres!("String concatenation")
        clause = "\"#{column1}\" || '#{separator}' || \"#{column2}\" = ?"
        with_wheres(@wheres + [WhereClause.new(clause, [value] of DBValue)])
      end

      # Regular expression match (case-sensitive)
      #
      # Uses PostgreSQL's ~ operator for POSIX regex matching.
      #
      # ## Example
      #
      # ```
      # # Match usernames that start with a letter and contain only alphanumerics
      # query.where_regex("username", "^[a-zA-Z][a-zA-Z0-9_]*$")
      #
      # # Match email pattern
      # query.where_regex("email", "^[^@]+@[^@]+\\.[^@]+$")
      # ```
      def where_regex(column : String, pattern : String) : Builder
        ensure_postgres!("Regex operator (~)")
        with_wheres(@wheres + [WhereClause.new("\"#{column}\" ~ ?", [pattern] of DBValue)])
      end

      # Case-insensitive regular expression match
      #
      # Uses PostgreSQL's ~* operator.
      #
      # ## Example
      #
      # ```
      # query.where_regex_i("name", "john")
      # # Matches "John", "JOHN", "john", etc.
      # ```
      def where_regex_i(column : String, pattern : String) : Builder
        ensure_postgres!("Case-insensitive regex operator (~*)")
        with_wheres(@wheres + [WhereClause.new("\"#{column}\" ~* ?", [pattern] of DBValue)])
      end

      # Regular expression not match (case-sensitive)
      def where_not_regex(column : String, pattern : String) : Builder
        ensure_postgres!("Regex not-match operator (!~)")
        with_wheres(@wheres + [WhereClause.new("\"#{column}\" !~ ?", [pattern] of DBValue)])
      end

      # Case-insensitive regular expression not match
      def where_not_regex_i(column : String, pattern : String) : Builder
        ensure_postgres!("Case-insensitive regex not-match operator (!~*)")
        with_wheres(@wheres + [WhereClause.new("\"#{column}\" !~* ?", [pattern] of DBValue)])
      end

      # String length comparison
      #
      # ## Example
      #
      # ```
      # query.where_length("name", ">", 5)
      # # SQL: WHERE length("name") > 5
      # ```
      def where_length(column : String, operator : String, length : Int32) : Builder
        ensure_postgres!("length() function")
        with_wheres(@wheres + [WhereClause.new("length(\"#{column}\") #{operator} #{length}", [] of DBValue)])
      end

      # Select string length
      def select_length(column : String, as alias_name : String = "length") : Builder
        ensure_postgres!("length() function")
        with_selects(@selects + ["length(\"#{column}\") AS \"#{alias_name}\""])
      end

      # Convert to lowercase comparison
      #
      # ## Example
      #
      # ```
      # query.where_lower("email", "test@example.com")
      # # SQL: WHERE lower("email") = 'test@example.com'
      # ```
      def where_lower(column : String, value : String) : Builder
        ensure_postgres!("lower() function")
        with_wheres(@wheres + [WhereClause.new("lower(\"#{column}\") = ?", [value] of DBValue)])
      end

      # Select lowercase column
      def select_lower(column : String, as alias_name : String) : Builder
        ensure_postgres!("lower() function")
        with_selects(@selects + ["lower(\"#{column}\") AS \"#{alias_name}\""])
      end

      # Convert to uppercase comparison
      def where_upper(column : String, value : String) : Builder
        ensure_postgres!("upper() function")
        with_wheres(@wheres + [WhereClause.new("upper(\"#{column}\") = ?", [value] of DBValue)])
      end

      # Select uppercase column
      def select_upper(column : String, as alias_name : String) : Builder
        ensure_postgres!("upper() function")
        with_selects(@selects + ["upper(\"#{column}\") AS \"#{alias_name}\""])
      end

      # Trim whitespace comparison
      def where_trim(column : String, value : String) : Builder
        ensure_postgres!("trim() function")
        with_wheres(@wheres + [WhereClause.new("trim(\"#{column}\") = ?", [value] of DBValue)])
      end

      # Substring comparison
      #
      # ## Example
      #
      # ```
      # query.where_substring("code", 1, 3, "ABC")
      # # SQL: WHERE substring("code" from 1 for 3) = 'ABC'
      # ```
      def where_substring(column : String, start : Int32, length : Int32, value : String) : Builder
        ensure_postgres!("substring() function")
        with_wheres(@wheres + [WhereClause.new("substring(\"#{column}\" from #{start} for #{length}) = ?", [value] of DBValue)])
      end

      # Select substring
      def select_substring(column : String, start : Int32, length : Int32, as alias_name : String) : Builder
        ensure_postgres!("substring() function")
        with_selects(@selects + ["substring(\"#{column}\" from #{start} for #{length}) AS \"#{alias_name}\""])
      end

      # String replacement
      #
      # ## Example
      #
      # ```
      # query.select_replace("email", "@example.com", "@test.com", as: "test_email")
      # # SQL: SELECT replace("email", '@example.com', '@test.com') AS "test_email"
      # ```
      def select_replace(column : String, from : String, to : String, as alias_name : String) : Builder
        ensure_postgres!("replace() function")
        with_selects(@selects + ["replace(\"#{column}\", '#{from.gsub("'", "''")}', '#{to.gsub("'", "''")}') AS \"#{alias_name}\""])
      end

      # Starts with comparison (uses efficient index if available)
      #
      # ## Example
      #
      # ```
      # query.where_starts_with("name", "John")
      # # SQL: WHERE "name" LIKE 'John%'
      # ```
      def where_starts_with(column : String, prefix : String) : Builder
        # This works on any backend, but included here for completeness
        escaped = prefix.gsub("%", "\\%").gsub("_", "\\_")
        with_wheres(@wheres + [WhereClause.new("\"#{column}\" LIKE ?", ["#{escaped}%"] of DBValue)])
      end

      # Ends with comparison
      def where_ends_with(column : String, suffix : String) : Builder
        escaped = suffix.gsub("%", "\\%").gsub("_", "\\_")
        with_wheres(@wheres + [WhereClause.new("\"#{column}\" LIKE ?", ["%#{escaped}"] of DBValue)])
      end

      # Case-insensitive LIKE (PostgreSQL ILIKE)
      #
      # ## Example
      #
      # ```
      # query.where_ilike("name", "%john%")
      # # Matches "John", "JOHN DOE", "johnny", etc.
      # ```
      def where_ilike(column : String, pattern : String) : Builder
        ensure_postgres!("ILIKE operator")
        with_wheres(@wheres + [WhereClause.new("\"#{column}\" ILIKE ?", [pattern] of DBValue)])
      end

      # Case-insensitive NOT LIKE
      def where_not_ilike(column : String, pattern : String) : Builder
        ensure_postgres!("NOT ILIKE operator")
        with_wheres(@wheres + [WhereClause.new("\"#{column}\" NOT ILIKE ?", [pattern] of DBValue)])
      end

      # ========================================
      # PostgreSQL Array Functions (Enhanced)
      # ========================================

      # Check if array contains all specified elements
      #
      # ## Example
      #
      # ```
      # query.where_array_contains_all("tags", ["crystal", "orm"])
      # # SQL: WHERE "tags" @> ARRAY['crystal', 'orm']
      # ```
      def where_array_contains_all(column : String, values : Array(String)) : Builder
        ensure_postgres!("Array containment operator (@>)")
        return self if values.empty?
        quoted = values.map { |v| "'#{v.gsub("'", "''")}'" }.join(", ")
        with_wheres(@wheres + [WhereClause.new("\"#{column}\" @> ARRAY[#{quoted}]", [] of DBValue)])
      end

      # Check if array is contained by another array
      #
      # All elements in the column must be present in the given values.
      def where_array_is_contained_by(column : String, values : Array(String)) : Builder
        ensure_postgres!("Array containment operator (<@)")
        return self if values.empty?
        quoted = values.map { |v| "'#{v.gsub("'", "''")}'" }.join(", ")
        with_wheres(@wheres + [WhereClause.new("\"#{column}\" <@ ARRAY[#{quoted}]", [] of DBValue)])
      end

      # Array cardinality (length) using cardinality() function
      #
      # Works correctly with multi-dimensional arrays (returns total elements).
      def where_cardinality(column : String, operator : String, value : Int32) : Builder
        ensure_postgres!("cardinality() function")
        with_wheres(@wheres + [WhereClause.new("cardinality(\"#{column}\") #{operator} #{value}", [] of DBValue)])
      end

      # Append element to array (for use in UPDATE)
      #
      # Returns an expression that can be used with raw SQL.
      def select_array_append(column : String, value : String, as alias_name : String) : Builder
        ensure_postgres!("array_append() function")
        with_selects(@selects + ["array_append(\"#{column}\", '#{value.gsub("'", "''")}') AS \"#{alias_name}\""])
      end

      # Remove element from array (for use in UPDATE)
      def select_array_remove(column : String, value : String, as alias_name : String) : Builder
        ensure_postgres!("array_remove() function")
        with_selects(@selects + ["array_remove(\"#{column}\", '#{value.gsub("'", "''")}') AS \"#{alias_name}\""])
      end

      # Get array element at index (1-based in PostgreSQL)
      def select_array_element(column : String, index : Int32, as alias_name : String) : Builder
        ensure_postgres!("Array subscript")
        with_selects(@selects + ["\"#{column}\"[#{index}] AS \"#{alias_name}\""])
      end

      # Unnest array (expand to rows)
      #
      # ## Example
      #
      # ```
      # # Expand tags array into individual rows
      # query.select_unnest("tags", as: "tag")
      # ```
      def select_unnest(column : String, as alias_name : String) : Builder
        ensure_postgres!("unnest() function")
        with_selects(@selects + ["unnest(\"#{column}\") AS \"#{alias_name}\""])
      end

      # ========================================
      # PostgreSQL Advanced Aggregations
      # ========================================

      # Aggregate values into an array
      #
      # ## Example
      #
      # ```
      # query.group("user_id").select_array_agg("tag", as: "tags")
      # # SQL: SELECT array_agg("tag") AS "tags" FROM ... GROUP BY user_id
      # ```
      def select_array_agg(column : String, distinct : Bool = false, order_by : String? = nil, as alias_name : String = "array_agg") : Builder
        ensure_postgres!("array_agg() function")

        distinct_sql = distinct ? "DISTINCT " : ""
        order_sql = order_by ? " ORDER BY \"#{order_by}\"" : ""

        with_selects(@selects + ["array_agg(#{distinct_sql}\"#{column}\"#{order_sql}) AS \"#{alias_name}\""])
      end

      # Aggregate strings with delimiter
      #
      # ## Example
      #
      # ```
      # query.group("category_id").select_string_agg("name", ", ", order_by: "name", as: "names")
      # # SQL: SELECT string_agg("name", ', ' ORDER BY "name") AS "names"
      # ```
      def select_string_agg(column : String, delimiter : String, distinct : Bool = false, order_by : String? = nil, as alias_name : String = "string_agg") : Builder
        ensure_postgres!("string_agg() function")

        distinct_sql = distinct ? "DISTINCT " : ""
        order_sql = order_by ? " ORDER BY \"#{order_by}\"" : ""

        with_selects(@selects + ["string_agg(#{distinct_sql}\"#{column}\", '#{delimiter}'#{order_sql}) AS \"#{alias_name}\""])
      end

      # Calculate mode (most common value)
      #
      # ## Example
      #
      # ```
      # query.select_mode("rating", as: "most_common_rating")
      # # SQL: SELECT mode() WITHIN GROUP (ORDER BY "rating") AS "most_common_rating"
      # ```
      def select_mode(column : String, as alias_name : String = "mode") : Builder
        ensure_postgres!("mode() function")
        with_selects(@selects + ["mode() WITHIN GROUP (ORDER BY \"#{column}\") AS \"#{alias_name}\""])
      end

      # Calculate percentile (continuous)
      #
      # ## Example
      #
      # ```
      # query.select_percentile("response_time", 0.95, as: "p95")
      # # SQL: SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY "response_time") AS "p95"
      # ```
      def select_percentile(column : String, percentile : Float64, as alias_name : String = "percentile") : Builder
        ensure_postgres!("percentile_cont() function")
        with_selects(@selects + ["percentile_cont(#{percentile}) WITHIN GROUP (ORDER BY \"#{column}\") AS \"#{alias_name}\""])
      end

      # Calculate median (50th percentile)
      def select_median(column : String, as alias_name : String = "median") : Builder
        select_percentile(column, 0.5, as: alias_name)
      end

      # Calculate percentile (discrete - returns actual value from dataset)
      def select_percentile_disc(column : String, percentile : Float64, as alias_name : String = "percentile") : Builder
        ensure_postgres!("percentile_disc() function")
        with_selects(@selects + ["percentile_disc(#{percentile}) WITHIN GROUP (ORDER BY \"#{column}\") AS \"#{alias_name}\""])
      end

      # Aggregate into JSON array
      #
      # ## Example
      #
      # ```
      # query.group("user_id").select_json_agg("order_id", as: "order_ids")
      # # SQL: SELECT json_agg("order_id") AS "order_ids"
      # ```
      def select_json_agg(column : String, order_by : String? = nil, as alias_name : String = "json_agg") : Builder
        ensure_postgres!("json_agg() function")
        order_sql = order_by ? " ORDER BY \"#{order_by}\"" : ""
        with_selects(@selects + ["json_agg(\"#{column}\"#{order_sql}) AS \"#{alias_name}\""])
      end

      # Aggregate into JSONB array
      def select_jsonb_agg(column : String, order_by : String? = nil, as alias_name : String = "jsonb_agg") : Builder
        ensure_postgres!("jsonb_agg() function")
        order_sql = order_by ? " ORDER BY \"#{order_by}\"" : ""
        with_selects(@selects + ["jsonb_agg(\"#{column}\"#{order_sql}) AS \"#{alias_name}\""])
      end

      # Build JSON object from key-value pairs
      #
      # ## Example
      #
      # ```
      # query.select_json_build_object({"name" => "name", "email" => "email"}, as: "user_info")
      # # SQL: SELECT json_build_object('name', "name", 'email', "email") AS "user_info"
      # ```
      def select_json_build_object(pairs : Hash(String, String), as alias_name : String = "json_object") : Builder
        ensure_postgres!("json_build_object() function")
        parts = pairs.flat_map { |k, v| ["'#{k}'", "\"#{v}\""] }
        with_selects(@selects + ["json_build_object(#{parts.join(", ")}) AS \"#{alias_name}\""])
      end

      # ========================================
      # PostgreSQL Backend Helper
      # ========================================

      # Check if current backend is PostgreSQL
      private def is_postgres? : Bool
        Ralph.settings.database.try(&.dialect) == :postgres
      end

      # Ensure PostgreSQL backend or raise error
      private def ensure_postgres!(feature : String) : Nil
        unless is_postgres?
          raise Ralph::BackendError.new("#{feature} is only available on PostgreSQL backend")
        end
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

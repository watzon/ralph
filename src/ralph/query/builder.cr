module Ralph
  module Query
    # Represents a WHERE clause
    class WhereClause
      getter clause : String
      getter args : Array(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil)

      def initialize(@clause : String, @args : Array(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil) = [] of Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil)
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
                    when :inner then "INNER JOIN"
                    when :left   then "LEFT JOIN"
                    when :right  then "RIGHT JOIN"
                    when :cross  then "CROSS JOIN"
                    when :full   then "FULL OUTER JOIN"
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

    # Builds SQL queries with a fluent interface
    class Builder
      @wheres : Array(WhereClause) = [] of WhereClause
      @orders : Array(OrderClause) = [] of OrderClause
      @limit : Int32?
      @offset : Int32?
      @joins : Array(JoinClause) = [] of JoinClause
      @selects : Array(String) = [] of String
      @groups : Array(String) = [] of String
      @havings : Array(WhereClause) = [] of WhereClause
      @distinct : Bool = false
      @distinct_columns : Array(String) = [] of String

      def initialize(@table : String)
      end

      # Select specific columns
      def select(*columns : String) : self
        @selects.concat(columns.to_a)
        self
      end

      # Add a WHERE clause
      def where(clause : String, *args) : self
        converted = args.to_a.map { |a| a.as(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil) }
        @wheres << WhereClause.new(clause, converted)
        self
      end

      # Add a WHERE clause with a block
      def where(&block : WhereBuilder ->) : self
        builder = WhereBuilder.new
        block.call(builder)
        if clause = builder.build
          @wheres << clause
        end
        self
      end

      # Add a WHERE NOT clause
      def where_not(clause : String, *args) : self
        converted = args.to_a.map { |a| a.as(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil) }
        @wheres << WhereClause.new("NOT (#{clause})", converted)
        self
      end

      # Add an ORDER BY clause
      def order(column : String, direction : Symbol = :asc) : self
        @orders << OrderClause.new(column, direction)
        self
      end

      # Add a LIMIT clause
      def limit(count : Int32) : self
        @limit = count
        self
      end

      # Add an OFFSET clause
      def offset(count : Int32) : self
        @offset = count
        self
      end

      # Join another table
      def join(table : String, on : String, type : Symbol = :inner, alias as_alias : String? = nil) : self
        @joins << JoinClause.new(table, on, type, as_alias)
        self
      end

      # Inner join (alias for join)
      def inner_join(table : String, on : String, alias as_alias : String? = nil) : self
        join(table, on, :inner, as_alias)
      end

      # Left join
      def left_join(table : String, on : String, alias as_alias : String? = nil) : self
        join(table, on, :left, as_alias)
      end

      # Right join
      def right_join(table : String, on : String, alias as_alias : String? = nil) : self
        join(table, on, :right, as_alias)
      end

      # Cross join (no ON clause)
      def cross_join(table : String, alias as_alias : String? = nil) : self
        @joins << JoinClause.new(table, "", :cross, as_alias)
        self
      end

      # Full outer join
      def full_outer_join(table : String, on : String, alias as_alias : String? = nil) : self
        join(table, on, :full_outer, as_alias)
      end

      # Full join (alias for full_outer_join)
      def full_join(table : String, on : String, alias as_alias : String? = nil) : self
        join(table, on, :full, as_alias)
      end

      # Add a GROUP BY clause
      def group(*columns : String) : self
        @groups.concat(columns.to_a)
        self
      end

      # Add a HAVING clause
      def having(clause : String, *args) : self
        converted = args.to_a.map { |a| a.as(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil) }
        @havings << WhereClause.new(clause, converted)
        self
      end

      # Add DISTINCT to SELECT
      def distinct : self
        @distinct = true
        self
      end

      # Add DISTINCT ON specific columns
      def distinct(*columns : String) : self
        @distinct = true
        @distinct_columns.concat(columns.to_a)
        self
      end

      # Build the SELECT query
      def build_select : String
        # Build SELECT clause with DISTINCT if specified
        # Note: DISTINCT ON is PostgreSQL-specific, so we use GROUP BY for column-specific distinct
        distinct_clause = if @distinct && @distinct_columns.empty?
          "DISTINCT "
        else
          ""
        end

        select_clause = @selects.empty? ? "*" : @selects.map { |c| "\"#{c}\"" }.join(", ")

        # Handle table name - quote it if not already quoted
        table_name = @table.starts_with?('"') ? @table : "\"#{@table}\""
        query = "SELECT #{distinct_clause}#{select_clause} FROM #{table_name}"

        unless @joins.empty?
          query += " " + @joins.map(&.to_sql).join(" ")
        end

        unless @wheres.empty?
          where_sql = build_where_clauses
          query += " WHERE #{where_sql}"
        end

        # Combine explicit groups with distinct_columns for GROUP BY
        all_groups = @groups.dup
        all_groups.concat(@distinct_columns) unless @distinct_columns.empty?

        unless all_groups.empty?
          group_sql = all_groups.map { |c| "\"#{c}\"" }.join(", ")
          query += " GROUP BY #{group_sql}"

          # HAVING is only valid with GROUP BY
          unless @havings.empty?
            having_index = 0
            having_sql = @havings.map do |h|
              clause = h.clause
              h.args.each do
                having_index += 1
                clause = clause.sub("?", "$#{having_index}")
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

        query
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
        "SELECT COUNT(\"#{column}\") FROM \"#{@table}\"#{where}"
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

      # Reset the query builder
      def reset : self
        @wheres.clear
        @orders.clear
        @limit = nil
        @offset = nil
        @joins.clear
        @selects.clear
        @groups.clear
        @havings.clear
        @distinct = false
        @distinct_columns.clear
        self
      end

      # Check if the query has conditions
      def has_conditions? : Bool
        !@wheres.empty?
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

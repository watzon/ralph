# SQL Migration Generator for db:generate
#
# Generates SQL migration files from schema diffs produced
# by the SchemaComparator. Outputs plain SQL files with
# -- +migrate Up/Down markers.

require "file_utils"

module Ralph
  module Schema
    class SqlMigrationGenerator
      @diff : SchemaDiff
      @name : String
      @output_dir : String
      @dialect : Symbol
      @model_schemas : Hash(String, ModelSchema)?

      def initialize(@diff, @name = "auto_migration", @output_dir = "./db/migrations", @dialect = :sqlite, @model_schemas = nil)
      end

      def generate : NamedTuple(path: String, content: String)
        timestamp = Time.utc.to_s("%Y%m%d%H%M%S")
        snake_name = @name.underscore.gsub(/[^a-z0-9_]/, "_")
        file_name = "#{timestamp}_#{snake_name}.sql"
        path = File.join(@output_dir, file_name)

        content = build_migration_content

        {path: path, content: content}
      end

      def generate! : String
        result = generate
        FileUtils.mkdir_p(@output_dir)
        File.write(result[:path], result[:content])
        result[:path]
      end

      private def build_migration_content : String
        String.build do |io|
          # Header comment
          io << "-- Migration: #{@name}\n"
          io << "-- Generated: #{Time.utc}\n"
          io << "-- Dialect: #{@dialect}\n"
          if @diff.has_destructive_changes?
            io << "--\n"
            io << "-- ⚠️  WARNING: This migration contains destructive changes!\n"
            io << "-- Review carefully before running.\n"
          end
          io << "\n"

          # Up migration
          io << "-- +migrate Up\n"
          generate_up_statements(io)

          io << "\n"

          # Down migration
          io << "-- +migrate Down\n"
          generate_down_statements(io)
        end
      end

      private def generate_up_statements(io : IO)
        # Separate changes by type for proper ordering
        create_table_changes = [] of SchemaChange
        other_changes = [] of SchemaChange

        @diff.changes.each do |change|
          if change.type.create_table?
            create_table_changes << change
          else
            other_changes << change
          end
        end

        # Sort CREATE TABLE statements by FK dependencies
        sorted_creates, deferred_fks = sort_tables_by_dependencies(create_table_changes)

        # Generate CREATE TABLE statements in dependency order
        sorted_creates.each do |change|
          if warning = change.warning
            io << "-- ⚠️  #{warning}\n"
          end
          generate_create_table_sql(io, change, deferred_fks)
        end

        # Add deferred foreign keys (for circular dependencies)
        unless deferred_fks.empty?
          io << "\n-- Deferred foreign keys (circular dependencies)\n"
          deferred_fks.each do |table, fks|
            fks.each do |fk|
              constraint_name = "fk_#{table}_#{fk.from_column}"
              io << "ALTER TABLE \"#{table}\" ADD CONSTRAINT \"#{constraint_name}\" "
              io << "FOREIGN KEY (\"#{fk.from_column}\") REFERENCES \"#{fk.to_table}\" (\"#{fk.to_column}\");\n"
            end
          end
        end

        # Generate all other changes
        other_changes.each do |change|
          if warning = change.warning
            io << "-- ⚠️  #{warning}\n"
          end

          case change.type
          when .drop_table?
            io << "DROP TABLE IF EXISTS \"#{change.table}\";\n"
          when .add_column?
            generate_add_column_sql(io, change)
          when .remove_column?
            io << "ALTER TABLE \"#{change.table}\" DROP COLUMN \"#{change.column}\";\n"
          when .change_column_type?
            generate_change_column_type_sql(io, change)
          when .change_column_nullable?
            generate_change_nullable_sql(io, change)
          when .add_foreign_key?
            generate_add_foreign_key_sql(io, change)
          when .remove_foreign_key?
            io << "ALTER TABLE \"#{change.table}\" DROP CONSTRAINT \"fk_#{change.table}_#{change.column}\";\n"
          when .add_index?
            io << "CREATE INDEX \"index_#{change.table}_on_#{change.column}\" ON \"#{change.table}\" (\"#{change.column}\");\n"
          when .remove_index?
            io << "DROP INDEX IF EXISTS \"index_#{change.table}_on_#{change.column}\";\n"
          end
        end

        if @diff.empty?
          io << "-- No changes detected\n"
        end
      end

      # Sort CREATE TABLE changes by foreign key dependencies using topological sort.
      # Returns tuple of (sorted_changes, deferred_fks) where deferred_fks contains
      # foreign keys that couldn't be resolved due to circular dependencies.
      private def sort_tables_by_dependencies(creates : Array(SchemaChange)) : {Array(SchemaChange), Hash(String, Array(ModelForeignKey))}
        return {creates, {} of String => Array(ModelForeignKey)} if creates.empty?

        schemas = @model_schemas
        return {creates, {} of String => Array(ModelForeignKey)} unless schemas

        # Build table name -> change mapping
        changes_by_table = creates.map { |c| {c.table, c} }.to_h
        tables_to_create = changes_by_table.keys.to_set

        # Build dependency graph: table -> tables it depends on (via FKs)
        dependencies = {} of String => Set(String)
        all_fks = {} of String => Array(ModelForeignKey)

        tables_to_create.each do |table|
          dependencies[table] = Set(String).new
          if model = schemas[table]?
            all_fks[table] = model.foreign_keys.dup
            model.foreign_keys.each do |fk|
              # Only count as dependency if the referenced table is also being created
              # AND it's not a self-reference
              if tables_to_create.includes?(fk.to_table) && fk.to_table != table
                dependencies[table] << fk.to_table
              end
            end
          else
            all_fks[table] = [] of ModelForeignKey
          end
        end

        # Topological sort with cycle detection
        sorted = [] of String
        visited = Set(String).new
        in_stack = Set(String).new # For cycle detection
        deferred_fks = {} of String => Array(ModelForeignKey)

        # Visit function for DFS-based topological sort
        visit = uninitialized String -> Nil
        visit = ->(table : String) do
          return if visited.includes?(table)

          if in_stack.includes?(table)
            # Cycle detected - this shouldn't happen after we break cycles below
            return
          end

          in_stack << table
          dependencies[table].each { |dep| visit.call(dep) }
          in_stack.delete(table)
          visited << table
          sorted << table
          nil
        end

        # First pass: detect and break cycles by deferring FKs
        # Find strongly connected components (cycles)
        cycles = find_cycles(dependencies)

        cycles.each do |cycle|
          # For each cycle, pick one edge to defer (the one from the "last" table alphabetically)
          cycle_tables = cycle.to_a.sort
          break_from = cycle_tables.last

          # Find FKs from break_from that point to other tables in the cycle
          if fks = all_fks[break_from]?
            fks_to_defer = fks.select { |fk| cycle.includes?(fk.to_table) && fk.to_table != break_from }
            unless fks_to_defer.empty?
              deferred_fks[break_from] = fks_to_defer
              # Remove these dependencies to break the cycle
              fks_to_defer.each do |fk|
                dependencies[break_from].delete(fk.to_table)
              end
            end
          end
        end

        # Now do the topological sort (should succeed after breaking cycles)
        tables_to_create.each { |table| visit.call(table) }

        # Map back to changes in sorted order
        sorted_changes = sorted.compact_map { |table| changes_by_table[table]? }

        {sorted_changes, deferred_fks}
      end

      # Find all cycles in the dependency graph using Tarjan's algorithm
      private def find_cycles(dependencies : Hash(String, Set(String))) : Array(Set(String))
        index_counter = [0]
        stack = [] of String
        lowlinks = {} of String => Int32
        index = {} of String => Int32
        on_stack = Set(String).new
        sccs = [] of Set(String)

        strongconnect = uninitialized String -> Nil
        strongconnect = ->(node : String) do
          index[node] = index_counter[0]
          lowlinks[node] = index_counter[0]
          index_counter[0] += 1
          stack.push(node)
          on_stack << node

          dependencies[node]?.try &.each do |successor|
            if !index.has_key?(successor)
              strongconnect.call(successor)
              lowlinks[node] = Math.min(lowlinks[node], lowlinks[successor])
            elsif on_stack.includes?(successor)
              lowlinks[node] = Math.min(lowlinks[node], index[successor])
            end
          end

          # If node is a root node, pop the stack and generate an SCC
          if lowlinks[node] == index[node]
            scc = Set(String).new
            loop do
              successor = stack.pop
              on_stack.delete(successor)
              scc << successor
              break if successor == node
            end
            # Only report cycles (SCCs with more than one node, or self-referencing)
            if scc.size > 1
              sccs << scc
            end
          end
          nil
        end

        dependencies.keys.each do |node|
          strongconnect.call(node) unless index.has_key?(node)
        end

        sccs
      end

      private def generate_down_statements(io : IO)
        @diff.changes.reverse_each do |change|
          case change.type
          when .create_table?
            io << "DROP TABLE IF EXISTS \"#{change.table}\";\n"
          when .drop_table?
            io << "-- Cannot automatically reverse DROP TABLE\n"
            io << "-- Manual recreation required for: #{change.table}\n"
          when .add_column?
            io << "ALTER TABLE \"#{change.table}\" DROP COLUMN \"#{change.column}\";\n"
          when .remove_column?
            io << "-- Cannot automatically reverse DROP COLUMN\n"
            io << "-- Original column: #{change.table}.#{change.column}\n"
          when .change_column_type?
            generate_change_column_type_sql_reverse(io, change)
          when .change_column_nullable?
            generate_change_nullable_sql_reverse(io, change)
          when .add_foreign_key?
            io << "ALTER TABLE \"#{change.table}\" DROP CONSTRAINT \"fk_#{change.table}_#{change.column}\";\n"
          when .remove_foreign_key?
            io << "-- Cannot automatically reverse DROP CONSTRAINT\n"
          when .add_index?
            io << "DROP INDEX IF EXISTS \"index_#{change.table}_on_#{change.column}\";\n"
          when .remove_index?
            io << "-- Cannot automatically reverse DROP INDEX\n"
          end
        end

        if @diff.empty?
          io << "-- No changes to reverse\n"
        end
      end

      private def generate_create_table_sql(io : IO, change : SchemaChange, deferred_fks : Hash(String, Array(ModelForeignKey)) = {} of String => Array(ModelForeignKey))
        io << "CREATE TABLE \"#{change.table}\" (\n"

        columns = [] of String
        constraints = [] of String

        # Get the set of deferred FK columns for this table
        deferred_columns = Set(String).new
        if deferred = deferred_fks[change.table]?
          deferred.each { |fk| deferred_columns << fk.from_column }
        end

        # If we have model schemas, use them for column definitions
        if schemas = @model_schemas
          if model = schemas[change.table]?
            model.columns.each do |col|
              col_sql = String.build do |col_io|
                col_io << "    \"#{col.name}\" #{map_type_to_sql(col.sql_type.to_s)}"
                col_io << " PRIMARY KEY" if col.primary_key
                col_io << " NOT NULL" unless col.nullable
                if default = col.default
                  col_io << " DEFAULT #{default}"
                end
              end
              columns << col_sql
            end

            # Add foreign key constraints (except deferred ones)
            model.foreign_keys.each do |fk|
              # Skip FKs that are deferred due to circular dependencies
              next if deferred_columns.includes?(fk.from_column)

              constraint_name = "fk_#{change.table}_#{fk.from_column}"
              fk_sql = "    CONSTRAINT \"#{constraint_name}\" FOREIGN KEY (\"#{fk.from_column}\") REFERENCES \"#{fk.to_table}\" (\"#{fk.to_column}\")"
              constraints << fk_sql
            end
          end
        end

        if columns.empty?
          # Fallback: create basic table with just id
          columns << "    \"id\" BIGSERIAL PRIMARY KEY"
          io << "    -- TODO: Add columns from model\n"
        end

        # Combine columns and constraints
        all_definitions = columns + constraints
        io << all_definitions.join(",\n")
        io << "\n);\n"
      end

      private def generate_add_column_sql(io : IO, change : SchemaChange)
        type = change.details["type"]? || "text"
        sql_type = map_type_to_sql(type)
        nullable = change.details["nullable"]? == "true"

        io << "ALTER TABLE \"#{change.table}\" ADD COLUMN \"#{change.column}\" #{sql_type}"
        io << " NOT NULL" unless nullable
        io << ";\n"
      end

      private def generate_change_column_type_sql(io : IO, change : SchemaChange)
        if @dialect == :sqlite
          io << "-- SQLite does not support ALTER COLUMN TYPE\n"
          io << "-- Manual migration required for: #{change.table}.#{change.column}\n"
          io << "-- Change from: #{change.details["from"]} to: #{change.details["to"]}\n"
        else
          new_type = map_type_to_sql(change.details["to"]? || "text")
          io << "ALTER TABLE \"#{change.table}\" ALTER COLUMN \"#{change.column}\" TYPE #{new_type};\n"
        end
      end

      private def generate_change_column_type_sql_reverse(io : IO, change : SchemaChange)
        if @dialect == :sqlite
          io << "-- SQLite does not support ALTER COLUMN TYPE\n"
        else
          old_type = map_type_to_sql(change.details["from"]? || "text")
          io << "ALTER TABLE \"#{change.table}\" ALTER COLUMN \"#{change.column}\" TYPE #{old_type};\n"
        end
      end

      private def generate_change_nullable_sql(io : IO, change : SchemaChange)
        if @dialect == :sqlite
          io << "-- SQLite does not support ALTER COLUMN NULL/NOT NULL\n"
          io << "-- Manual migration required for: #{change.table}.#{change.column}\n"
        else
          if change.details["to"]? == "false"
            io << "ALTER TABLE \"#{change.table}\" ALTER COLUMN \"#{change.column}\" SET NOT NULL;\n"
          else
            io << "ALTER TABLE \"#{change.table}\" ALTER COLUMN \"#{change.column}\" DROP NOT NULL;\n"
          end
        end
      end

      private def generate_change_nullable_sql_reverse(io : IO, change : SchemaChange)
        if @dialect == :sqlite
          io << "-- SQLite does not support ALTER COLUMN NULL/NOT NULL\n"
        else
          if change.details["from"]? == "false"
            io << "ALTER TABLE \"#{change.table}\" ALTER COLUMN \"#{change.column}\" SET NOT NULL;\n"
          else
            io << "ALTER TABLE \"#{change.table}\" ALTER COLUMN \"#{change.column}\" DROP NOT NULL;\n"
          end
        end
      end

      private def generate_add_foreign_key_sql(io : IO, change : SchemaChange)
        to_table = change.details["to_table"]? || "unknown"
        to_column = change.details["to_column"]? || "id"

        if @dialect == :sqlite
          io << "-- SQLite does not support ADD CONSTRAINT for foreign keys\n"
          io << "-- Foreign key must be defined when creating the table\n"
          io << "-- #{change.table}.#{change.column} -> #{to_table}.#{to_column}\n"
        else
          io << "ALTER TABLE \"#{change.table}\" ADD CONSTRAINT \"fk_#{change.table}_#{change.column}\" "
          io << "FOREIGN KEY (\"#{change.column}\") REFERENCES \"#{to_table}\" (\"#{to_column}\");\n"
        end
      end

      private def map_type_to_sql(type : String) : String
        case type.downcase
        when "string", "varchar"
          "VARCHAR(255)"
        when "text"
          "TEXT"
        when "integer", "int", "int32"
          "INTEGER"
        when "bigint", "int64"
          "BIGINT"
        when "serial"
          @dialect == :postgres ? "SERIAL" : "INTEGER"
        when "bigserial"
          @dialect == :postgres ? "BIGSERIAL" : "INTEGER"
        when "float", "float32"
          "REAL"
        when "double", "float64"
          @dialect == :postgres ? "DOUBLE PRECISION" : "REAL"
        when "decimal", "numeric"
          "DECIMAL"
        when "boolean", "bool"
          "BOOLEAN"
        when "date"
          "DATE"
        when "time"
          "TIME"
        when "timestamp", "datetime"
          "TIMESTAMP"
        when "json"
          @dialect == :postgres ? "JSON" : "TEXT"
        when "jsonb"
          @dialect == :postgres ? "JSONB" : "TEXT"
        when "uuid"
          @dialect == :postgres ? "UUID" : "CHAR(36)"
        when "binary", "blob", "bytea"
          @dialect == :postgres ? "BYTEA" : "BLOB"
        else
          type.upcase
        end
      end
    end
  end
end

# SQL Migration File Parser and Representation
#
# Parses SQL migration files with -- +migrate Up/Down markers.
# Compatible with goose, micrate, and similar SQL migration tools.
#
# ## File Format
#
# ```sql
# -- +migrate Up
# CREATE TABLE users (
#     id BIGSERIAL PRIMARY KEY,
#     name VARCHAR(255) NOT NULL
# );
#
# -- +migrate Down
# DROP TABLE IF EXISTS users;
# ```
#
# ## Statement Separation
#
# By default, statements are separated by semicolons. For complex statements
# (functions, triggers) that contain semicolons, use StatementBegin/StatementEnd:
#
# ```sql
# -- +migrate Up
# -- +migrate StatementBegin
# CREATE OR REPLACE FUNCTION update_timestamp()
# RETURNS TRIGGER AS $$
# BEGIN
#     NEW.updated_at = NOW();
#     RETURN NEW;
# END;
# $$ LANGUAGE plpgsql;
# -- +migrate StatementEnd
# ```
#
# ## No Transaction
#
# Some statements (like CREATE INDEX CONCURRENTLY) cannot run in a transaction.
# Use the NoTransaction directive:
#
# ```sql
# -- +migrate Up
# -- +migrate NoTransaction
# CREATE INDEX CONCURRENTLY idx_users_email ON users(email);
# ```
module Ralph
  module Migrations
    # Represents a parsed SQL migration file
    class Migration
      # The migration version (timestamp from filename)
      getter version : String

      # The migration name (derived from filename)
      getter name : String

      # Full path to the .sql file
      getter filepath : String

      # SQL statements for the up migration
      getter up_statements : Array(String)

      # SQL statements for the down migration
      getter down_statements : Array(String)

      # Whether to run outside a transaction
      getter? no_transaction : Bool

      def initialize(
        @version : String,
        @name : String,
        @filepath : String,
        @up_statements : Array(String) = [] of String,
        @down_statements : Array(String) = [] of String,
        @no_transaction : Bool = false,
      )
      end

      # Parse a migration file from disk
      def self.from_file(filepath : String) : Migration
        Parser.parse_file(filepath)
      end

      # Check if migration has up statements
      def has_up? : Bool
        !@up_statements.empty?
      end

      # Check if migration has down statements
      def has_down? : Bool
        !@down_statements.empty?
      end

      # Get combined up SQL (for display/debugging)
      def up_sql : String
        @up_statements.join("\n\n")
      end

      # Get combined down SQL (for display/debugging)
      def down_sql : String
        @down_statements.join("\n\n")
      end

      # Comparison for sorting (by version)
      def <=>(other : Migration)
        @version <=> other.version
      end
    end

    # Parser for SQL migration files
    module Parser
      # Directive markers
      MIGRATE_UP       = /^\s*--\s*\+migrate\s+Up\s*$/i
      MIGRATE_DOWN     = /^\s*--\s*\+migrate\s+Down\s*$/i
      STATEMENT_BEGIN  = /^\s*--\s*\+migrate\s+StatementBegin\s*$/i
      STATEMENT_END    = /^\s*--\s*\+migrate\s+StatementEnd\s*$/i
      NO_TRANSACTION   = /^\s*--\s*\+migrate\s+NoTransaction\s*$/i
      SQL_COMMENT      = /^\s*--/
      EMPTY_LINE       = /^\s*$/
      FILENAME_PATTERN = /^(\d+)_(.+)\.sql$/

      # Parse a migration file
      def self.parse_file(filepath : String) : Migration
        unless File.exists?(filepath)
          raise MigrationParseError.new("Migration file not found: #{filepath}")
        end

        filename = File.basename(filepath)
        match = FILENAME_PATTERN.match(filename)
        unless match
          raise MigrationParseError.new(
            "Invalid migration filename: #{filename}. " \
            "Expected format: TIMESTAMP_name.sql (e.g., 20260111143000_create_users.sql)"
          )
        end

        version = match[1]
        name = match[2]

        content = File.read(filepath)
        up_statements, down_statements, no_transaction = parse_content(content)

        Migration.new(
          version: version,
          name: name,
          filepath: filepath,
          up_statements: up_statements,
          down_statements: down_statements,
          no_transaction: no_transaction
        )
      end

      # Parse migration content string
      def self.parse_content(content : String) : Tuple(Array(String), Array(String), Bool)
        up_statements = [] of String
        down_statements = [] of String
        no_transaction = false

        current_section : Symbol? = nil
        lines_buffer = [] of String
        in_statement_block = false

        content.each_line do |line|
          # Check for directives
          if MIGRATE_UP.matches?(line)
            # Flush any pending statement
            flush_statement(lines_buffer, current_section, up_statements, down_statements)
            current_section = :up
            next
          elsif MIGRATE_DOWN.matches?(line)
            flush_statement(lines_buffer, current_section, up_statements, down_statements)
            current_section = :down
            next
          elsif STATEMENT_BEGIN.matches?(line)
            in_statement_block = true
            next
          elsif STATEMENT_END.matches?(line)
            if in_statement_block
              # Flush the entire block as one statement
              flush_statement(lines_buffer, current_section, up_statements, down_statements)
              in_statement_block = false
            end
            next
          elsif NO_TRANSACTION.matches?(line)
            no_transaction = true
            next
          end

          # Skip if we're not in a section yet
          next unless current_section

          # If in a statement block, accumulate everything
          if in_statement_block
            lines_buffer << line
            next
          end

          # Normal mode: accumulate until semicolon
          stripped = line.strip

          # Skip pure comment lines and empty lines for cleaner output
          # but keep them if they're part of a multi-line statement
          if lines_buffer.empty?
            if SQL_COMMENT.matches?(line) && !line.includes?("+migrate")
              next
            elsif EMPTY_LINE.matches?(line)
              next
            end
          end

          lines_buffer << line

          # Check if line ends with semicolon (statement terminator)
          if stripped.ends_with?(";")
            flush_statement(lines_buffer, current_section, up_statements, down_statements)
          end
        end

        # Flush any remaining content
        flush_statement(lines_buffer, current_section, up_statements, down_statements)

        {up_statements, down_statements, no_transaction}
      end

      # Flush current buffer to appropriate statement array
      private def self.flush_statement(
        buffer : Array(String),
        section : Symbol?,
        up : Array(String),
        down : Array(String),
      ) : Nil
        sql = buffer.join("\n").strip
        buffer.clear

        return if sql.empty?

        case section
        when :up
          up << sql
        when :down
          down << sql
        end
      end
    end

    # Error raised when parsing a migration file fails
    class MigrationParseError < Ralph::Error
      def initialize(message : String)
        super(message)
      end
    end
  end
end

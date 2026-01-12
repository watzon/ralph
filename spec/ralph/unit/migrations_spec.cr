require "../../spec_helper"

describe Ralph::Migrations::Migration do
  describe ".from_file" do
    it "parses a valid migration file" do
      # Create a temporary migration file
      Dir.mkdir_p("./tmp/migrations")
      filepath = "./tmp/migrations/20260101120000_create_users.sql"

      content = <<-SQL
      -- Migration: create_users
      -- Created: 2026-01-01

      -- +migrate Up
      CREATE TABLE users (
          id BIGSERIAL PRIMARY KEY,
          name VARCHAR(255) NOT NULL
      );

      CREATE INDEX index_users_on_name ON users (name);

      -- +migrate Down
      DROP INDEX IF EXISTS index_users_on_name;
      DROP TABLE IF EXISTS users;
      SQL

      File.write(filepath, content)

      migration = Ralph::Migrations::Migration.from_file(filepath)

      migration.version.should eq("20260101120000")
      migration.name.should eq("create_users")
      migration.has_up?.should be_true
      migration.has_down?.should be_true
      migration.up_statements.size.should eq(2)
      migration.down_statements.size.should eq(2)

      File.delete(filepath)
    end

    it "parses StatementBegin/StatementEnd blocks" do
      Dir.mkdir_p("./tmp/migrations")
      filepath = "./tmp/migrations/20260101130000_add_function.sql"

      content = <<-SQL
      -- +migrate Up
      -- +migrate StatementBegin
      CREATE OR REPLACE FUNCTION update_timestamp()
      RETURNS TRIGGER AS $$
      BEGIN
          NEW.updated_at = NOW();
          RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
      -- +migrate StatementEnd

      -- +migrate Down
      DROP FUNCTION IF EXISTS update_timestamp();
      SQL

      File.write(filepath, content)

      migration = Ralph::Migrations::Migration.from_file(filepath)

      migration.up_statements.size.should eq(1)
      migration.up_statements[0].should contain("CREATE OR REPLACE FUNCTION")
      migration.up_statements[0].should contain("$$ LANGUAGE plpgsql")

      File.delete(filepath)
    end

    it "parses NoTransaction directive" do
      Dir.mkdir_p("./tmp/migrations")
      filepath = "./tmp/migrations/20260101140000_add_index.sql"

      content = <<-SQL
      -- +migrate NoTransaction

      -- +migrate Up
      CREATE INDEX CONCURRENTLY idx_users_email ON users(email);

      -- +migrate Down
      DROP INDEX CONCURRENTLY IF EXISTS idx_users_email;
      SQL

      File.write(filepath, content)

      migration = Ralph::Migrations::Migration.from_file(filepath)

      migration.no_transaction?.should be_true

      File.delete(filepath)
    end

    it "raises on invalid filename" do
      Dir.mkdir_p("./tmp/migrations")
      filepath = "./tmp/migrations/invalid_migration.sql"
      File.write(filepath, "-- +migrate Up\nSELECT 1;")

      expect_raises(Ralph::Migrations::MigrationParseError) do
        Ralph::Migrations::Migration.from_file(filepath)
      end

      File.delete(filepath)
    end
  end
end

describe Ralph::Migrations::Parser do
  describe ".parse_content" do
    it "separates up and down sections" do
      content = <<-SQL
      -- +migrate Up
      CREATE TABLE test (id INT);

      -- +migrate Down
      DROP TABLE test;
      SQL

      up, down, no_tx = Ralph::Migrations::Parser.parse_content(content)

      up.size.should eq(1)
      down.size.should eq(1)
      no_tx.should be_false
    end

    it "handles multiple statements in each section" do
      content = <<-SQL
      -- +migrate Up
      CREATE TABLE users (id INT);
      CREATE TABLE posts (id INT);
      CREATE INDEX idx_posts ON posts (id);

      -- +migrate Down
      DROP INDEX idx_posts;
      DROP TABLE posts;
      DROP TABLE users;
      SQL

      up, down, _ = Ralph::Migrations::Parser.parse_content(content)

      up.size.should eq(3)
      down.size.should eq(3)
    end

    it "handles empty sections" do
      content = <<-SQL
      -- +migrate Up

      -- +migrate Down
      SQL

      up, down, _ = Ralph::Migrations::Parser.parse_content(content)

      up.size.should eq(0)
      down.size.should eq(0)
    end

    it "ignores content before first directive" do
      content = <<-SQL
      -- This is a comment
      -- Another comment
      SELECT 1;

      -- +migrate Up
      CREATE TABLE test (id INT);

      -- +migrate Down
      DROP TABLE test;
      SQL

      up, down, _ = Ralph::Migrations::Parser.parse_content(content)

      up.size.should eq(1)
      up[0].should contain("CREATE TABLE")
    end
  end
end

describe Ralph::Migrations::Migrator do
  describe ".create" do
    it "creates a migration file with correct format" do
      Dir.mkdir_p("./tmp/test_migrations")

      path = Ralph::Migrations::Migrator.create("create_products", "./tmp/test_migrations")

      path.should match(/^\.\/(tmp\/test_migrations)\/\d{14}_create_products\.sql$/)
      File.exists?(path).should be_true

      content = File.read(path)
      content.should contain("-- +migrate Up")
      content.should contain("-- +migrate Down")

      File.delete(path)
    end

    it "converts name to snake_case" do
      Dir.mkdir_p("./tmp/test_migrations")

      path = Ralph::Migrations::Migrator.create("CreateUsersTable", "./tmp/test_migrations")

      path.should contain("create_users_table.sql")
      File.delete(path)
    end
  end
end

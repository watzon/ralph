require "../spec_helper"
require "file_utils"
require "db"

module RalphTestHelper
  @@db_path : String? = nil

  def self.setup_test_database
    @@db_path = "/tmp/ralph_test_#{Process.pid}.sqlite3"

    Ralph.configure do |config|
      config.database = Ralph::Database::SqliteBackend.new("sqlite3://#{@@db_path}")
    end

    # Create test schema
    Ralph.database.execute <<-SQL
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name VARCHAR(255) NOT NULL,
      email VARCHAR(255) NOT NULL,
      age INTEGER,
      active BOOLEAN,
      skip_callback BOOLEAN,
      created_at TIMESTAMP
    )
    SQL

    Ralph.database.execute <<-SQL
    CREATE TABLE IF NOT EXISTS posts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title VARCHAR(255) NOT NULL,
      user_id INTEGER,
      views INTEGER DEFAULT 0,
      published BOOLEAN DEFAULT 0
    )
    SQL
  end

  def self.cleanup_test_database
    if path = @@db_path
      File.delete(path) if File.exists?(path)
    end
  end

  def self.clear_tables
    Ralph.database.execute("DELETE FROM users")
    Ralph.database.execute("DELETE FROM posts")
  end
end

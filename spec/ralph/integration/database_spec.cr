require "../../spec_helper"

# Integration tests for SQLite backend
describe Ralph::Database::SqliteBackend do
  db_path = "/tmp/ralph_integration_test_#{Process.pid}.sqlite3"

  before_all do
    Ralph.configure do |config|
      config.database = Ralph::Database::SqliteBackend.new("sqlite3://#{db_path}")
    end

    # Create test schema
    Ralph.database.execute <<-SQL
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name VARCHAR(255) NOT NULL,
      email VARCHAR(255) NOT NULL,
      age INTEGER,
      created_at TIMESTAMP
    )
    SQL
  end

  before_each do
    Ralph.database.execute("DELETE FROM users")
  end

  after_all do
    File.delete(db_path) if File.exists?(db_path)
  end

  it "executes SQL statements" do
    Ralph.database.execute("INSERT INTO users (name, email) VALUES (?, ?)", args: ["Test User", "test@example.com"] of DB::Any)

    result = Ralph.database.query_all("SELECT COUNT(*) FROM users")
    result.each do
      count = result.read(Int32)
      count.should be > 0
    end
  ensure
    result.close if result
  end

  it "returns last insert ID" do
    id = Ralph.database.insert("INSERT INTO users (name, email) VALUES (?, ?)", args: ["Another User", "another@example.com"] of DB::Any)
    id.should be_a(Int64)
  end

  it "increments insert ID" do
    id1 = Ralph.database.insert("INSERT INTO users (name, email) VALUES (?, ?)", args: ["User 1", "user1@example.com"] of DB::Any)
    id2 = Ralph.database.insert("INSERT INTO users (name, email) VALUES (?, ?)", args: ["User 2", "user2@example.com"] of DB::Any)

    id2.should eq(id1 + 1)
  end

  it "queries and reads results" do
    Ralph.database.execute("INSERT INTO users (name, email) VALUES (?, ?)", args: ["Query Test", "query@example.com"] of DB::Any)

    result = Ralph.database.query_all("SELECT name, email FROM users")
    found = false
    result.each do
      name = result.read(String)
      email = result.read(String)
      found = true if name == "Query Test" && email == "query@example.com"
    end
    found.should be_true
  ensure
    result.close if result
  end

  it "supports transactions" do
    Ralph.database.transaction do |tx|
      cnn = tx.connection
      cnn.exec("INSERT INTO users (name, email) VALUES ('Tx User 1', 'tx1@example.com')")
      cnn.exec("INSERT INTO users (name, email) VALUES ('Tx User 2', 'tx2@example.com')")
    end

    result = Ralph.database.query_all("SELECT COUNT(*) FROM users")
    result.each do
      count = result.read(Int32)
      count.should be > 0
    end
  ensure
    result.close if result
  end

  it "reports closed status" do
    db = Ralph::Database::SqliteBackend.new("sqlite3:///tmp/ralph_closed_test_#{Process.pid}.sqlite3")
    db.closed?.should be_false

    db.close
    db.closed?.should be_true

    File.delete("/tmp/ralph_closed_test_#{Process.pid}.sqlite3") if File.exists?("/tmp/ralph_closed_test_#{Process.pid}.sqlite3")
  end
end

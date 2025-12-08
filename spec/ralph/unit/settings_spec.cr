require "../../spec_helper"

# Unit tests for Settings
describe Ralph::Settings do
  it "has configurable database" do
    settings = Ralph::Settings.new
    settings.database.should be_nil

    # Create a test database connection
    db = Ralph::Database::SqliteBackend.new("sqlite3:///tmp/ralph_settings_test_#{Process.pid}.sqlite3")
    settings.database = db
    settings.database.should eq(db)

    db.close
    File.delete("/tmp/ralph_settings_test_#{Process.pid}.sqlite3") if File.exists?("/tmp/ralph_settings_test_#{Process.pid}.sqlite3")
  end
end

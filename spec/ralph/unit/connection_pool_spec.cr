require "../../spec_helper"

# Unit tests for Connection Pool Configuration
describe "Connection Pool Configuration" do
  describe Ralph::Settings do
    describe "pool settings" do
      it "has default pool configuration values" do
        settings = Ralph::Settings.new

        # Defaults are conservative (1 connection) for SQLite compatibility
        # PostgreSQL users should increase these for production
        settings.initial_pool_size.should eq 1
        settings.max_pool_size.should eq 0 # unlimited
        settings.max_idle_pool_size.should eq 1
        settings.checkout_timeout.should eq 5.0
        settings.retry_attempts.should eq 3
        settings.retry_delay.should eq 0.2
      end

      it "allows customizing pool settings" do
        settings = Ralph::Settings.new

        settings.initial_pool_size = 10
        settings.max_pool_size = 50
        settings.max_idle_pool_size = 10
        settings.checkout_timeout = 15.0
        settings.retry_attempts = 5
        settings.retry_delay = 1.0

        settings.initial_pool_size.should eq 10
        settings.max_pool_size.should eq 50
        settings.max_idle_pool_size.should eq 10
        settings.checkout_timeout.should eq 15.0
        settings.retry_attempts.should eq 5
        settings.retry_delay.should eq 1.0
      end

      it "generates pool_params hash" do
        settings = Ralph::Settings.new
        settings.initial_pool_size = 3
        settings.max_pool_size = 25
        settings.max_idle_pool_size = 5

        params = settings.pool_params

        params["initial_pool_size"].should eq "3"
        params["max_pool_size"].should eq "25"
        params["max_idle_pool_size"].should eq "5"
        params["checkout_timeout"].should eq "5.0"
        params["retry_attempts"].should eq "3"
        params["retry_delay"].should eq "0.2"
      end
    end

    describe "#validate_pool_settings" do
      it "returns empty array for valid settings" do
        settings = Ralph::Settings.new
        warnings = settings.validate_pool_settings
        warnings.should be_empty
      end

      it "warns about negative initial_pool_size" do
        settings = Ralph::Settings.new
        settings.initial_pool_size = -1

        warnings = settings.validate_pool_settings
        warnings.size.should eq 1
        warnings[0].should contain "initial_pool_size cannot be negative"
      end

      it "warns about negative max_pool_size" do
        settings = Ralph::Settings.new
        settings.max_pool_size = -5

        warnings = settings.validate_pool_settings
        warnings.size.should eq 1
        warnings[0].should contain "max_pool_size cannot be negative"
      end

      it "warns when initial_pool_size exceeds max_pool_size" do
        settings = Ralph::Settings.new
        settings.initial_pool_size = 20
        settings.max_pool_size = 10

        warnings = settings.validate_pool_settings
        warnings.size.should eq 1
        warnings[0].should contain "initial_pool_size (20) exceeds max_pool_size (10)"
      end

      it "does not warn when max_pool_size is 0 (unlimited)" do
        settings = Ralph::Settings.new
        settings.initial_pool_size = 100
        settings.max_pool_size = 0 # unlimited

        warnings = settings.validate_pool_settings
        warnings.should be_empty
      end

      it "warns about negative max_idle_pool_size" do
        settings = Ralph::Settings.new
        settings.max_idle_pool_size = -1

        warnings = settings.validate_pool_settings
        warnings.size.should eq 1
        warnings[0].should contain "max_idle_pool_size cannot be negative"
      end

      it "warns when max_idle_pool_size exceeds max_pool_size" do
        settings = Ralph::Settings.new
        settings.max_idle_pool_size = 30
        settings.max_pool_size = 20

        warnings = settings.validate_pool_settings
        warnings.size.should eq 1
        warnings[0].should contain "max_idle_pool_size (30) exceeds max_pool_size (20)"
      end

      it "warns about non-positive checkout_timeout" do
        settings = Ralph::Settings.new
        settings.checkout_timeout = 0.0

        warnings = settings.validate_pool_settings
        warnings.size.should eq 1
        warnings[0].should contain "checkout_timeout must be positive"
      end

      it "warns about negative retry_attempts" do
        settings = Ralph::Settings.new
        settings.retry_attempts = -1

        warnings = settings.validate_pool_settings
        warnings.size.should eq 1
        warnings[0].should contain "retry_attempts cannot be negative"
      end

      it "warns about negative retry_delay" do
        settings = Ralph::Settings.new
        settings.retry_delay = -0.5

        warnings = settings.validate_pool_settings
        warnings.size.should eq 1
        warnings[0].should contain "retry_delay cannot be negative"
      end

      it "returns multiple warnings for multiple issues" do
        settings = Ralph::Settings.new
        settings.initial_pool_size = -1
        settings.checkout_timeout = 0.0
        settings.retry_delay = -1.0

        warnings = settings.validate_pool_settings
        warnings.size.should eq 3
      end
    end
  end

  describe Ralph::Database::PoolStats do
    it "can be created with connection statistics" do
      stats = Ralph::Database::PoolStats.new(
        open_connections: 5,
        idle_connections: 3,
        in_flight_connections: 2,
        max_connections: 10
      )

      stats.open_connections.should eq 5
      stats.idle_connections.should eq 3
      stats.in_flight_connections.should eq 2
      stats.max_connections.should eq 10
    end
  end
end

describe "Connection Pool Integration" do
  describe Ralph::Database::SqliteBackend do
    it "applies pool settings from Ralph.settings" do
      # Configure custom pool settings
      original_initial = Ralph.settings.initial_pool_size
      original_max = Ralph.settings.max_pool_size

      Ralph.settings.initial_pool_size = 3
      Ralph.settings.max_pool_size = 10

      # Create backend (it should apply these settings)
      db_path = "/tmp/ralph_pool_test_#{Process.pid}.sqlite3"
      db = Ralph::Database::SqliteBackend.new("sqlite3://#{db_path}")

      begin
        # The backend should have pool stats available
        stats = db.pool_stats
        stats.should_not be_nil

        # Pool should have been created with our settings
        # Note: open_connections may vary based on initial_pool_size
        stats.open_connections.should be >= 1
      ensure
        db.close
        File.delete(db_path) if File.exists?(db_path)

        # Restore original settings
        Ralph.settings.initial_pool_size = original_initial
        Ralph.settings.max_pool_size = original_max
      end
    end

    it "can skip pool settings with apply_pool_settings: false" do
      db_path = "/tmp/ralph_pool_test2_#{Process.pid}.sqlite3"
      db = Ralph::Database::SqliteBackend.new("sqlite3://#{db_path}", apply_pool_settings: false)

      begin
        # Should still work but with default pool settings
        stats = db.pool_stats
        stats.should_not be_nil
        stats.open_connections.should be >= 1
      ensure
        db.close
        File.delete(db_path) if File.exists?(db_path)
      end
    end

    it "returns pool_healthy? true for working database" do
      db_path = "/tmp/ralph_pool_health_#{Process.pid}.sqlite3"
      db = Ralph::Database::SqliteBackend.new("sqlite3://#{db_path}")

      begin
        db.pool_healthy?.should be_true
      ensure
        db.close
        File.delete(db_path) if File.exists?(db_path)
      end
    end

    it "preserves connection_string getter" do
      original_url = "sqlite3:///tmp/ralph_pool_url_#{Process.pid}.sqlite3"
      db = Ralph::Database::SqliteBackend.new(original_url)

      begin
        # Should return the original URL (without pool params)
        db.connection_string.should eq original_url
      ensure
        db.close
        File.delete("/tmp/ralph_pool_url_#{Process.pid}.sqlite3") if File.exists?("/tmp/ralph_pool_url_#{Process.pid}.sqlite3")
      end
    end
  end

  describe "Ralph module helpers" do
    before_each do
      db_path = "/tmp/ralph_module_pool_#{Process.pid}.sqlite3"
      Ralph.configure do |config|
        config.database = Ralph::Database::SqliteBackend.new("sqlite3://#{db_path}")
      end
    end

    after_each do
      Ralph.settings.database.try(&.close)
      File.delete("/tmp/ralph_module_pool_#{Process.pid}.sqlite3") if File.exists?("/tmp/ralph_module_pool_#{Process.pid}.sqlite3")
    end

    it "returns pool_stats from Ralph.pool_stats" do
      stats = Ralph.pool_stats
      stats.should_not be_nil

      stats = stats.not_nil!
      stats.open_connections.should be >= 1
      stats.idle_connections.should be >= 0
    end

    it "returns true from Ralph.pool_healthy? when database is healthy" do
      Ralph.pool_healthy?.should be_true
    end

    it "returns pool_info with configuration and stats" do
      info = Ralph.pool_info

      # Should include configuration
      info["initial_pool_size"].should eq Ralph.settings.initial_pool_size
      info["max_pool_size"].should eq Ralph.settings.max_pool_size
      info["checkout_timeout"].should eq Ralph.settings.checkout_timeout

      # Should include runtime stats
      info.has_key?("open_connections").should be_true
      info.has_key?("idle_connections").should be_true

      # Should include health status
      info["healthy"].should be_true

      # Should include backend info
      info["dialect"].should eq "sqlite"
      info["closed"].should eq false
    end

    it "returns empty warnings from Ralph.validate_pool_config with valid settings" do
      warnings = Ralph.validate_pool_config
      warnings.should be_empty
    end
  end

  describe "pool_stats returns nil when no database configured" do
    it "returns nil from Ralph.pool_stats when database is nil" do
      # Save current database
      original_db = Ralph.settings.database

      begin
        Ralph.settings.database = nil
        Ralph.pool_stats.should be_nil
      ensure
        Ralph.settings.database = original_db
      end
    end

    it "returns false from Ralph.pool_healthy? when database is nil" do
      original_db = Ralph.settings.database

      begin
        Ralph.settings.database = nil
        Ralph.pool_healthy?.should be_false
      ensure
        Ralph.settings.database = original_db
      end
    end
  end
end

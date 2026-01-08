require "../../postgres_spec_helper"

postgres_url = ENV["POSTGRES_URL"]?

{% if flag?(:skip_postgres_tests) %}
  # Skip all postgres tests when flag is set
{% else %}
  describe Ralph::Database::PostgresBackend do
    if postgres_url.nil?
      pending "Requires POSTGRES_URL environment variable"
    end

    describe "with POSTGRES_URL set" do
      before_all do
        if url = postgres_url
          Ralph.configure do |config|
            config.database = Ralph::Database::PostgresBackend.new(url)
          end

          Ralph.database.execute("DROP TABLE IF EXISTS test_users CASCADE")
          Ralph.database.execute <<-SQL
        CREATE TABLE IF NOT EXISTS test_users (
          id BIGSERIAL PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          email VARCHAR(255) NOT NULL,
          age INTEGER,
          created_at TIMESTAMP
        )
        SQL
        end
      end

      before_each do
        if postgres_url
          Ralph.database.execute("TRUNCATE TABLE test_users RESTART IDENTITY")
        end
      end

      after_all do
        if postgres_url
          Ralph.database.execute("DROP TABLE IF EXISTS test_users CASCADE")
        end
      end

      it "executes SQL statements" do
        next unless postgres_url

        Ralph.database.execute("INSERT INTO test_users (name, email) VALUES ($1, $2)", args: ["Test User", "test@example.com"] of DB::Any)

        result = Ralph.database.query_all("SELECT COUNT(*) FROM test_users")
        result.each do
          count = result.read(Int64)
          count.should be > 0
        end
      ensure
        result.try(&.close)
      end

      it "returns last insert ID via RETURNING" do
        next unless postgres_url

        id = Ralph.database.insert("INSERT INTO test_users (name, email) VALUES ($1, $2)", args: ["Another User", "another@example.com"] of DB::Any)
        id.should be_a(Int64)
        id.should eq(1_i64)
      end

      it "increments insert ID" do
        next unless postgres_url

        id1 = Ralph.database.insert("INSERT INTO test_users (name, email) VALUES ($1, $2)", args: ["User 1", "user1@example.com"] of DB::Any)
        id2 = Ralph.database.insert("INSERT INTO test_users (name, email) VALUES ($1, $2)", args: ["User 2", "user2@example.com"] of DB::Any)

        id2.should eq(id1 + 1)
      end

      it "queries and reads results" do
        next unless postgres_url

        Ralph.database.execute("INSERT INTO test_users (name, email) VALUES ($1, $2)", args: ["Query Test", "query@example.com"] of DB::Any)

        result = Ralph.database.query_all("SELECT name, email FROM test_users")
        found = false
        result.each do
          name = result.read(String)
          email = result.read(String)
          found = true if name == "Query Test" && email == "query@example.com"
        end
        found.should be_true
      ensure
        result.try(&.close)
      end

      it "supports transactions" do
        next unless postgres_url

        Ralph.database.transaction do |tx|
          cnn = tx.connection
          cnn.exec("INSERT INTO test_users (name, email) VALUES ('Tx User 1', 'tx1@example.com')")
          cnn.exec("INSERT INTO test_users (name, email) VALUES ('Tx User 2', 'tx2@example.com')")
        end

        result = Ralph.database.query_all("SELECT COUNT(*) FROM test_users")
        result.each do
          count = result.read(Int64)
          count.should eq(2)
        end
      ensure
        result.try(&.close)
      end

      it "rolls back transactions on error" do
        next unless postgres_url

        begin
          Ralph.database.transaction do |tx|
            cnn = tx.connection
            cnn.exec("INSERT INTO test_users (name, email) VALUES ('Rollback Test', 'rollback@example.com')")
            raise "Intentional error"
          end
        rescue
        end

        result = Ralph.database.query_all("SELECT COUNT(*) FROM test_users")
        result.each do
          count = result.read(Int64)
          count.should eq(0)
        end
      ensure
        result.try(&.close)
      end

      it "supports savepoints for nested transactions" do
        next unless postgres_url

        Ralph.database.execute(Ralph.database.begin_transaction_sql)
        Ralph.database.execute("INSERT INTO test_users (name, email) VALUES ('Outer', 'outer@example.com')")

        Ralph.database.execute(Ralph.database.savepoint_sql("sp1"))
        Ralph.database.execute("INSERT INTO test_users (name, email) VALUES ('Inner', 'inner@example.com')")
        Ralph.database.execute(Ralph.database.rollback_to_savepoint_sql("sp1"))
        Ralph.database.execute(Ralph.database.release_savepoint_sql("sp1"))

        Ralph.database.execute(Ralph.database.commit_sql)

        result = Ralph.database.query_all("SELECT COUNT(*) FROM test_users")
        result.each do
          count = result.read(Int64)
          count.should eq(1)
        end
      ensure
        result.try(&.close)
      end

      it "reports dialect as postgres" do
        next unless postgres_url

        Ralph.database.dialect.should eq(:postgres)
      end

      it "reports closed status" do
        next unless postgres_url

        db = Ralph::Database::PostgresBackend.new(postgres_url.not_nil!)
        db.closed?.should be_false

        db.close
        db.closed?.should be_true
      end
    end
  end
{% end %}

require "../../postgres_spec_helper"

{% if flag?(:skip_postgres_tests) %}
  # Skip all postgres tests when flag is set
{% else %}
  describe "PostgreSQL Schema Features", tags: "postgres" do
    before_all do
      Ralph.configure do |config|
        config.database = Ralph::Database::PostgresBackend.new(POSTGRES_URL)
      end

      # Set dialect for schema generation
      Ralph::Migrations::Schema::Dialect.set_from_backend(Ralph.database)
    end

    describe "GIN Index Definitions" do
      it "generates correct SQL for GIN index" do
        index = Ralph::Migrations::Schema::GinIndexDefinition.new(
          "test_table", "metadata", "idx_test_metadata_gin", true
        )
        sql = index.to_sql
        sql.should contain("CREATE INDEX IF NOT EXISTS")
        sql.should contain("USING gin")
        sql.should contain("\"metadata\"")
      end

      it "generates correct SQL for GIN index without fastupdate" do
        index = Ralph::Migrations::Schema::GinIndexDefinition.new(
          "test_table", "metadata", "idx_test_metadata_gin", false
        )
        sql = index.to_sql
        sql.should contain("WITH (fastupdate = off)")
      end

      it "generates drop SQL" do
        index = Ralph::Migrations::Schema::GinIndexDefinition.new(
          "test_table", "metadata", "idx_test_metadata_gin", true
        )
        sql = index.to_drop_sql
        sql.should eq("DROP INDEX IF EXISTS \"idx_test_metadata_gin\"")
      end
    end

    describe "GiST Index Definitions" do
      it "generates correct SQL for single column GiST index" do
        index = Ralph::Migrations::Schema::GistIndexDefinition.new(
          "test_table", "location", "idx_test_location_gist"
        )
        sql = index.to_sql
        sql.should contain("CREATE INDEX IF NOT EXISTS")
        sql.should contain("USING gist")
        sql.should contain("\"location\"")
      end

      it "generates correct SQL for multi-column GiST index" do
        index = Ralph::Migrations::Schema::GistIndexDefinition.new(
          "test_table", ["latitude", "longitude"], "idx_test_coords_gist"
        )
        sql = index.to_sql
        sql.should contain("\"latitude\", \"longitude\"")
      end
    end

    describe "Full-Text Search Index Definitions" do
      it "generates correct SQL for single column FTS index" do
        index = Ralph::Migrations::Schema::FullTextIndexDefinition.new(
          "articles", "content", "idx_articles_content_fts", "english", true
        )
        sql = index.to_sql

        sql.should contain("CREATE INDEX IF NOT EXISTS")
        sql.should contain("USING gin")
        sql.should contain("to_tsvector('english', \"content\")")
      end

      it "generates correct SQL for multi-column FTS index" do
        index = Ralph::Migrations::Schema::FullTextIndexDefinition.new(
          "articles", ["title", "content"], "idx_articles_search_fts", "english", true
        )
        sql = index.to_sql

        sql.should contain("coalesce(\"title\", '') || ' ' || coalesce(\"content\", '')")
      end

      it "supports different language configurations" do
        index = Ralph::Migrations::Schema::FullTextIndexDefinition.new(
          "articles", "content", "idx_articles_content_french", "french", true
        )
        sql = index.to_sql

        sql.should contain("to_tsvector('french', \"content\")")
      end
    end

    describe "Partial Index Definitions" do
      it "generates correct SQL for partial index" do
        index = Ralph::Migrations::Schema::PartialIndexDefinition.new(
          "users", "email", "idx_active_users_email", "active = true", false
        )
        sql = index.to_sql

        sql.should contain("CREATE INDEX IF NOT EXISTS")
        sql.should contain("WHERE active = true")
      end

      it "generates correct SQL for unique partial index" do
        index = Ralph::Migrations::Schema::PartialIndexDefinition.new(
          "posts", "slug", "idx_published_slugs", "status = 'published'", true
        )
        sql = index.to_sql

        sql.should contain("CREATE UNIQUE INDEX IF NOT EXISTS")
        sql.should contain("WHERE status = 'published'")
      end
    end

    describe "Expression Index Definitions" do
      it "generates correct SQL for expression index" do
        index = Ralph::Migrations::Schema::ExpressionIndexDefinition.new(
          "users", "lower(email)", "idx_users_email_lower", false, nil
        )
        sql = index.to_sql

        sql.should contain("CREATE INDEX IF NOT EXISTS")
        sql.should contain("lower(email)")
      end

      it "generates correct SQL for unique expression index" do
        index = Ralph::Migrations::Schema::ExpressionIndexDefinition.new(
          "users", "lower(email)", "idx_users_email_lower_unique", true, nil
        )
        sql = index.to_sql

        sql.should contain("CREATE UNIQUE INDEX IF NOT EXISTS")
      end

      it "supports custom index method" do
        index = Ralph::Migrations::Schema::ExpressionIndexDefinition.new(
          "data", "jsonb_column->>'key'", "idx_data_key", false, "btree"
        )
        sql = index.to_sql

        sql.should contain("USING btree")
      end
    end

    describe "TableDefinition PostgreSQL Index Methods" do
      it "creates GIN index via TableDefinition" do
        definition = Ralph::Migrations::Schema::TableDefinition.new("test_pg_indexes")
        definition.jsonb("metadata")
        definition.gin_index("metadata", name: "idx_test_metadata")

        definition.gin_indexes.size.should eq(1)
        definition.gin_indexes.first.name.should eq("idx_test_metadata")
      end

      it "creates GiST index via TableDefinition" do
        definition = Ralph::Migrations::Schema::TableDefinition.new("test_pg_indexes")
        definition.float("latitude")
        definition.float("longitude")
        definition.gist_index("latitude", name: "idx_test_lat")

        definition.gist_indexes.size.should eq(1)
      end

      it "creates full-text index via TableDefinition" do
        definition = Ralph::Migrations::Schema::TableDefinition.new("test_pg_indexes")
        definition.text("content")
        definition.full_text_index("content", config: "english")

        definition.full_text_indexes.size.should eq(1)
      end

      it "creates partial index via TableDefinition" do
        definition = Ralph::Migrations::Schema::TableDefinition.new("test_pg_indexes")
        definition.string("email")
        definition.boolean("active")
        definition.partial_index("email", condition: "active = true", unique: true)

        definition.partial_indexes.size.should eq(1)
        definition.partial_indexes.first.unique.should be_true
      end

      it "creates expression index via TableDefinition" do
        definition = Ralph::Migrations::Schema::TableDefinition.new("test_pg_indexes")
        definition.string("email")
        definition.expression_index("lower(email)", name: "idx_email_lower")

        definition.expression_indexes.size.should eq(1)
      end

      it "returns all PostgreSQL indexes via postgres_indexes" do
        definition = Ralph::Migrations::Schema::TableDefinition.new("test_pg_indexes")
        definition.gin_index("col1")
        definition.gist_index("col2")
        definition.full_text_index("col3")
        definition.partial_index("col4", condition: "x = true")
        definition.expression_index("lower(col5)", name: "idx_lower")

        definition.postgres_indexes.size.should eq(5)
      end
    end

    describe "Integration: Creating and Dropping Indexes" do
      before_each do
        Ralph.database.execute("DROP TABLE IF EXISTS pg_index_test CASCADE")
        Ralph.database.execute <<-SQL
          CREATE TABLE pg_index_test (
            id BIGSERIAL PRIMARY KEY,
            name VARCHAR(255),
            email VARCHAR(255),
            content TEXT,
            metadata JSONB,
            tags VARCHAR(255)[],
            active BOOLEAN DEFAULT true,
            created_at TIMESTAMP DEFAULT NOW()
          )
        SQL
      end

      after_each do
        Ralph.database.execute("DROP TABLE IF EXISTS pg_index_test CASCADE")
      end

      it "creates and drops GIN index" do
        # Create index
        index = Ralph::Migrations::Schema::GinIndexDefinition.new(
          "pg_index_test", "metadata", "idx_test_gin", true
        )
        Ralph.database.execute(index.to_sql)

        # Verify exists
        result = Ralph.database.query_all(
          "SELECT indexname FROM pg_indexes WHERE tablename = 'pg_index_test' AND indexname = 'idx_test_gin'"
        )
        found = false
        result.each { found = true }
        result.close
        found.should be_true

        # Drop index
        Ralph.database.execute(index.to_drop_sql)

        # Verify dropped
        result = Ralph.database.query_all(
          "SELECT indexname FROM pg_indexes WHERE tablename = 'pg_index_test' AND indexname = 'idx_test_gin'"
        )
        found = false
        result.each { found = true }
        result.close
        found.should be_false
      end

      it "creates and drops full-text search index" do
        index = Ralph::Migrations::Schema::FullTextIndexDefinition.new(
          "pg_index_test", "content", "idx_test_fts", "english", true
        )
        Ralph.database.execute(index.to_sql)

        # Verify exists
        result = Ralph.database.query_all(
          "SELECT indexname FROM pg_indexes WHERE tablename = 'pg_index_test' AND indexname = 'idx_test_fts'"
        )
        found = false
        result.each { found = true }
        result.close
        found.should be_true

        # Drop
        Ralph.database.execute(index.to_drop_sql)
      end

      it "creates and drops partial index" do
        index = Ralph::Migrations::Schema::PartialIndexDefinition.new(
          "pg_index_test", "email", "idx_test_partial", "active = true", true
        )
        Ralph.database.execute(index.to_sql)

        # Verify exists
        result = Ralph.database.query_all(
          "SELECT indexname FROM pg_indexes WHERE tablename = 'pg_index_test' AND indexname = 'idx_test_partial'"
        )
        found = false
        result.each { found = true }
        result.close
        found.should be_true

        # Drop
        Ralph.database.execute(index.to_drop_sql)
      end

      it "creates and drops expression index" do
        index = Ralph::Migrations::Schema::ExpressionIndexDefinition.new(
          "pg_index_test", "lower(email)", "idx_test_expr", true, nil
        )
        Ralph.database.execute(index.to_sql)

        # Verify exists
        result = Ralph.database.query_all(
          "SELECT indexname FROM pg_indexes WHERE tablename = 'pg_index_test' AND indexname = 'idx_test_expr'"
        )
        found = false
        result.each { found = true }
        result.close
        found.should be_true

        # Drop
        Ralph.database.execute(index.to_drop_sql)
      end
    end
  end
{% end %}

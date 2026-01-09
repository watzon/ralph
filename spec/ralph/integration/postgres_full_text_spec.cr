require "../../postgres_spec_helper"

{% if flag?(:skip_postgres_tests) %}
  # Skip all postgres tests when flag is set
{% else %}
  describe "PostgreSQL Full-Text Search", tags: "postgres" do
    before_all do
      Ralph.configure do |config|
        config.database = Ralph::Database::PostgresBackend.new(POSTGRES_URL)
      end

      # Set dialect for schema generation
      Ralph::Migrations::Schema::Dialect.set_from_backend(Ralph.database)

      # Setup test tables
      Ralph.database.execute("DROP TABLE IF EXISTS fts_articles CASCADE")
      Ralph.database.execute <<-SQL
        CREATE TABLE IF NOT EXISTS fts_articles (
          id BIGSERIAL PRIMARY KEY,
          title VARCHAR(255),
          content TEXT,
          author VARCHAR(255),
          tags VARCHAR(255)[],
          created_at TIMESTAMP DEFAULT NOW()
        )
      SQL

      # Insert test data (arrays as PostgreSQL array literals since DB::Any doesn't support Array(String))
      Ralph.database.execute("INSERT INTO fts_articles (title, content, author, tags) VALUES ($1, $2, $3, '{crystal,orm,tutorial}')",
        args: ["Crystal ORM Tutorial", "Learn how to use Ralph ORM for Crystal programming language. Crystal is fast and type-safe.", "John Doe"] of DB::Any)
      Ralph.database.execute("INSERT INTO fts_articles (title, content, author, tags) VALUES ($1, $2, $3, '{ruby,rails,web}')",
        args: ["Ruby on Rails Guide", "Complete guide to Ruby on Rails web framework. Build web applications quickly.", "Jane Smith"] of DB::Any)
      Ralph.database.execute("INSERT INTO fts_articles (title, content, author, tags) VALUES ($1, $2, $3, '{crystal,programming}')",
        args: ["Crystal Programming", "Crystal is a statically typed language with Ruby-like syntax. It compiles to native code.", "Bob Johnson"] of DB::Any)
      Ralph.database.execute("INSERT INTO fts_articles (title, content, author, tags) VALUES ($1, $2, $3, '{postgresql,database,sql}')",
        args: ["PostgreSQL Database", "PostgreSQL is a powerful open-source relational database with advanced features.", "Alice Williams"] of DB::Any)
    end

    after_all do
      Ralph.database.execute("DROP TABLE IF EXISTS fts_articles CASCADE")
    end

    describe "#where_search" do
      it "generates correct SQL for single column search" do
        query = Ralph::Query::Builder.new("fts_articles").where_search("title", "crystal")
        sql = query.build_select
        sql.should contain("to_tsvector('english', \"title\") @@ plainto_tsquery('english', ")
      end

      it "finds articles matching search term in title" do
        result = Ralph.database.query_all(
          Ralph::Query::Builder.new("fts_articles")
            .where_search("title", "crystal")
            .build_select,
          args: ["crystal"] of DB::Any
        )

        found_titles = [] of String
        result.each do
          found_titles << result.read(Int64).to_s # id
          found_titles << result.read(String)     # title
          result.read(String?)                    # content
          result.read(String?)                    # author
          result.read(Array(String)?)             # tags
          result.read(Time?)                      # created_at
        end
        result.close

        found_titles.should contain("Crystal ORM Tutorial")
        found_titles.should contain("Crystal Programming")
      end

      it "uses custom text search configuration" do
        query = Ralph::Query::Builder.new("fts_articles").where_search("content", "programming", config: "simple")
        sql = query.build_select
        sql.should contain("to_tsvector('simple', \"content\")")
        sql.should contain("plainto_tsquery('simple', ")
      end
    end

    describe "#where_search_multi" do
      it "generates correct SQL for multi-column search" do
        query = Ralph::Query::Builder.new("fts_articles").where_search_multi(["title", "content"], "crystal framework")
        sql = query.build_select
        sql.should contain("coalesce(\"title\", '') || ' ' || coalesce(\"content\", '')")
      end

      it "finds articles matching in either column" do
        result = Ralph.database.query_all(
          Ralph::Query::Builder.new("fts_articles")
            .where_search_multi(["title", "content"], "database")
            .build_select,
          args: ["database"] of DB::Any
        )

        count = 0
        result.each { count += 1 }
        result.close

        count.should be > 0
      end
    end

    describe "#where_websearch" do
      it "generates correct SQL for websearch syntax" do
        query = Ralph::Query::Builder.new("fts_articles").where_websearch("content", "crystal -ruby")
        sql = query.build_select
        sql.should contain("websearch_to_tsquery")
      end
    end

    describe "#where_phrase_search" do
      it "generates correct SQL for phrase search" do
        query = Ralph::Query::Builder.new("fts_articles").where_phrase_search("content", "Crystal programming")
        sql = query.build_select
        sql.should contain("phraseto_tsquery")
      end
    end

    describe "#order_by_search_rank" do
      it "adds rank to SELECT and orders by it" do
        query = Ralph::Query::Builder.new("fts_articles")
          .where_search("content", "crystal")
          .order_by_search_rank("content", "crystal")
        sql = query.build_select

        sql.should contain("ts_rank")
        sql.should contain("AS \"search_rank\"")
        sql.should contain("ORDER BY \"search_rank\" DESC")
      end
    end

    describe "#select_search_headline" do
      it "adds headline extraction to SELECT" do
        query = Ralph::Query::Builder.new("fts_articles")
          .where_search("content", "crystal")
          .select_search_headline("content", "crystal")
        sql = query.build_select

        sql.should contain("ts_headline")
        sql.should contain("AS \"headline\"")
      end

      it "supports custom headline options" do
        query = Ralph::Query::Builder.new("fts_articles")
          .select_search_headline("content", "crystal",
            max_words: 50,
            min_words: 20,
            start_tag: "<mark>",
            stop_tag: "</mark>",
            as: "excerpt"
          )
        sql = query.build_select

        sql.should contain("MaxWords=50")
        sql.should contain("MinWords=20")
        sql.should contain("StartSel=<mark>")
        sql.should contain("StopSel=</mark>")
        sql.should contain("AS \"excerpt\"")
      end
    end

    describe "Text Search Configurations" do
      it "lists available configurations" do
        backend = Ralph.database.as(Ralph::Database::PostgresBackend)
        configs = backend.available_text_search_configs

        configs.should be_a(Array(String))
        configs.should contain("english")
        configs.should contain("simple")
      end

      it "checks if configuration exists" do
        backend = Ralph.database.as(Ralph::Database::PostgresBackend)

        backend.text_search_config_exists?("english").should be_true
        backend.text_search_config_exists?("nonexistent_config_xyz").should be_false
      end

      it "creates and drops custom configuration" do
        backend = Ralph.database.as(Ralph::Database::PostgresBackend)

        # Create config
        backend.create_text_search_config("test_ralph_config", copy_from: "english")
        backend.text_search_config_exists?("test_ralph_config").should be_true

        # Drop config
        backend.drop_text_search_config("test_ralph_config")
        backend.text_search_config_exists?("test_ralph_config").should be_false
      end
    end

    describe "Full-Text Search Indexes" do
      it "creates GIN index for full-text search" do
        Ralph.database.execute("DROP INDEX IF EXISTS idx_fts_articles_content")

        index = Ralph::Migrations::Schema::FullTextIndexDefinition.new(
          "fts_articles", "content", "idx_fts_articles_content", "english", true
        )
        Ralph.database.execute(index.to_sql)

        # Check if index exists
        result = Ralph.database.query_all(
          "SELECT indexname FROM pg_indexes WHERE tablename = 'fts_articles' AND indexname = 'idx_fts_articles_content'"
        )

        found = false
        result.each do
          result.read(String)
          found = true
        end
        result.close

        found.should be_true

        # Cleanup
        Ralph.database.execute(index.to_drop_sql)
      end

      it "creates multi-column full-text search index" do
        Ralph.database.execute("DROP INDEX IF EXISTS idx_fts_articles_search")

        index = Ralph::Migrations::Schema::FullTextIndexDefinition.new(
          "fts_articles", ["title", "content"], "idx_fts_articles_search", "english", true
        )
        Ralph.database.execute(index.to_sql)

        # Check SQL contains coalesce
        index.to_sql.should contain("coalesce")

        # Cleanup
        Ralph.database.execute(index.to_drop_sql)
      end
    end
  end
{% end %}

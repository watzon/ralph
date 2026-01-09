require "../../postgres_spec_helper"

{% if flag?(:skip_postgres_tests) %}
  # Skip all postgres tests when flag is set
{% else %}
  describe "PostgreSQL Special Functions", tags: "postgres" do
    before_all do
      Ralph.configure do |config|
        config.database = Ralph::Database::PostgresBackend.new(POSTGRES_URL)
      end

      # Set dialect for schema generation
      Ralph::Migrations::Schema::Dialect.set_from_backend(Ralph.database)

      Ralph.database.execute("DROP TABLE IF EXISTS fn_test_events CASCADE")

      Ralph.database.execute <<-SQL
        CREATE TABLE IF NOT EXISTS fn_test_events (
          id BIGSERIAL PRIMARY KEY,
          name VARCHAR(255),
          description TEXT,
          event_date TIMESTAMP,
          tags VARCHAR(255)[],
          priority INTEGER,
          created_at TIMESTAMP DEFAULT NOW()
        )
      SQL

      # Insert test data (arrays as PostgreSQL array literals since DB::Any doesn't support Array(String))
      Ralph.database.execute("INSERT INTO fn_test_events (name, description, event_date, tags, priority) VALUES ($1, $2, NOW(), '{test,event}', $3)",
        args: ["Test Event", "A test event description", 5] of DB::Any)
      Ralph.database.execute("INSERT INTO fn_test_events (name, description, event_date, tags, priority) VALUES ($1, $2, NOW() - interval '10 days', '{old}', $3)",
        args: ["Old Event", "An old event", 3] of DB::Any)
    end

    after_all do
      Ralph.database.execute("DROP TABLE IF EXISTS fn_test_events CASCADE")
    end

    describe "Date/Time Functions" do
      describe "#where_before_now / #where_after_now" do
        it "generates correct SQL for NOW() comparison" do
          query = Ralph::Query::Builder.new("fn_test_events").where_before_now("event_date")
          sql = query.build_select
          sql.should contain("\"event_date\" < NOW()")
        end

        it "generates correct SQL for after NOW()" do
          query = Ralph::Query::Builder.new("fn_test_events").where_after_now("event_date")
          sql = query.build_select
          sql.should contain("\"event_date\" > NOW()")
        end
      end

      describe "#where_now" do
        it "uses custom operator with NOW()" do
          query = Ralph::Query::Builder.new("fn_test_events").where_now("event_date", ">=")
          sql = query.build_select
          sql.should contain("\"event_date\" >= NOW()")
        end
      end

      describe "#where_current_timestamp" do
        it "generates CURRENT_TIMESTAMP comparison" do
          query = Ralph::Query::Builder.new("fn_test_events").where_current_timestamp("event_date", "<")
          sql = query.build_select
          sql.should contain("\"event_date\" < CURRENT_TIMESTAMP")
        end
      end

      describe "#select_now / #select_current_timestamp" do
        it "adds NOW() to SELECT" do
          query = Ralph::Query::Builder.new("fn_test_events").select_now("server_time")
          sql = query.build_select
          sql.should contain("NOW() AS \"server_time\"")
        end

        it "adds CURRENT_TIMESTAMP to SELECT" do
          query = Ralph::Query::Builder.new("fn_test_events").select_current_timestamp("ts")
          sql = query.build_select
          sql.should contain("CURRENT_TIMESTAMP AS \"ts\"")
        end
      end

      describe "#where_age" do
        it "generates age() function comparison" do
          query = Ralph::Query::Builder.new("fn_test_events").where_age("event_date", ">", "7 days")
          sql = query.build_select
          sql.should contain("age(\"event_date\") > interval '7 days'")
        end

        it "finds old events" do
          query = Ralph::Query::Builder.new("fn_test_events").where_older_than("event_date", "5 days")
          sql = query.build_select
          sql.should contain("age(\"event_date\") > interval '5 days'")
        end
      end

      describe "#where_date_trunc" do
        it "generates date_trunc() comparison" do
          query = Ralph::Query::Builder.new("fn_test_events").where_date_trunc("day", "event_date", "2024-01-15")
          sql = query.build_select
          sql.should contain("date_trunc('day', \"event_date\") = '2024-01-15'")
        end
      end

      describe "#select_date_trunc" do
        it "adds date_trunc() to SELECT" do
          query = Ralph::Query::Builder.new("fn_test_events").select_date_trunc("month", "event_date", "event_month")
          sql = query.build_select
          sql.should contain("date_trunc('month', \"event_date\") AS \"event_month\"")
        end
      end

      describe "#where_extract" do
        it "generates extract() comparison" do
          query = Ralph::Query::Builder.new("fn_test_events").where_extract("year", "event_date", 2024)
          sql = query.build_select
          sql.should contain("EXTRACT(year FROM \"event_date\") = 2024")
        end
      end

      describe "#where_within_last" do
        it "generates interval subtraction from NOW()" do
          query = Ralph::Query::Builder.new("fn_test_events").where_within_last("event_date", "7 days")
          sql = query.build_select
          sql.should contain("\"event_date\" > NOW() - interval '7 days'")
        end
      end
    end

    describe "UUID Functions" do
      describe "#select_random_uuid" do
        it "adds gen_random_uuid() to SELECT" do
          query = Ralph::Query::Builder.new("fn_test_events").select_random_uuid("new_id")
          sql = query.build_select
          sql.should contain("gen_random_uuid() AS \"new_id\"")
        end
      end
    end

    describe "String Functions" do
      describe "#where_concat" do
        it "generates string concatenation" do
          query = Ralph::Query::Builder.new("fn_test_events").where_concat("name", "description", "Test Event A test event description")
          sql = query.build_select
          sql.should contain("\"name\" || ' ' || \"description\" =")
        end
      end

      describe "#where_regex" do
        it "generates case-sensitive regex match" do
          query = Ralph::Query::Builder.new("fn_test_events").where_regex("name", "^Test")
          sql = query.build_select
          sql.should contain("\"name\" ~")
        end
      end

      describe "#where_regex_i" do
        it "generates case-insensitive regex match" do
          query = Ralph::Query::Builder.new("fn_test_events").where_regex_i("name", "test")
          sql = query.build_select
          sql.should contain("\"name\" ~*")
        end
      end

      describe "#where_not_regex / #where_not_regex_i" do
        it "generates regex not-match" do
          query = Ralph::Query::Builder.new("fn_test_events").where_not_regex("name", "^Old")
          sql = query.build_select
          sql.should contain("\"name\" !~")
        end

        it "generates case-insensitive regex not-match" do
          query = Ralph::Query::Builder.new("fn_test_events").where_not_regex_i("name", "old")
          sql = query.build_select
          sql.should contain("\"name\" !~*")
        end
      end

      describe "#where_length" do
        it "generates length() comparison" do
          query = Ralph::Query::Builder.new("fn_test_events").where_length("name", ">", 5)
          sql = query.build_select
          sql.should contain("length(\"name\") > 5")
        end
      end

      describe "#where_lower / #where_upper" do
        it "generates lower() comparison" do
          query = Ralph::Query::Builder.new("fn_test_events").where_lower("name", "test event")
          sql = query.build_select
          sql.should contain("lower(\"name\")")
        end

        it "generates upper() comparison" do
          query = Ralph::Query::Builder.new("fn_test_events").where_upper("name", "TEST EVENT")
          sql = query.build_select
          sql.should contain("upper(\"name\")")
        end
      end

      describe "#where_ilike" do
        it "generates ILIKE comparison" do
          query = Ralph::Query::Builder.new("fn_test_events").where_ilike("name", "%test%")
          sql = query.build_select
          sql.should contain("\"name\" ILIKE")
        end
      end

      describe "#where_starts_with / #where_ends_with" do
        it "generates LIKE with prefix" do
          query = Ralph::Query::Builder.new("fn_test_events").where_starts_with("name", "Test")
          sql = query.build_select
          sql.should contain("\"name\" LIKE")
        end

        it "generates LIKE with suffix" do
          query = Ralph::Query::Builder.new("fn_test_events").where_ends_with("name", "Event")
          sql = query.build_select
          sql.should contain("\"name\" LIKE")
        end
      end
    end

    describe "Array Functions" do
      describe "#where_array_contains_all" do
        it "generates @> operator" do
          query = Ralph::Query::Builder.new("fn_test_events").where_array_contains_all("tags", ["test", "event"])
          sql = query.build_select
          sql.should contain("\"tags\" @> ARRAY['test', 'event']")
        end
      end

      describe "#where_array_is_contained_by" do
        it "generates <@ operator" do
          query = Ralph::Query::Builder.new("fn_test_events").where_array_is_contained_by("tags", ["test", "event", "extra"])
          sql = query.build_select
          sql.should contain("\"tags\" <@ ARRAY['test', 'event', 'extra']")
        end
      end

      describe "#where_cardinality" do
        it "generates cardinality() comparison" do
          query = Ralph::Query::Builder.new("fn_test_events").where_cardinality("tags", ">", 1)
          sql = query.build_select
          sql.should contain("cardinality(\"tags\") > 1")
        end
      end

      describe "#select_unnest" do
        it "generates unnest() in SELECT" do
          query = Ralph::Query::Builder.new("fn_test_events").select_unnest("tags", "tag")
          sql = query.build_select
          sql.should contain("unnest(\"tags\") AS \"tag\"")
        end
      end
    end

    describe "Advanced Aggregations" do
      describe "#select_array_agg" do
        it "generates array_agg()" do
          query = Ralph::Query::Builder.new("fn_test_events").select_array_agg("name", as: "all_names")
          sql = query.build_select
          sql.should contain("array_agg(\"name\") AS \"all_names\"")
        end

        it "supports DISTINCT and ORDER BY" do
          query = Ralph::Query::Builder.new("fn_test_events").select_array_agg("name", distinct: true, order_by: "name", as: "sorted_names")
          sql = query.build_select
          sql.should contain("array_agg(DISTINCT \"name\" ORDER BY \"name\")")
        end
      end

      describe "#select_string_agg" do
        it "generates string_agg()" do
          query = Ralph::Query::Builder.new("fn_test_events").select_string_agg("name", ", ", as: "names")
          sql = query.build_select
          sql.should contain("string_agg(\"name\", ', ')")
        end

        it "supports ORDER BY" do
          query = Ralph::Query::Builder.new("fn_test_events").select_string_agg("name", ", ", order_by: "name", as: "sorted_names")
          sql = query.build_select
          sql.should contain("ORDER BY \"name\"")
        end
      end

      describe "#select_mode" do
        it "generates mode() WITHIN GROUP" do
          query = Ralph::Query::Builder.new("fn_test_events").select_mode("priority", as: "most_common")
          sql = query.build_select
          sql.should contain("mode() WITHIN GROUP (ORDER BY \"priority\") AS \"most_common\"")
        end
      end

      describe "#select_percentile / #select_median" do
        it "generates percentile_cont()" do
          query = Ralph::Query::Builder.new("fn_test_events").select_percentile("priority", 0.95, as: "p95")
          sql = query.build_select
          sql.should contain("percentile_cont(0.95) WITHIN GROUP (ORDER BY \"priority\") AS \"p95\"")
        end

        it "generates median as 50th percentile" do
          query = Ralph::Query::Builder.new("fn_test_events").select_median("priority", as: "median_priority")
          sql = query.build_select
          sql.should contain("percentile_cont(0.5) WITHIN GROUP")
        end
      end

      describe "#select_json_agg / #select_jsonb_agg" do
        it "generates json_agg()" do
          query = Ralph::Query::Builder.new("fn_test_events").select_json_agg("name", as: "names_json")
          sql = query.build_select
          sql.should contain("json_agg(\"name\")")
        end

        it "generates jsonb_agg()" do
          query = Ralph::Query::Builder.new("fn_test_events").select_jsonb_agg("name", as: "names_jsonb")
          sql = query.build_select
          sql.should contain("jsonb_agg(\"name\")")
        end
      end

      describe "#select_json_build_object" do
        it "generates json_build_object()" do
          query = Ralph::Query::Builder.new("fn_test_events").select_json_build_object(
            {"name" => "name", "priority" => "priority"},
            as: "event_info"
          )
          sql = query.build_select
          sql.should contain("json_build_object(")
          sql.should contain("'name'")
          sql.should contain("\"name\"")
        end
      end
    end

    describe "PostgreSQL Version and Extensions" do
      it "returns PostgreSQL version" do
        backend = Ralph.database.as(Ralph::Database::PostgresBackend)
        version = backend.postgres_version

        version.should be_a(String)
        version.should_not eq("unknown")
      end

      it "checks extension availability" do
        backend = Ralph.database.as(Ralph::Database::PostgresBackend)

        # pg_trgm is commonly available
        backend.extension_available?("plpgsql").should be_true
      end
    end
  end
{% end %}

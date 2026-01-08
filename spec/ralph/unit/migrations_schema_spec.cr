require "../../spec_helper"

describe Ralph::Migrations::Schema::TableDefinition do
  it "creates TableDefinition" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("test_table")
    definition.string("name")
    definition.integer("age")
    definition.timestamps

    sql = definition.to_sql
    sql.should contain("CREATE TABLE IF NOT EXISTS")
    sql.should contain("\"test_table\"")
    sql.should contain("\"name\"")
    sql.should contain("\"age\"")
    sql.should contain("\"created_at\"")
    sql.should contain("\"updated_at\"")
  end

  it "creates TableDefinition with primary key" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("posts")
    definition.primary_key
    definition.string("title")

    sql = definition.to_sql
    sql.should contain("CREATE TABLE IF NOT EXISTS")
  end

  it "creates TableDefinition with custom primary key" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("posts")
    definition.primary_key(:post_id)
    definition.string("title")

    sql = definition.to_sql
    sql.should contain("\"posts\"")
  end

  it "creates TableDefinition with all column types" do
    # Test with SQLite dialect explicitly for deterministic output
    sqlite_dialect = Ralph::Migrations::Schema::Dialect::Sqlite.new
    definition = Ralph::Migrations::Schema::TableDefinition.new("items", sqlite_dialect)
    definition.primary_key
    definition.string("name", size: 100)
    definition.text("description")
    definition.integer("quantity")
    definition.bigint("count")
    definition.float("price")
    definition.boolean("active")
    definition.date("published_on")
    definition.timestamp("created_at")

    sql = definition.to_sql
    sql.should contain("VARCHAR(100)")
    sql.should contain("TEXT")
    sql.should contain("INTEGER")
    sql.should contain("BIGINT")
    sql.should contain("REAL")
    sql.should contain("BOOLEAN")
    sql.should contain("DATE")
    sql.should contain("TIMESTAMP")
  end

  it "creates TableDefinition with indexes" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("users")
    definition.primary_key
    definition.string("email")
    definition.index("email", unique: true)

    indexes = definition.indexes
    indexes.size.should eq(1)
    indexes[0].unique.should be_true
  end

  it "TableDefinition includes reference column" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("posts")
    definition.primary_key
    definition.string("title")
    definition.reference("user")

    sql = definition.to_sql
    sql.should contain("user_id")
  end

  it "TableDefinition reference creates index" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("posts")
    definition.primary_key
    definition.reference("user")

    definition.indexes.size.should eq(1)
    definition.indexes[0].column.should eq("user_id")
  end

  it "uses SQLite dialect when explicitly specified" do
    sqlite_dialect = Ralph::Migrations::Schema::Dialect::Sqlite.new
    definition = Ralph::Migrations::Schema::TableDefinition.new("users", sqlite_dialect)
    definition.primary_key

    sql = definition.to_sql
    sql.should contain("INTEGER PRIMARY KEY AUTOINCREMENT")
  end

  it "uses Postgres dialect when specified" do
    postgres_dialect = Ralph::Migrations::Schema::Dialect::Postgres.new
    definition = Ralph::Migrations::Schema::TableDefinition.new("users", postgres_dialect)
    definition.primary_key

    sql = definition.to_sql
    sql.should contain("BIGSERIAL PRIMARY KEY")
  end
end

describe Ralph::Migrations::Schema::ColumnDefinition do
  dialect = Ralph::Migrations::Schema::Dialect::Sqlite.new

  it "creates ColumnDefinition with SQL" do
    opts = {:size => 100} of Symbol => String | Int32 | Int64 | Float64 | Bool | Symbol | Nil
    column = Ralph::Migrations::Schema::ColumnDefinition.new("title", :string, dialect, opts)
    sql = column.to_sql

    sql.should contain("\"title\"")
    sql.should contain("VARCHAR(100)")
  end

  it "creates ColumnDefinition with NOT NULL" do
    opts = {:size => 255, :null => false} of Symbol => String | Int32 | Int64 | Float64 | Bool | Symbol | Nil
    column = Ralph::Migrations::Schema::ColumnDefinition.new("email", :string, dialect, opts)
    sql = column.to_sql

    sql.should contain("NOT NULL")
  end

  it "creates ColumnDefinition with default value" do
    opts = {:size => 50, :default => "pending"} of Symbol => String | Int32 | Int64 | Float64 | Bool | Symbol | Nil
    column = Ralph::Migrations::Schema::ColumnDefinition.new("status", :string, dialect, opts)
    sql = column.to_sql

    sql.should contain("DEFAULT 'pending'")
  end

  it "creates ColumnDefinition with integer default" do
    opts = {:default => 0} of Symbol => String | Int32 | Int64 | Float64 | Bool | Symbol | Nil
    column = Ralph::Migrations::Schema::ColumnDefinition.new("views", :integer, dialect, opts)
    sql = column.to_sql

    sql.should contain("DEFAULT 0")
  end

  it "uses Postgres types when dialect is Postgres" do
    pg_dialect = Ralph::Migrations::Schema::Dialect::Postgres.new
    opts = {} of Symbol => String | Int32 | Int64 | Float64 | Bool | Symbol | Nil

    float_col = Ralph::Migrations::Schema::ColumnDefinition.new("price", :float, pg_dialect, opts)
    float_col.to_sql.should contain("DOUBLE PRECISION")

    uuid_col = Ralph::Migrations::Schema::ColumnDefinition.new("external_id", :uuid, pg_dialect, opts)
    uuid_col.to_sql.should contain("UUID")

    jsonb_col = Ralph::Migrations::Schema::ColumnDefinition.new("data", :jsonb, pg_dialect, opts)
    jsonb_col.to_sql.should contain("JSONB")
  end
end

describe Ralph::Migrations::Schema::IndexDefinition do
  it "creates IndexDefinition" do
    index = Ralph::Migrations::Schema::IndexDefinition.new("users", "email", "index_users_on_email", false)
    sql = index.to_sql

    sql.should eq("CREATE INDEX IF NOT EXISTS \"index_users_on_email\" ON \"users\" (\"email\")")
  end

  it "creates unique IndexDefinition" do
    index = Ralph::Migrations::Schema::IndexDefinition.new("users", "email", "unique_email", true)
    sql = index.to_sql

    sql.should eq("CREATE UNIQUE INDEX IF NOT EXISTS \"unique_email\" ON \"users\" (\"email\")")
  end
end

describe Ralph::Migrations::Schema::Dialect do
  it "returns dialect matching current database backend" do
    # The dialect is set based on the configured database backend
    expected_dialect = Ralph.database.dialect
    Ralph::Migrations::Schema::Dialect.current.identifier.should eq(expected_dialect)
  end

  it "can switch to Postgres dialect" do
    original = Ralph::Migrations::Schema::Dialect.current
    Ralph::Migrations::Schema::Dialect.current = Ralph::Migrations::Schema::Dialect::Postgres.new
    Ralph::Migrations::Schema::Dialect.current.identifier.should eq(:postgres)
    Ralph::Migrations::Schema::Dialect.current = original
  end

  it "can switch to SQLite dialect" do
    original = Ralph::Migrations::Schema::Dialect.current
    Ralph::Migrations::Schema::Dialect.current = Ralph::Migrations::Schema::Dialect::Sqlite.new
    Ralph::Migrations::Schema::Dialect.current.identifier.should eq(:sqlite)
    Ralph::Migrations::Schema::Dialect.current = original
  end
end

describe "Schema DSL null: parameter" do
  dialect = Ralph::Migrations::Schema::Dialect::Sqlite.new

  it "creates NOT NULL column with null: false" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("users", dialect)
    definition.primary_key
    definition.string("name", null: false)

    sql = definition.to_sql
    sql.should contain("\"name\" VARCHAR(255) NOT NULL")
  end

  it "creates nullable column by default (null: true)" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("users", dialect)
    definition.primary_key
    definition.string("name")

    sql = definition.to_sql
    sql.should contain("\"name\" VARCHAR(255)")
    sql.should_not contain("NOT NULL")
  end

  it "supports null: parameter on all column types" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("test", dialect)
    definition.string("s", null: false)
    definition.text("t", null: false)
    definition.integer("i", null: false)
    definition.bigint("b", null: false)
    definition.float("f", null: false)
    definition.boolean("bo", null: false)
    definition.date("d", null: false)
    definition.timestamp("ts", null: false)

    sql = definition.to_sql
    sql.scan(/NOT NULL/).size.should eq(8)
  end

  it "combines null: false with default value" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("users", dialect)
    definition.string("status", null: false, default: "active")

    sql = definition.to_sql
    sql.should contain("NOT NULL")
    sql.should contain("DEFAULT 'active'")
  end
end

describe Ralph::Migrations::Schema::ForeignKeyDefinition do
  it "generates inline foreign key SQL" do
    fk = Ralph::Migrations::Schema::ForeignKeyDefinition.new(
      from_table: "posts",
      from_column: "user_id",
      to_table: "users",
      to_column: "id"
    )

    sql = fk.to_inline_sql
    sql.should contain("CONSTRAINT")
    sql.should contain("FOREIGN KEY (\"user_id\")")
    sql.should contain("REFERENCES \"users\" (\"id\")")
  end

  it "generates ON DELETE CASCADE" do
    fk = Ralph::Migrations::Schema::ForeignKeyDefinition.new(
      from_table: "posts",
      from_column: "user_id",
      to_table: "users",
      to_column: "id",
      on_delete: :cascade
    )

    sql = fk.to_inline_sql
    sql.should contain("ON DELETE CASCADE")
  end

  it "generates ON UPDATE SET NULL" do
    fk = Ralph::Migrations::Schema::ForeignKeyDefinition.new(
      from_table: "posts",
      from_column: "user_id",
      to_table: "users",
      to_column: "id",
      on_update: :nullify
    )

    sql = fk.to_inline_sql
    sql.should contain("ON UPDATE SET NULL")
  end

  it "generates ADD CONSTRAINT SQL" do
    fk = Ralph::Migrations::Schema::ForeignKeyDefinition.new(
      from_table: "posts",
      from_column: "user_id",
      to_table: "users",
      to_column: "id",
      on_delete: :restrict
    )

    sql = fk.to_add_sql
    sql.should contain("ALTER TABLE \"posts\" ADD CONSTRAINT")
    sql.should contain("ON DELETE RESTRICT")
  end

  it "generates DROP CONSTRAINT SQL" do
    fk = Ralph::Migrations::Schema::ForeignKeyDefinition.new(
      from_table: "posts",
      from_column: "user_id",
      to_table: "users",
      to_column: "id"
    )

    sql = fk.to_drop_sql
    sql.should eq("ALTER TABLE \"posts\" DROP CONSTRAINT \"fk_posts_user_id\"")
  end

  it "uses custom constraint name" do
    fk = Ralph::Migrations::Schema::ForeignKeyDefinition.new(
      from_table: "posts",
      from_column: "user_id",
      to_table: "users",
      to_column: "id",
      name: "my_custom_fk"
    )

    fk.constraint_name.should eq("my_custom_fk")
    fk.to_drop_sql.should contain("\"my_custom_fk\"")
  end
end

describe "TableDefinition foreign_key method" do
  dialect = Ralph::Migrations::Schema::Dialect::Sqlite.new

  it "adds foreign key constraint via foreign_key method" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("posts", dialect)
    definition.primary_key
    definition.bigint("user_id", null: false)
    definition.foreign_key("users", on_delete: :cascade)

    sql = definition.to_sql
    sql.should contain("FOREIGN KEY")
    sql.should contain("ON DELETE CASCADE")
  end

  it "adds inline FK via reference with on_delete" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("posts", dialect)
    definition.primary_key
    definition.reference("user", null: false, on_delete: :cascade)

    sql = definition.to_sql
    sql.should contain("\"user_id\"")
    sql.should contain("FOREIGN KEY")
    sql.should contain("ON DELETE CASCADE")
  end
end

describe "timestamps_not_null" do
  dialect = Ralph::Migrations::Schema::Dialect::Sqlite.new

  it "creates NOT NULL timestamp columns" do
    definition = Ralph::Migrations::Schema::TableDefinition.new("posts", dialect)
    definition.primary_key
    definition.timestamps_not_null

    sql = definition.to_sql
    sql.should contain("\"created_at\" TIMESTAMP NOT NULL")
    sql.should contain("\"updated_at\" TIMESTAMP NOT NULL")
  end
end

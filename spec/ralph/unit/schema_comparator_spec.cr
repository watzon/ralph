require "../../spec_helper"

# Test model schemas (simulated)
def create_test_model_schema(
  table_name : String,
  columns : Array(Ralph::Schema::ModelColumn) = [] of Ralph::Schema::ModelColumn,
  foreign_keys : Array(Ralph::Schema::ModelForeignKey) = [] of Ralph::Schema::ModelForeignKey,
) : Ralph::Schema::ModelSchema
  Ralph::Schema::ModelSchema.new(
    table_name: table_name,
    columns: columns,
    foreign_keys: foreign_keys
  )
end

def create_test_db_table(
  name : String,
  columns : Array(Ralph::Schema::DatabaseColumn) = [] of Ralph::Schema::DatabaseColumn,
  foreign_keys : Array(Ralph::Schema::DatabaseForeignKey) = [] of Ralph::Schema::DatabaseForeignKey,
) : Ralph::Schema::DatabaseTable
  Ralph::Schema::DatabaseTable.new(
    name: name,
    columns: columns,
    foreign_keys: foreign_keys
  )
end

describe Ralph::Schema::SchemaComparator do
  describe "#compare" do
    it "detects new tables to create" do
      model_schemas = {
        "users" => create_test_model_schema("users", [
          Ralph::Schema::ModelColumn.new("id", "Int64", :bigint, false, true, nil),
          Ralph::Schema::ModelColumn.new("name", "String", :string, false, false, nil),
        ]),
      }
      db_schema = Ralph::Schema::DatabaseSchema.new

      comparator = Ralph::Schema::SchemaComparator.new(model_schemas, db_schema, :postgres)
      diff = comparator.compare

      diff.changes.size.should eq(1)
      diff.changes[0].type.should eq(Ralph::Schema::ChangeType::CreateTable)
      diff.changes[0].table.should eq("users")
    end

    it "detects tables to drop" do
      model_schemas = {} of String => Ralph::Schema::ModelSchema
      db_schema = Ralph::Schema::DatabaseSchema.new({
        "old_table" => create_test_db_table("old_table", [
          Ralph::Schema::DatabaseColumn.new("id", "bigint", false, nil, true, true),
        ]),
      })

      comparator = Ralph::Schema::SchemaComparator.new(model_schemas, db_schema, :postgres)
      diff = comparator.compare

      diff.changes.size.should eq(1)
      diff.changes[0].type.should eq(Ralph::Schema::ChangeType::DropTable)
      diff.changes[0].table.should eq("old_table")
    end

    it "detects new columns to add" do
      model_schemas = {
        "users" => create_test_model_schema("users", [
          Ralph::Schema::ModelColumn.new("id", "Int64", :bigint, false, true, nil),
          Ralph::Schema::ModelColumn.new("name", "String", :string, false, false, nil),
          Ralph::Schema::ModelColumn.new("nickname", "String?", :string, true, false, nil),
        ]),
      }
      db_schema = Ralph::Schema::DatabaseSchema.new({
        "users" => create_test_db_table("users", [
          Ralph::Schema::DatabaseColumn.new("id", "bigint", false, nil, true, true),
          Ralph::Schema::DatabaseColumn.new("name", "varchar(255)", false, nil, false, false),
        ]),
      })

      comparator = Ralph::Schema::SchemaComparator.new(model_schemas, db_schema, :postgres)
      diff = comparator.compare

      add_column_changes = diff.changes.select { |c| c.type.add_column? }
      add_column_changes.size.should eq(1)
      add_column_changes[0].table.should eq("users")
      add_column_changes[0].column.should eq("nickname")
    end

    it "detects columns to remove" do
      model_schemas = {
        "users" => create_test_model_schema("users", [
          Ralph::Schema::ModelColumn.new("id", "Int64", :bigint, false, true, nil),
        ]),
      }
      db_schema = Ralph::Schema::DatabaseSchema.new({
        "users" => create_test_db_table("users", [
          Ralph::Schema::DatabaseColumn.new("id", "bigint", false, nil, true, true),
          Ralph::Schema::DatabaseColumn.new("old_column", "varchar(255)", true, nil, false, false),
        ]),
      })

      comparator = Ralph::Schema::SchemaComparator.new(model_schemas, db_schema, :postgres)
      diff = comparator.compare

      remove_column_changes = diff.changes.select { |c| c.type.remove_column? }
      remove_column_changes.size.should eq(1)
      remove_column_changes[0].column.should eq("old_column")
    end

    it "detects missing foreign keys on existing tables" do
      model_schemas = {
        "posts" => create_test_model_schema("posts",
          [
            Ralph::Schema::ModelColumn.new("id", "Int64", :bigint, false, true, nil),
            Ralph::Schema::ModelColumn.new("user_id", "Int64", :bigint, false, false, nil),
          ],
          [
            Ralph::Schema::ModelForeignKey.new("user_id", "users", "id"),
          ]
        ),
      }
      db_schema = Ralph::Schema::DatabaseSchema.new({
        "posts" => create_test_db_table("posts", [
          Ralph::Schema::DatabaseColumn.new("id", "bigint", false, nil, true, true),
          Ralph::Schema::DatabaseColumn.new("user_id", "bigint", false, nil, false, false),
        ]),
      })

      comparator = Ralph::Schema::SchemaComparator.new(model_schemas, db_schema, :postgres)
      diff = comparator.compare

      add_fk_changes = diff.changes.select { |c| c.type.add_foreign_key? }
      add_fk_changes.size.should eq(1)
      add_fk_changes[0].table.should eq("posts")
      add_fk_changes[0].column.should eq("user_id")
      add_fk_changes[0].details["to_table"].should eq("users")
    end

    it "does NOT emit AddForeignKey for tables being created" do
      # This is the key bug fix - when a table is being created,
      # the FKs should be included in the CREATE TABLE, not as separate
      # AddForeignKey changes
      model_schemas = {
        "posts" => create_test_model_schema("posts",
          [
            Ralph::Schema::ModelColumn.new("id", "Int64", :bigint, false, true, nil),
            Ralph::Schema::ModelColumn.new("user_id", "Int64", :bigint, false, false, nil),
          ],
          [
            Ralph::Schema::ModelForeignKey.new("user_id", "users", "id"),
          ]
        ),
      }
      # Empty DB schema = table doesn't exist yet
      db_schema = Ralph::Schema::DatabaseSchema.new

      comparator = Ralph::Schema::SchemaComparator.new(model_schemas, db_schema, :postgres)
      diff = comparator.compare

      # Should have CreateTable but NOT AddForeignKey
      create_table_changes = diff.changes.select { |c| c.type.create_table? }
      add_fk_changes = diff.changes.select { |c| c.type.add_foreign_key? }

      create_table_changes.size.should eq(1)
      create_table_changes[0].table.should eq("posts")

      # No AddForeignKey because FKs are included in CREATE TABLE
      add_fk_changes.size.should eq(0)
    end

    it "skips migration tracking tables by default" do
      model_schemas = {} of String => Ralph::Schema::ModelSchema
      db_schema = Ralph::Schema::DatabaseSchema.new({
        "schema_migrations" => create_test_db_table("schema_migrations"),
        "adonis_schema"     => create_test_db_table("adonis_schema"),
        "users"             => create_test_db_table("users"),
      })

      comparator = Ralph::Schema::SchemaComparator.new(model_schemas, db_schema, :postgres)
      diff = comparator.compare

      # Only "users" should be flagged for drop, not the migration tables
      drop_changes = diff.changes.select { |c| c.type.drop_table? }
      drop_changes.size.should eq(1)
      drop_changes[0].table.should eq("users")
    end

    it "skips user-specified tables" do
      model_schemas = {} of String => Ralph::Schema::ModelSchema
      db_schema = Ralph::Schema::DatabaseSchema.new({
        "internal_cache" => create_test_db_table("internal_cache"),
        "users"          => create_test_db_table("users"),
      })

      comparator = Ralph::Schema::SchemaComparator.new(model_schemas, db_schema, :postgres, ["internal_cache"])
      diff = comparator.compare

      drop_changes = diff.changes.select { |c| c.type.drop_table? }
      drop_changes.size.should eq(1)
      drop_changes[0].table.should eq("users")
    end
  end
end

describe Ralph::Schema::SqlMigrationGenerator do
  describe "#generate" do
    it "generates CREATE TABLE with columns" do
      model_schemas = {
        "users" => create_test_model_schema("users", [
          Ralph::Schema::ModelColumn.new("id", "Int64", :bigint, false, true, nil),
          Ralph::Schema::ModelColumn.new("name", "String", :string, false, false, nil),
          Ralph::Schema::ModelColumn.new("email", "String?", :string, true, false, nil),
        ]),
      }

      diff = Ralph::Schema::SchemaDiff.new([
        Ralph::Schema::SchemaChange.new(
          type: Ralph::Schema::ChangeType::CreateTable,
          table: "users",
          details: {"columns" => "id, name, email"}
        ),
      ])

      generator = Ralph::Schema::SqlMigrationGenerator.new(
        diff: diff,
        name: "test",
        output_dir: "/tmp",
        dialect: :postgres,
        model_schemas: model_schemas
      )

      result = generator.generate
      content = result[:content]

      content.should contain("CREATE TABLE \"users\"")
      content.should contain("\"id\" BIGINT PRIMARY KEY NOT NULL")
      content.should contain("\"name\" TEXT NOT NULL")
      content.should contain("\"email\" TEXT")
      # Down migration
      content.should contain("DROP TABLE IF EXISTS \"users\"")
    end

    it "includes foreign keys in CREATE TABLE" do
      model_schemas = {
        "posts" => create_test_model_schema("posts",
          [
            Ralph::Schema::ModelColumn.new("id", "Int64", :bigint, false, true, nil),
            Ralph::Schema::ModelColumn.new("user_id", "Int64", :bigint, false, false, nil),
          ],
          [
            Ralph::Schema::ModelForeignKey.new("user_id", "users", "id"),
          ]
        ),
      }

      diff = Ralph::Schema::SchemaDiff.new([
        Ralph::Schema::SchemaChange.new(
          type: Ralph::Schema::ChangeType::CreateTable,
          table: "posts",
          details: {"columns" => "id, user_id"}
        ),
      ])

      generator = Ralph::Schema::SqlMigrationGenerator.new(
        diff: diff,
        name: "test",
        output_dir: "/tmp",
        dialect: :postgres,
        model_schemas: model_schemas
      )

      result = generator.generate
      content = result[:content]

      content.should contain("CREATE TABLE \"posts\"")
      content.should contain("\"user_id\" BIGINT NOT NULL")
      content.should contain("CONSTRAINT \"fk_posts_user_id\" FOREIGN KEY (\"user_id\") REFERENCES \"users\" (\"id\")")
    end

    it "generates ADD COLUMN statement" do
      diff = Ralph::Schema::SchemaDiff.new([
        Ralph::Schema::SchemaChange.new(
          type: Ralph::Schema::ChangeType::AddColumn,
          table: "users",
          column: "nickname",
          details: {"type" => "string", "nullable" => "true"}
        ),
      ])

      generator = Ralph::Schema::SqlMigrationGenerator.new(
        diff: diff,
        name: "test",
        output_dir: "/tmp",
        dialect: :postgres
      )

      result = generator.generate
      content = result[:content]

      content.should contain("ALTER TABLE \"users\" ADD COLUMN \"nickname\" TEXT")
      content.should_not contain("NOT NULL")
      # Down migration
      content.should contain("ALTER TABLE \"users\" DROP COLUMN \"nickname\"")
    end

    it "generates ADD COLUMN with NOT NULL for non-nullable columns" do
      diff = Ralph::Schema::SchemaDiff.new([
        Ralph::Schema::SchemaChange.new(
          type: Ralph::Schema::ChangeType::AddColumn,
          table: "users",
          column: "status",
          details: {"type" => "string", "nullable" => "false"}
        ),
      ])

      generator = Ralph::Schema::SqlMigrationGenerator.new(
        diff: diff,
        name: "test",
        output_dir: "/tmp",
        dialect: :postgres
      )

      result = generator.generate
      content = result[:content]

      content.should contain("ALTER TABLE \"users\" ADD COLUMN \"status\" TEXT NOT NULL")
    end

    it "generates ADD FOREIGN KEY statement" do
      diff = Ralph::Schema::SchemaDiff.new([
        Ralph::Schema::SchemaChange.new(
          type: Ralph::Schema::ChangeType::AddForeignKey,
          table: "posts",
          column: "user_id",
          details: {"to_table" => "users", "to_column" => "id"}
        ),
      ])

      generator = Ralph::Schema::SqlMigrationGenerator.new(
        diff: diff,
        name: "test",
        output_dir: "/tmp",
        dialect: :postgres
      )

      result = generator.generate
      content = result[:content]

      content.should contain("ALTER TABLE \"posts\" ADD CONSTRAINT \"fk_posts_user_id\"")
      content.should contain("FOREIGN KEY (\"user_id\") REFERENCES \"users\" (\"id\")")
      # Down migration
      content.should contain("ALTER TABLE \"posts\" DROP CONSTRAINT \"fk_posts_user_id\"")
    end

    it "generates DROP TABLE statement" do
      diff = Ralph::Schema::SchemaDiff.new([
        Ralph::Schema::SchemaChange.new(
          type: Ralph::Schema::ChangeType::DropTable,
          table: "old_table"
        ),
      ])

      generator = Ralph::Schema::SqlMigrationGenerator.new(
        diff: diff,
        name: "test",
        output_dir: "/tmp",
        dialect: :postgres
      )

      result = generator.generate
      content = result[:content]

      content.should contain("DROP TABLE IF EXISTS \"old_table\"")
      # Down migration can't auto-reverse DROP TABLE
      content.should contain("Cannot automatically reverse DROP TABLE")
    end

    it "handles column defaults" do
      model_schemas = {
        "settings" => create_test_model_schema("settings", [
          Ralph::Schema::ModelColumn.new("id", "Int64", :bigint, false, true, nil),
          Ralph::Schema::ModelColumn.new("is_active", "Bool", :boolean, false, false, true),
        ]),
      }

      diff = Ralph::Schema::SchemaDiff.new([
        Ralph::Schema::SchemaChange.new(
          type: Ralph::Schema::ChangeType::CreateTable,
          table: "settings",
          details: {"columns" => "id, is_active"}
        ),
      ])

      generator = Ralph::Schema::SqlMigrationGenerator.new(
        diff: diff,
        name: "test",
        output_dir: "/tmp",
        dialect: :postgres,
        model_schemas: model_schemas
      )

      result = generator.generate
      content = result[:content]

      # PostgreSQL outputs TRUE/FALSE in uppercase
      content.should contain("\"is_active\" BOOLEAN NOT NULL DEFAULT TRUE")
    end

    it "orders CREATE TABLE by foreign key dependencies" do
      # posts depends on users, comments depends on posts
      # Order should be: users, posts, comments
      model_schemas = {
        "comments" => create_test_model_schema("comments",
          [
            Ralph::Schema::ModelColumn.new("id", "Int64", :bigint, false, true, nil),
            Ralph::Schema::ModelColumn.new("post_id", "Int64", :bigint, false, false, nil),
          ],
          [
            Ralph::Schema::ModelForeignKey.new("post_id", "posts", "id"),
          ]
        ),
        "posts" => create_test_model_schema("posts",
          [
            Ralph::Schema::ModelColumn.new("id", "Int64", :bigint, false, true, nil),
            Ralph::Schema::ModelColumn.new("user_id", "Int64", :bigint, false, false, nil),
          ],
          [
            Ralph::Schema::ModelForeignKey.new("user_id", "users", "id"),
          ]
        ),
        "users" => create_test_model_schema("users", [
          Ralph::Schema::ModelColumn.new("id", "Int64", :bigint, false, true, nil),
          Ralph::Schema::ModelColumn.new("name", "String", :string, false, false, nil),
        ]),
      }

      diff = Ralph::Schema::SchemaDiff.new([
        Ralph::Schema::SchemaChange.new(type: Ralph::Schema::ChangeType::CreateTable, table: "comments"),
        Ralph::Schema::SchemaChange.new(type: Ralph::Schema::ChangeType::CreateTable, table: "posts"),
        Ralph::Schema::SchemaChange.new(type: Ralph::Schema::ChangeType::CreateTable, table: "users"),
      ])

      generator = Ralph::Schema::SqlMigrationGenerator.new(
        diff: diff,
        name: "test",
        output_dir: "/tmp",
        dialect: :postgres,
        model_schemas: model_schemas
      )

      result = generator.generate
      content = result[:content]

      # Find positions of each CREATE TABLE
      users_pos = content.index("CREATE TABLE \"users\"").not_nil!
      posts_pos = content.index("CREATE TABLE \"posts\"").not_nil!
      comments_pos = content.index("CREATE TABLE \"comments\"").not_nil!

      # users should come before posts
      users_pos.should be < posts_pos
      # posts should come before comments
      posts_pos.should be < comments_pos
    end

    it "handles circular dependencies by deferring foreign keys" do
      # Circular: tenants -> users (via deleted_by_user_id) AND users -> tenants (via tenant_id)
      model_schemas = {
        "tenants" => create_test_model_schema("tenants",
          [
            Ralph::Schema::ModelColumn.new("id", "Int64", :bigint, false, true, nil),
            Ralph::Schema::ModelColumn.new("name", "String", :string, false, false, nil),
            Ralph::Schema::ModelColumn.new("deleted_by_user_id", "Int64?", :bigint, true, false, nil),
          ],
          [
            Ralph::Schema::ModelForeignKey.new("deleted_by_user_id", "users", "id"),
          ]
        ),
        "users" => create_test_model_schema("users",
          [
            Ralph::Schema::ModelColumn.new("id", "Int64", :bigint, false, true, nil),
            Ralph::Schema::ModelColumn.new("name", "String", :string, false, false, nil),
            Ralph::Schema::ModelColumn.new("tenant_id", "Int64", :bigint, false, false, nil),
          ],
          [
            Ralph::Schema::ModelForeignKey.new("tenant_id", "tenants", "id"),
          ]
        ),
      }

      diff = Ralph::Schema::SchemaDiff.new([
        Ralph::Schema::SchemaChange.new(type: Ralph::Schema::ChangeType::CreateTable, table: "tenants"),
        Ralph::Schema::SchemaChange.new(type: Ralph::Schema::ChangeType::CreateTable, table: "users"),
      ])

      generator = Ralph::Schema::SqlMigrationGenerator.new(
        diff: diff,
        name: "test",
        output_dir: "/tmp",
        dialect: :postgres,
        model_schemas: model_schemas
      )

      result = generator.generate
      content = result[:content]

      # Both tables should be created
      content.should contain("CREATE TABLE \"users\"")
      content.should contain("CREATE TABLE \"tenants\"")

      # One FK should be deferred (added via ALTER TABLE after all CREATE TABLEs)
      content.should contain("Deferred foreign keys")
      content.should contain("ALTER TABLE")
      content.should contain("ADD CONSTRAINT")
    end

    it "handles complex dependency chains" do
      # A depends on B, B depends on C, C depends on nothing
      # Order should be: C, B, A
      model_schemas = {
        "table_a" => create_test_model_schema("table_a",
          [
            Ralph::Schema::ModelColumn.new("id", "Int64", :bigint, false, true, nil),
            Ralph::Schema::ModelColumn.new("b_id", "Int64", :bigint, false, false, nil),
          ],
          [Ralph::Schema::ModelForeignKey.new("b_id", "table_b", "id")]
        ),
        "table_b" => create_test_model_schema("table_b",
          [
            Ralph::Schema::ModelColumn.new("id", "Int64", :bigint, false, true, nil),
            Ralph::Schema::ModelColumn.new("c_id", "Int64", :bigint, false, false, nil),
          ],
          [Ralph::Schema::ModelForeignKey.new("c_id", "table_c", "id")]
        ),
        "table_c" => create_test_model_schema("table_c", [
          Ralph::Schema::ModelColumn.new("id", "Int64", :bigint, false, true, nil),
        ]),
      }

      diff = Ralph::Schema::SchemaDiff.new([
        Ralph::Schema::SchemaChange.new(type: Ralph::Schema::ChangeType::CreateTable, table: "table_a"),
        Ralph::Schema::SchemaChange.new(type: Ralph::Schema::ChangeType::CreateTable, table: "table_b"),
        Ralph::Schema::SchemaChange.new(type: Ralph::Schema::ChangeType::CreateTable, table: "table_c"),
      ])

      generator = Ralph::Schema::SqlMigrationGenerator.new(
        diff: diff,
        name: "test",
        output_dir: "/tmp",
        dialect: :postgres,
        model_schemas: model_schemas
      )

      result = generator.generate
      content = result[:content]

      c_pos = content.index("CREATE TABLE \"table_c\"").not_nil!
      b_pos = content.index("CREATE TABLE \"table_b\"").not_nil!
      a_pos = content.index("CREATE TABLE \"table_a\"").not_nil!

      c_pos.should be < b_pos
      b_pos.should be < a_pos
    end

    it "handles FKs to tables not being created (pre-existing)" do
      # posts references users, but users already exists (not in create list)
      model_schemas = {
        "posts" => create_test_model_schema("posts",
          [
            Ralph::Schema::ModelColumn.new("id", "Int64", :bigint, false, true, nil),
            Ralph::Schema::ModelColumn.new("user_id", "Int64", :bigint, false, false, nil),
          ],
          [Ralph::Schema::ModelForeignKey.new("user_id", "users", "id")]
        ),
      }

      diff = Ralph::Schema::SchemaDiff.new([
        Ralph::Schema::SchemaChange.new(type: Ralph::Schema::ChangeType::CreateTable, table: "posts"),
      ])

      generator = Ralph::Schema::SqlMigrationGenerator.new(
        diff: diff,
        name: "test",
        output_dir: "/tmp",
        dialect: :postgres,
        model_schemas: model_schemas
      )

      result = generator.generate
      content = result[:content]

      # Should create posts with the FK inline (users already exists)
      content.should contain("CREATE TABLE \"posts\"")
      content.should contain("CONSTRAINT \"fk_posts_user_id\" FOREIGN KEY (\"user_id\") REFERENCES \"users\" (\"id\")")
      # No deferred FKs needed
      content.should_not contain("Deferred foreign keys")
    end
  end
end

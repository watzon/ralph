require "../spec_helper"
require "file_utils"
require "db"

module TestSchema
  def self.create_table(name : String, &block : Ralph::Migrations::Schema::TableDefinition ->)
    drop_table(name)
    dialect = Ralph::Migrations::Schema::Dialect.current
    definition = Ralph::Migrations::Schema::TableDefinition.new(name, dialect)
    block.call(definition)
    Ralph.database.execute(definition.to_sql)
    definition.indexes.each { |idx| Ralph.database.execute(idx.to_sql) }
  end

  def self.drop_table(name : String)
    if RalphTestHelper.postgres?
      Ralph.database.execute("DROP TABLE IF EXISTS \"#{name}\" CASCADE")
    else
      Ralph.database.execute("DROP TABLE IF EXISTS \"#{name}\"")
    end
  end

  def self.truncate_table(name : String)
    if RalphTestHelper.postgres?
      Ralph.database.execute("TRUNCATE TABLE \"#{name}\" RESTART IDENTITY CASCADE")
    else
      Ralph.database.execute("DELETE FROM \"#{name}\"")
    end
  end
end

module RalphTestHelper
  @@db_path : String? = nil
  @@adapter : String = "sqlite"

  def self.adapter : String
    @@adapter
  end

  def self.postgres? : Bool
    @@adapter == "postgres"
  end

  def self.sqlite? : Bool
    @@adapter == "sqlite"
  end

  def self.setup_test_database
    @@adapter = ENV.fetch("DB_ADAPTER", "sqlite")

    case @@adapter
    when "postgres"
      setup_postgres_database
    when "sqlite"
      setup_sqlite_database
    else
      raise "Unknown DB_ADAPTER: #{@@adapter}. Use 'sqlite' or 'postgres'."
    end
  end

  def self.setup_sqlite_database
    @@db_path = "/tmp/ralph_test_#{Process.pid}.sqlite3"

    Ralph.configure do |config|
      config.database = Ralph::Database::SqliteBackend.new("sqlite3://#{@@db_path}")
    end

    Ralph::Migrations::Schema::Dialect.current = Ralph::Migrations::Schema::Dialect::Sqlite.new

    create_base_schema
  end

  def self.setup_postgres_database
    postgres_url = ENV["POSTGRES_URL"]?
    unless postgres_url
      raise "POSTGRES_URL environment variable not set. Required when DB_ADAPTER=postgres"
    end

    Ralph.configure do |config|
      config.database = Ralph::Database::PostgresBackend.new(postgres_url)
    end

    Ralph::Migrations::Schema::Dialect.current = Ralph::Migrations::Schema::Dialect::Postgres.new

    create_base_schema
  end

  def self.create_base_schema
    TestSchema.create_table("users") do |t|
      t.primary_key
      t.string("name")
      t.string("email")
      t.integer("age")
      t.boolean("active")
      t.boolean("skip_callback")
      t.timestamp("created_at")
      t.index("email", unique: true) # Unique index for upsert tests
    end

    TestSchema.create_table("posts") do |t|
      t.primary_key
      t.string("title")
      t.bigint("user_id")
      t.integer("views", default: 0)
      t.boolean("published", default: false)
    end

    # UUID primary key table for bulk operations testing
    TestSchema.create_table("uuid_items") do |t|
      t.uuid_primary_key("id")
      t.string("name")
      t.string("code")
      t.index("code", unique: true)
    end
  end

  def self.cleanup_test_database
    case @@adapter
    when "postgres"
      TestSchema.drop_table("uuid_items")
      TestSchema.drop_table("posts")
      TestSchema.drop_table("users")
    when "sqlite"
      if path = @@db_path
        File.delete(path) if File.exists?(path)
      end
    end
  end

  def self.clear_tables
    TestSchema.truncate_table("uuid_items")
    TestSchema.truncate_table("posts")
    TestSchema.truncate_table("users")
  end
end

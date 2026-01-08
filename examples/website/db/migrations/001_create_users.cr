require "ralph"

class CreateUsers_20260107000001 < Ralph::Migrations::Migration
  migration_version 20260107000001

  def up
    # Use raw SQL for SQLite to create a table with UUID primary key
    # SQLite stores UUIDs as TEXT
    execute <<-SQL
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY NOT NULL,
        username TEXT NOT NULL,
        email TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    SQL

    add_index "users", "username", unique: true
    add_index "users", "email", unique: true
  end

  def down
    drop_table "users"
  end
end

Ralph::Migrations::Migrator.register(CreateUsers_20260107000001)

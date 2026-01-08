require "ralph"

class CreatePosts_20260107000002 < Ralph::Migrations::Migration
  migration_version 20260107000002

  def up : Nil
    # Use raw SQL for SQLite to create a table with UUID primary key
    # and UUID foreign key to users
    execute <<-SQL
      CREATE TABLE IF NOT EXISTS posts (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        published INTEGER DEFAULT 0,
        user_id TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    SQL

    add_index "posts", "user_id"
  end

  def down : Nil
    drop_table "posts"
  end
end

Ralph::Migrations::Migrator.register(CreatePosts_20260107000002)

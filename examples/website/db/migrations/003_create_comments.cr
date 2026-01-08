require "ralph"

class CreateComments_20260107000003 < Ralph::Migrations::Migration
  migration_version 20260107000003

  def up : Nil
    # Use raw SQL for SQLite to create a table with UUID primary key
    # and UUID foreign keys to users and posts
    execute <<-SQL
      CREATE TABLE IF NOT EXISTS comments (
        id TEXT PRIMARY KEY NOT NULL,
        body TEXT NOT NULL,
        user_id TEXT,
        post_id TEXT,
        created_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (post_id) REFERENCES posts(id)
      )
    SQL

    add_index "comments", "user_id"
    add_index "comments", "post_id"
  end

  def down : Nil
    drop_table "comments"
  end
end

Ralph::Migrations::Migrator.register(CreateComments_20260107000003)

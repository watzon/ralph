require "ralph"

class CreatePosts_20260107000002 < Ralph::Migrations::Migration
  migration_version 20260107000002

  def up : Nil
    create_table "posts" do |t|
      t.uuid_primary_key
      t.string "title", null: false
      t.text "body", null: false
      t.boolean "published", default: false
      t.string "user_id"
      t.timestamps
      t.foreign_key "users", column: "user_id", on_delete: :cascade
    end

    add_index "posts", "user_id"
  end

  def down : Nil
    drop_table "posts"
  end
end

Ralph::Migrations::Migrator.register(CreatePosts_20260107000002)

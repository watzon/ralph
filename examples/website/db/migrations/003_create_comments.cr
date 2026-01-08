require "ralph"

class CreateComments_20260107000003 < Ralph::Migrations::Migration
  migration_version 20260107000003

  def up : Nil
    create_table "comments" do |t|
      t.uuid_primary_key
      t.text "body", null: false
      t.string "user_id"
      t.string "post_id"
      t.timestamps
      t.foreign_key "users", column: "user_id", on_delete: :cascade
      t.foreign_key "posts", column: "post_id", on_delete: :cascade
    end

    add_index "comments", "user_id"
    add_index "comments", "post_id"
  end

  def down : Nil
    drop_table "comments"
  end
end

Ralph::Migrations::Migrator.register(CreateComments_20260107000003)

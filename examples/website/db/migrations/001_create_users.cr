require "ralph"

class CreateUsers_20260107000001 < Ralph::Migrations::Migration
  migration_version 20260107000001

  def up
    create_table "users" do |t|
      t.uuid_primary_key
      t.string "username", null: false
      t.string "email", null: false
      t.string "password_hash", null: false
      t.timestamps
    end

    add_index "users", "username", unique: true
    add_index "users", "email", unique: true
  end

  def down
    drop_table "users"
  end
end

Ralph::Migrations::Migrator.register(CreateUsers_20260107000001)

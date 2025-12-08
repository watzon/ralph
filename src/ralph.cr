# Ralph - An ORM for Crystal
#
# Ralph is an Active Record-style ORM for Crystal with a focus on:
# - Developer experience
# - Type safety
# - Explicit over implicit behavior
# - Pluggable database backends
#
# Basic usage:
#
# ```
# Ralph.configure do |config|
#   config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
# end
#
# class User < Ralph::Model
#   table :users
#
#   column id : Int64, primary: true
#   column name : String
#   column email : String
#   column created_at : Time?
# end
#
# # Create
# user = User.new(name: "Alice", email: "alice@example.com")
# user.save
#
# # Read
# user = User.find(1)
# users = User.query { |q| q.where("name = ?", "Alice") }.to_a
#
# # Update
# user.name = "Bob"
# user.save
#
# # Delete
# user.destroy
# ```
module Ralph
  VERSION = "0.1.0"

  # Configure the ORM with a block
  def self.configure
    yield settings
  end

  # Get the current database connection
  def self.database
    settings.database || raise "Database not configured. Call Ralph.configure first."
  end
end

# Core library requires
require "./ralph/settings"
require "./ralph/database"
require "./ralph/validations"
require "./ralph/callbacks"
require "./ralph/associations"
require "./ralph/transactions"
require "./ralph/model"
require "./ralph/query/*"
require "./ralph/migrations/*"
require "./ralph/cli/*"
require "./ralph/cli/generators"

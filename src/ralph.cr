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
  VERSION = "1.0.0-beta.1"

  # Exception raised when attempting to use backend-specific features on an unsupported backend
  #
  # This is raised when PostgreSQL-specific features (like full-text search, regex operators,
  # or special functions) are used on a non-PostgreSQL backend.
  #
  # ## Example
  #
  # ```
  # # Using SQLite backend
  # Ralph.configure do |config|
  #   config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
  # end
  #
  # # This will raise BackendError
  # User.query { |q| q.where_search("name", "john") }
  # # => Ralph::BackendError: Full-text search is only available on PostgreSQL backend
  # ```
  class BackendError < Exception
  end

  # Configure the ORM with a block
  def self.configure(&)
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
require "./ralph/types/types"
require "./ralph/validations"
require "./ralph/callbacks"
require "./ralph/associations"
require "./ralph/transactions"
require "./ralph/eager_loading"
require "./ralph/model"
require "./ralph/query/*"
require "./ralph/migrations/*"
require "./ralph/cli/*"
require "./ralph/cli/generators"

require "spec"
require "../src/ralph"
require "../src/ralph/backends/postgres"

# Default PostgreSQL connection URL
POSTGRES_URL = ENV["POSTGRES_URL"]? || "postgres://postgres@localhost:5432/ralph_test"

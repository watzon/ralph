# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ralph is an Active Record-style ORM for Crystal with a focus on developer experience, type safety, and explicit behavior. It uses a pluggable database backend architecture (currently SQLite only).

## Build & Development Commands

```bash
# Install dependencies (for library development/testing)
shards install

# Run tests
crystal spec

# Run a single test file
crystal spec spec/path/to/file_spec.cr

# Type check without running
crystal build --no-codegen src/ralph.cr

# Build the CLI binary (uses separate shard file with adapter deps)
shards install --shard-file=shard.cli.yml
crystal build src/bin/ralph.cr -o bin/ralph

# Run the CLI
./bin/ralph
```

## CLI Commands

```bash
# Database commands
ralph db:create          # Create the database
ralph db:migrate         # Run pending migrations
ralph db:rollback        # Roll back the last migration
ralph db:status          # Show migration status
ralph db:reset           # Drop, create, migrate, and seed
ralph db:setup           # Create database and run migrations

# Generators
ralph g:migration NAME              # Create a new migration
ralph g:model NAME field:type ...   # Generate model with migration
```

## Architecture

### Core Components

- **`Ralph::Model`** (`src/ralph/model.cr`) — Abstract base class for all models. Uses macros for column definitions, provides CRUD operations, dirty tracking, and dynamic attribute access via `__get_by_key_name`/`__set_by_key_name` macros.

- **`Ralph::Query::Builder`** (`src/ralph/query/builder.cr`) — Fluent SQL query builder. Generates parameterized queries ($1, $2, etc.) and supports WHERE, JOIN, GROUP BY, HAVING, ORDER BY, LIMIT/OFFSET, and aggregates.

- **`Ralph::Database::Backend`** (`src/ralph/database.cr`) — Abstract database interface. All backends implement `execute`, `insert`, `query_one`, `query_all`, `scalar`, and `transaction`.

- **`Ralph::Database::SqliteBackend`** (`src/ralph/backends/sqlite.cr`) — SQLite implementation wrapping `crystal-db`.

### Model Features (Modules included by Model)

- **Validations** (`src/ralph/validations.cr`) — Macros like `validates_presence_of`, `validates_length_of`, `validates_format_of`, `validates_uniqueness_of`. Call `setup_validations` at end of class.

- **Callbacks** (`src/ralph/callbacks.cr`) — Annotations for lifecycle hooks: `@[BeforeSave]`, `@[AfterSave]`, `@[BeforeCreate]`, etc. Call `setup_callbacks` at end of class.

- **Associations** (`src/ralph/associations.cr`) — Macros `belongs_to`, `has_one`, `has_many`. Automatically defines foreign key columns and accessor methods.

### Migrations

- **`Ralph::Migrations::Migrator`** (`src/ralph/migrations/migrator.cr`) — Tracks applied migrations in `schema_migrations` table. Register migrations with `Ralph::Migrations::Migrator.register(ClassName)`.

- **`Ralph::Migrations::Migration`** (`src/ralph/migrations/migration.cr`) — Base class with schema DSL: `create_table`, `drop_table`, `add_column`, `remove_column`.

### CLI

- **Entry point**: `src/bin/ralph.cr`
- **Runner**: `src/ralph/cli/runner.cr` — Handles command parsing and dispatching
- **Generators**: `src/ralph/cli/generators/` — Model generator

## Key Patterns

### Defining a Model

```crystal
class User < Ralph::Model
  table :users

  column id : Int64, primary: true
  column name : String
  column email : String
  column created_at : Time?

  validates_presence_of :name
  validates_format_of :email, pattern: /@/

  has_many posts

  setup_validations
  setup_callbacks
end
```

### Query Builder Usage

```crystal
# Find with conditions
User.query { |q| q.where("age > ?", 18).order("name", :asc) }

# Joins
User.join_assoc(:posts, :left)

# Aggregates
User.count
User.sum("age")
```

### Configuration

```crystal
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
end
```

## Environment Variables

- `RALPH_ENV` — Environment name (default: "development")
- `DATABASE_URL` — Database connection string

## Conventions

- Database config looked for at `./config/database.yml`
- Migrations stored in `./db/migrations/`
- Seeds file at `./db/seeds.cr`
- Default database path: `./db/{environment}.sqlite3`

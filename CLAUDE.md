# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ralph is an Active Record-style ORM for Crystal with a focus on developer experience, type safety, and explicit behavior. Supports SQLite and PostgreSQL backends with automatic cross-database type compatibility.

**GREENFIELD PROJECT**: No backward compatibility requirements. Breaking changes are acceptable when they improve the design.

## Build & Development Commands

```bash
# Install dependencies
shards install

# Run tests (fast - excludes slow doc validation)
crystal spec --tag "~docs"

# Run ALL tests including documentation validation
crystal spec

# Run a single test file
crystal spec spec/path/to/file_spec.cr

# Type check without running
crystal build --no-codegen src/ralph.cr

# Format code
crystal tool format
```

**When to run doc specs**: Only run `crystal spec spec/docs/` when modifying markdown files with Crystal code blocks, changing macro syntax, or before releases.

### Using `just` (optional)

```bash
just install     # Install deps
just test        # Run all specs
just test-file FILE  # Run specific spec
just fmt         # Format code
just check       # Type check
```

## CLI

The CLI requires a separate shard file with adapter dependencies:

```bash
shards install --shard-file=shard.cli.yml
crystal build src/bin/ralph.cr -o bin/ralph
./bin/ralph
```

Commands: `db:create`, `db:migrate`, `db:rollback`, `db:status`, `db:reset`, `db:setup`, `g:migration NAME`, `g:model NAME field:type`

## Architecture

### Core Files

| File | Purpose |
|------|---------|
| `src/ralph/model.cr` | Base model class, column macro, CRUD, dirty tracking (1906 lines) |
| `src/ralph/associations.cr` | belongs_to/has_many/has_one macros (1537 lines) |
| `src/ralph/query/builder.cr` | Fluent query builder, immutable (1821 lines) |
| `src/ralph/validations.cr` | validates_* macros |
| `src/ralph/callbacks.cr` | @[BeforeSave] etc. annotations |
| `src/ralph/timestamps.cr` | `Ralph::Timestamps` module for created_at/updated_at |
| `src/ralph/acts_as_paranoid.cr` | Soft delete support |
| `src/ralph/eager_loading.cr` | Preloading associations |
| `src/ralph/migrations/` | Migration DSL, migrator, schema builder |
| `src/ralph/backends/` | sqlite.cr, postgres.cr implementations |
| `src/ralph/types/` | Cross-backend type system (array, enum, uuid, json) |

### Model Definition

```crystal
class User < Ralph::Model
  table :users

  # Type declaration syntax (preferred, Crystal-idiomatic)
  column id : Int64, primary: true
  column name : String
  column email : String

  # Positional syntax also works
  # column id, Int64, primary: true

  include Ralph::Timestamps  # Auto-manages created_at/updated_at

  validates_presence_of :name
  validates_format_of :email, pattern: /@/

  # Association type syntax
  has_many posts : Post
  belongs_to organization : Organization, optional: true

  # Symbol syntax also works
  # has_many :posts, class_name: "Post"
end
```

**Note:** `setup_validations` and `setup_callbacks` are no longer required — the `macro finished` hook handles this automatically.

### Query Builder (Immutable)

Each method returns a NEW Builder instance. Safe for branching:

```crystal
base = User.query { |q| q.where("active = ?", true) }
admins = base.where("role = ?", "admin")  # base unchanged
users = base.where("role = ?", "user")    # base unchanged
```

### Configuration

```crystal
# SQLite
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
end

# PostgreSQL
Ralph.configure do |config|
  config.database = Ralph::Database::PostgresBackend.new("postgres://user:pass@host/db")
end
```

## Key Patterns

### Callbacks via Annotations

```crystal
@[Ralph::Callbacks::BeforeCreate]
def set_defaults
  self.status = "pending"
end
```

### Scopes

```crystal
scope :active, ->(q : Ralph::Query::Builder) { q.where("active = ?", true) }
scope :recent, ->(q : Ralph::Query::Builder) { q.order("created_at", :desc).limit(10) }
```

### Soft Deletes

```crystal
class Post < Ralph::Model
  include Ralph::ActsAsParanoid
  # Adds deleted_at column, overrides destroy to soft-delete
end
```

## Testing

```bash
# Default development (fast)
crystal spec --tag "~docs"

# PostgreSQL integration
DB_ADAPTER=postgres POSTGRES_URL=postgres://localhost/ralph_test crystal spec spec/ralph/integration/
```

Test helpers in `spec/ralph/test_helper.cr`:
- `RalphTestHelper.setup_test_database` — Creates users/posts tables
- `RalphTestHelper.cleanup_test_database` — Truncates for isolation

### Documentation Code Blocks

Code blocks in `docs/` are validated by `spec/docs/`. To skip compilation for illustrative snippets:

````markdown
```crystal compile=false
create_table :example do |t|
  t.string :name
end
```
````

## Conventions

- Database config: `./config/database.yml`
- Migrations: `./db/migrations/`
- Seeds: `./db/seeds.cr`
- Foreign keys: `{association}_id`
- Polymorphic: `{name}_id` + `{name}_type` columns
- Private ivars: prefix with `_` to avoid column conflicts
- Macro-generated methods: prefix with `_ralph_`

## Environment Variables

- `RALPH_ENV` — Environment name (default: "development")
- `DATABASE_URL` — Database connection string

## Anti-Patterns

| Avoid | Instead |
|-------|---------|
| Modifying `@wheres` directly | Use `where()` builder method |
| Calling `Ralph.database` before configure | Check `settings.database?` first |
| Creating ivars without `_` prefix | Prefix with `_` (e.g., `@_cache`) |
| Assuming backend in type code | Use dialect checks for backend-specific SQL |

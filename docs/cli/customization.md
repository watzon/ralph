# CLI Setup & Customization

Ralph does not ship pre-compiled CLI binaries. Instead, you create a small Crystal file in your project that requires your migrations and models, then compiles everything together. This approach is standard in the Crystal ecosystem and provides several benefits:

- **Type Safety**: Your migrations are compiled with full type checking
- **Flexibility**: Require only the database backends you need
- **Customization**: Configure paths and defaults for your project structure

## Quick Start

### 1. Create a `ralph.cr` file

Create a file named `ralph.cr` in your project root:

```crystal
#!/usr/bin/env crystal

require "ralph"
require "ralph/backends/sqlite"  # and/or "ralph/backends/postgres"
require "./db/migrations/*"
require "./src/models/*"         # Optional: only needed for seeds

Ralph::Cli::Runner.new.run
```

### 2. Run the CLI

You can run the CLI directly with Crystal:

```bash
crystal run ./ralph.cr -- db:migrate
crystal run ./ralph.cr -- db:status
crystal run ./ralph.cr -- g:model User name:string
```

Or build it once for faster subsequent runs:

```bash
crystal build ralph.cr -o bin/ralph
./bin/ralph db:migrate
```

Or make it executable and run directly:

```bash
chmod +x ralph.cr
./ralph.cr db:migrate
```

!!! tip "Using `--`"
    When using `crystal run`, arguments after `--` are passed to your program. Without it, Crystal interprets them as compiler flags.

## Configuration Options

### Custom Paths

If your project uses a non-standard directory structure, configure the Runner:

```crystal
Ralph::Cli::Runner.new(
  migrations_dir: "./db/my_migrations",
  models_dir: "./src/my_app/models"
).run
```

### Database URL

Set a default database URL for your project:

```crystal
#!/usr/bin/env crystal

require "ralph"
require "ralph/backends/sqlite"
require "./db/migrations/*"

# Set default database URL (can still be overridden via -d flag or DATABASE_URL)
ENV["DATABASE_URL"] ||= "sqlite3://./my_app.sqlite3"

Ralph::Cli::Runner.new(
  migrations_dir: "./db/migrations",
  models_dir: "./src/models"
).run
```

### Multiple Backends

Require only the backends you need:

```crystal
require "ralph"

# SQLite only
require "ralph/backends/sqlite"

# PostgreSQL only
# require "ralph/backends/postgres"

# Both (choose at runtime via DATABASE_URL)
# require "ralph/backends/sqlite"
# require "ralph/backends/postgres"
```

## Runtime Flags

Even with a custom CLI, you can override settings at runtime:

| Option | Flag | Description |
|--------|------|-------------|
| Migrations | `-m`, `--migrations` | Migrations directory path |
| Models | `--models` | Models directory path |
| Database | `-d`, `--database` | Database URL |
| Environment | `-e`, `--env` | Environment name |

**Example:**

```bash
./ralph.cr g:model Post title:string -m ./custom/migrations --models ./custom/models
```

## Complete Example

Here's a full example for a typical web application:

```crystal
#!/usr/bin/env crystal

# ralph.cr - CLI entry point for database management

require "ralph"

# Require your database backend(s)
require "ralph/backends/sqlite"
# require "ralph/backends/postgres"

# Require all migrations (they auto-register with the migrator)
require "./db/migrations/*"

# Require models (needed for seeds that create records)
require "./src/models/*"

# Optional: Set project-specific defaults
ENV["DATABASE_URL"] ||= "sqlite3://./db/#{ENV["RALPH_ENV"]? || "development"}.sqlite3"

# Run the CLI
Ralph::Cli::Runner.new(
  migrations_dir: "./db/migrations",
  models_dir: "./src/models"
).run
```

## Why No Pre-built Binary?

Crystal is a compiled language, and migrations are Crystal code. For the CLI to run your migrations, it must compile them together. This means:

1. **Migrations must be `require`d** at compile time
2. **The CLI binary includes your migration code**
3. **Each project needs its own compiled CLI**

This is the same approach used by other Crystal ORMs like Micrate and Clear. The tradeoff is a small setup step in exchange for full type safety and the ability to use any Crystal code in your migrations.

## Framework Integration

### Lucky Framework

```crystal
# ralph.cr
require "ralph"
require "ralph/backends/postgres"
require "./db/migrations/*"
require "./src/models/*"

Ralph::Cli::Runner.new(
  migrations_dir: "./db/migrations",
  models_dir: "./src/models"
).run
```

### Kemal

```crystal
# ralph.cr
require "ralph"
require "ralph/backends/sqlite"
require "./src/migrations/*"
require "./src/models/*"

Ralph::Cli::Runner.new(
  migrations_dir: "./src/migrations",
  models_dir: "./src/models"
).run
```

## Programmatic Migration

You can also run migrations programmatically without the CLI:

```crystal
require "ralph"
require "ralph/backends/sqlite"
require "./db/migrations/*"

# Configure Ralph
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
end

# Run migrations on startup
migrator = Ralph::Migrations::Migrator.new(Ralph.database)
migrator.migrate
```

This is useful for running migrations automatically when your application starts.

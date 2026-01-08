# CLI Commands

Ralph includes a powerful command-line interface (CLI) to help you manage your database schema and generate code. This guide covers all available commands and their usage.

## Overview

Ralph does not ship pre-compiled CLI binaries. Instead, you create a small Crystal file in your project that compiles together with your migrations and models. This approach is common in the Crystal ecosystem (used by Micrate, Clear, and others) and provides full type safety for your migrations.

For setup instructions, see the [CLI Customization Guide](./customization.md).

Once set up, you can run the CLI with:

```bash
crystal run ./ralph.cr -- [command]

# Or build once and run directly
crystal build ralph.cr -o bin/ralph
./bin/ralph [command]
```

## Database Commands

These commands manage your database lifecycle, from creation to migrations and seeding.

### `db:create`

Creates the database defined in your configuration or specified via the `--database` flag. 

For PostgreSQL, this connects to the default `postgres` database to execute the `CREATE DATABASE` command.

**Usage:**

```bash
./ralph.cr db:create
```

**Example (SQLite):**

```bash
$ ./ralph.cr db:create
Created database: ./db/development.sqlite3
```

**Example (PostgreSQL):**

```bash
$ DATABASE_URL=postgres://localhost/my_app_dev ./ralph.cr db:create
Created database: my_app_dev
```

### `db:drop`

!!! danger "Warning"
    This command will permanently delete your database and all its data. Use with extreme caution.

Drops the database. For PostgreSQL, this command will attempt to terminate all existing connections to the target database before dropping it.

**Usage:**

```bash
./ralph.cr db:drop
```

**Example:**

```bash
$ ./ralph.cr db:drop
Dropped database: ./db/development.sqlite3
```

### `db:migrate`

Runs all pending migrations in the migrations directory.

**Usage:**

```bash
./ralph.cr db:migrate [options]
```

**Options:**

- `-e, --env ENV`: Environment (default: development)
- `-d, --database URL`: Database URL
- `-m, --migrations DIR`: Migrations directory (default: `./db/migrations`)
- `--models DIR`: Models directory (default: `./src/models`)

### `db:rollback`

Rolls back the most recently applied migration.

**Usage:**

```bash
./ralph.cr db:rollback
```

### `db:status`

Shows the status of all migrations (applied or pending).

**Usage:**

```bash
./ralph.cr db:status
```

**Example output:**

```
Migration status:
Status      Migration ID
--------------------------------------------------
[   UP    ] 20260107000001
[   UP    ] 20260107000002
[  DOWN   ] 20260107000003
```

### `db:version`

Shows the current migration version (the most recently applied migration).

**Usage:**

```bash
./ralph.cr db:version
```

### `db:seed`

Loads and executes the seed file (`./db/seeds.cr`). The seed file is a regular Crystal file that runs independently, so it must require Ralph and configure the database connection.

**Usage:**

```bash
./ralph.cr db:seed
```

**Creating a Seed File:**

Create `db/seeds.cr` in your project:

```crystal
#!/usr/bin/env crystal

require "ralph"
require "ralph/backends/sqlite"  # or postgres
require "../src/models/*"

# Configure database (must match your app's configuration)
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db/development.sqlite3")
end

# Use find_or_create_by for idempotent seeds
admin = User.find_or_create_by({"email" => "admin@example.com"}) do |u|
  u.name = "Administrator"
  u.role = "admin"
end

puts "Seeded #{User.count} users"
```

!!! tip "Idempotent Seeds"
    Use `find_or_create_by` or `find_or_initialize_by` to make your seeds idempotent—safe to run multiple times without creating duplicates. See [CRUD Operations](../models/crud-operations.md#find-or-initialize-find-or-create) for details.

### `db:reset`

Drops, creates, migrates, and seeds the database in one command.

**Usage:**

```bash
./ralph.cr db:reset
```

### `db:setup`

Creates the database and runs all migrations.

**Usage:**

```bash
./ralph.cr db:setup
```

---

## Generator Commands

### `g:migration`

Creates a new migration file.

**Usage:**

```bash
./ralph.cr g:migration NAME
```

**Example:**

```bash
$ ./ralph.cr g:migration CreateUsers
Created migration: ./db/migrations/20260108123456_create_users.cr
```

### `g:model`

Generates a model file and an accompanying migration.

**Usage:**

```bash
./ralph.cr g:model NAME [field:type ...]
```

**Example:**

```bash
./ralph.cr g:model User name:string email:string
```

---

## Global Options

- `-e, --env ENV`: Specifies the environment (e.g., `development`, `test`, `production`). Default is `development`.
- `-d, --database URL`: Overrides the database URL from configuration.
- `-m, --migrations DIR`: Overrides the migrations directory path. Default is `./db/migrations`.
- `--models DIR`: Overrides the models directory path. Default is `./src/models`.
- `-h, --help`: Shows the help message.
- `version`: Shows the Ralph version.

---

## Configuration

The CLI looks for database configuration in several places, in order of precedence:

1.  The `-d` or `--database` flag.
2.  The `DATABASE_URL` environment variable.
3.  The `POSTGRES_URL` environment variable.
4.  The `SQLITE_URL` environment variable.
5.  A default SQLite URL based on the environment: `sqlite3://./db/#{environment}.sqlite3`.

The CLI automatically detects the database type from the URL scheme (`postgres://`, `postgresql://`, or `sqlite3://`).

---

## Common Workflows

### Starting a New Project

1.  Set up the CLI (see [Customization Guide](./customization.md)).
2.  Run `./ralph.cr db:setup` to create the database.
3.  Generate your first model: `./ralph.cr g:model User name:string`.
4.  Run `./ralph.cr db:migrate`.

### Iterating on Schema

1.  Create a migration: `./ralph.cr g:migration AddRoleToUsers`.
2.  Edit the generated file in `db/migrations/`.
3.  Run `./ralph.cr db:migrate`.
4.  If you made a mistake, run `./ralph.cr db:rollback`, fix the file, and migrate again.

---

## Troubleshooting

### "Unknown command"

Ensure you are using the correct command name. Check `./ralph.cr help` for the list of available commands.

### "Database creation not implemented"

Ralph supports database creation for SQLite and PostgreSQL. Ensure your database URL scheme is supported (`sqlite3://`, `postgres://`, or `postgresql://`).

### "No migrations have been run"

This message appears when calling `db:version` on an empty database. Run `db:migrate` to apply migrations.

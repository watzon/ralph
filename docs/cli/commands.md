# CLI Commands

Ralph includes a powerful command-line interface (CLI) to help you manage your database schema and generate code. This guide covers all available commands and their usage.

## Overview

Ralph's CLI can be compiled once and reused without recompilation when you add new migrations. This is because migrations are plain SQL files that are read and executed at runtime.

For setup instructions, see the [CLI Customization Guide](./customization.md).

Once set up, you can run the CLI with:

```bash
crystal run ./ralph.cr -- [command]

# Or build once and run directly (recommended)
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
./ralph db:create
```

**Example (SQLite):**

```bash
$ ./ralph db:create
Created database: ./db/development.sqlite3
```

**Example (PostgreSQL):**

```bash
$ DATABASE_URL=postgres://localhost/my_app_dev ./ralph db:create
Created database: my_app_dev
```

### `db:drop`

!!! danger "Warning"
    This command will permanently delete your database and all its data. Use with extreme caution.

Drops the database. For PostgreSQL, this command will attempt to terminate all existing connections to the target database before dropping it.

**Usage:**

```bash
./ralph db:drop
```

**Example:**

```bash
$ ./ralph db:drop
Dropped database: ./db/development.sqlite3
```

### `db:migrate`

Runs all pending SQL migrations from the migrations directory.

**Usage:**

```bash
./ralph db:migrate [options]
```

**Options:**

- `-e, --env ENV`: Environment (default: development)
- `-d, --database URL`: Database URL
- `-m, --migrations DIR`: Migrations directory (default: `./db/migrations`)

**Example:**

```bash
$ ./ralph db:migrate
Running: 20260101120000_create_users
Running: 20260101120100_create_posts
Ran 2 migration(s)
```

### `db:rollback`

Rolls back the most recently applied migration.

**Usage:**

```bash
./ralph db:rollback [options]
```

**Options:**

- `--steps=N`: Roll back N migrations (default: 1)

**Examples:**

```bash
# Roll back one migration
./ralph db:rollback

# Roll back three migrations
./ralph db:rollback --steps=3
```

### `db:rollback:all`

Rolls back all applied migrations.

**Usage:**

```bash
./ralph db:rollback:all
```

### `db:status`

Shows the status of all migrations (applied or pending).

**Usage:**

```bash
./ralph db:status
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
./ralph db:version
```

### `db:seed`

Loads and executes the seed file (`./db/seeds.cr`). The seed file is a regular Crystal file that runs independently, so it must require Ralph and configure the database connection.

**Usage:**

```bash
./ralph db:seed
```

**Creating a Seed File:**

Create `db/seeds.cr` in your project:

<!-- skip-compile -->
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
./ralph db:reset
```

### `db:setup`

Creates the database and runs all migrations.

**Usage:**

```bash
./ralph db:setup
```

### `db:pool`

Shows connection pool status and configuration.

**Usage:**

```bash
./ralph db:pool
```

### `db:pull`

Generates model files from an existing database schema. Useful for creating models from a legacy database.

**Usage:**

```bash
./ralph db:pull [options]
```

**Options:**

- `--tables=TABLE1,TABLE2`: Only pull specific tables
- `--skip=TABLE1,TABLE2`: Skip specific tables
- `--overwrite`: Overwrite existing model files
- `--dry-run`: Preview without generating files
- `--models DIR`: Output directory for models

**Examples:**

```bash
# Pull all tables
./ralph db:pull

# Pull specific tables
./ralph db:pull --tables=users,posts

# Preview without generating
./ralph db:pull --dry-run
```

### `db:generate`

Generates a migration from the difference between your models and the database schema.

**Usage:**

```bash
./ralph db:generate [options]
```

**Options:**

- `--name=NAME`: Migration name (default: auto_migration)
- `--dry-run`: Preview changes without generating
- `-m, --migrations DIR`: Output directory

**Example:**

```bash
$ ./ralph db:generate --name=add_status_to_orders
Analyzing models...
Found 3 model(s)
Introspecting database...
Found 2 table(s)

Changes detected:
  + CREATE TABLE orders
  + ADD COLUMN users.status (string)

Generated: ./db/migrations/20260108123456_add_status_to_orders.sql
```

---

## Generator Commands

### `g:migration`

Creates a new SQL migration file.

**Usage:**

```bash
./ralph g:migration NAME
```

**Example:**

```bash
$ ./ralph g:migration create_users
Created migration: ./db/migrations/20260108123456_create_users.sql
```

The generated file looks like:

```sql
-- Migration: create_users
-- Created: 2026-01-08 12:34:56 UTC

-- +migrate Up
-- Write your UP migration SQL here

-- +migrate Down
-- Write your DOWN migration SQL here (reverses the UP)
```

### `g:model`

Generates a model file and an accompanying SQL migration.

**Usage:**

```bash
./ralph g:model NAME [field:type ...]
```

**Field Types:**

- `string` - VARCHAR(255)
- `text` - TEXT
- `integer` - INTEGER
- `bigint` - BIGINT
- `float` - DOUBLE PRECISION
- `boolean` - BOOLEAN
- `timestamp` - TIMESTAMP
- `json` / `jsonb` - JSON/JSONB
- `uuid` - UUID

**Example:**

```bash
$ ./ralph g:model User name:string email:string active:boolean
Created model: User
  - ./src/models/user.cr
  - ./db/migrations/20260108123456_create_users.sql
```

The generated migration:

```sql
-- Migration: Create users
-- Generated: 2026-01-08 12:34:56 UTC

-- +migrate Up
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    active BOOLEAN NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- +migrate Down
DROP TABLE IF EXISTS users;
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
2.  Run `./ralph db:setup` to create the database.
3.  Generate your first model: `./ralph g:model User name:string email:string`.
4.  Run `./ralph db:migrate`.

### Iterating on Schema

1.  Create a migration: `./ralph g:migration add_role_to_users`.
2.  Edit the generated SQL file in `db/migrations/`.
3.  Run `./ralph db:migrate`.
4.  If you made a mistake, run `./ralph db:rollback`, fix the file, and migrate again.

### Converting from Crystal DSL Migrations

If you have existing Crystal-based migrations, you can:

1. Run your existing migrations to bring the database up to date
2. Create new migrations as SQL files going forward
3. Optionally export the SQL from your Crystal migrations and create equivalent `.sql` files

---

## Migration File Format

Ralph uses SQL migration files with special comment markers:

```sql
-- +migrate Up
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL
);

-- +migrate Down
DROP TABLE IF EXISTS users;
```

For complex statements with semicolons (functions, triggers), use:

```sql
-- +migrate StatementBegin
CREATE FUNCTION ...
-- +migrate StatementEnd
```

For statements that can't run in a transaction:

```sql
-- +migrate NoTransaction

-- +migrate Up
CREATE INDEX CONCURRENTLY ...
```

See [Migrations Introduction](../migrations/introduction.md) for full details.

---

## Troubleshooting

### "Unknown command"

Ensure you are using the correct command name. Check `./ralph help` for the list of available commands.

### "Database creation not implemented"

Ralph supports database creation for SQLite and PostgreSQL. Ensure your database URL scheme is supported (`sqlite3://`, `postgres://`, or `postgresql://`).

### "No migrations have been run"

This message appears when calling `db:version` on an empty database. Run `db:migrate` to apply migrations.

### "Migration file not found"

Ensure your migration files:
- Are in the `db/migrations/` directory (or the directory specified with `-m`)
- Have a `.sql` extension
- Follow the naming pattern: `TIMESTAMP_name.sql` (e.g., `20260108123456_create_users.sql`)

# Migrations: Introduction

Migrations are a way to manage your database schema over time in a consistent and version-controlled manner. Ralph uses **plain SQL migration files** that can be executed at runtime without recompilation.

## What are Migrations?

A migration is a SQL file that defines two sections:

- `-- +migrate Up`: The changes to apply to the database (creating tables, adding columns, etc.)
- `-- +migrate Down`: How to reverse those changes (dropping tables, removing columns, etc.)

Ralph tracks which migrations have already been run in a special table called `schema_migrations`, ensuring that each migration is only applied once.

## Creating Migrations

Use the Ralph CLI to generate a new migration file:

```bash
ralph g:migration create_users_table
```

This creates a new file in `db/migrations/` with a timestamp prefix, like `20240101120000_create_users_table.sql`.

## Migration File Structure

A typical migration looks like this:

```sql
-- Migration: Create users table
-- Created: 2024-01-01

-- +migrate Up
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX index_users_on_email ON users (email);

-- +migrate Down
DROP INDEX IF EXISTS index_users_on_email;
DROP TABLE IF EXISTS users;
```

## Running Migrations

### Apply Pending Migrations

To run all migrations that haven't been applied yet:

```bash
ralph db:migrate
```

### Rollback the Last Migration

If you need to undo the most recent migration:

```bash
ralph db:rollback
```

To rollback multiple migrations:

```bash
ralph db:rollback --steps=3
```

### Rollback All Migrations

```bash
ralph db:rollback:all
```

### Check Migration Status

To see which migrations are currently applied:

```bash
ralph db:status
```

## Statement Blocks for Complex SQL

For complex statements like functions or triggers that contain semicolons, wrap them in StatementBegin/StatementEnd markers:

```sql
-- +migrate Up
-- +migrate StatementBegin
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- +migrate StatementEnd

-- +migrate StatementBegin
CREATE TRIGGER set_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();
-- +migrate StatementEnd

-- +migrate Down
DROP TRIGGER IF EXISTS set_updated_at ON users;
DROP FUNCTION IF EXISTS update_updated_at();
```

## No Transaction Mode

Some statements (like `CREATE INDEX CONCURRENTLY` in PostgreSQL) cannot run inside a transaction. Add the NoTransaction directive at the start of your migration:

```sql
-- +migrate NoTransaction

-- +migrate Up
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);

-- +migrate Down
DROP INDEX CONCURRENTLY IF EXISTS idx_users_email;
```

## Migration Ordering

Migrations are executed in the order of their timestamp prefixes. The convention is to use timestamp-prefixed filenames (`20240101120000_create_users.sql`) which ensures correct ordering when sorted alphabetically.

!!! tip "Consistent Ordering"
    Always use the CLI generator (`ralph g:migration`) to create migrations. This ensures timestamps are generated correctly and migrations run in the proper order.

## Best Practices

### 1. Make Migrations Reversible

Always ensure your `-- +migrate Down` section correctly reverses every action taken in `-- +migrate Up`. If you create a table, drop it in down. If you add a column, remove it.

### 2. Keep Data and Schema Separate

While you _can_ use migrations to move or transform data, it's often better to keep schema changes and data changes separate. If a data migration fails, it can leave your database in an inconsistent state.

```sql
-- Acceptable: Simple data backfill
-- +migrate Up
ALTER TABLE users ADD COLUMN role VARCHAR(50) DEFAULT 'member';

-- +migrate Down
ALTER TABLE users DROP COLUMN role;
```

```sql
-- Risky: Complex data transformation with schema changes
-- +migrate Up
ALTER TABLE users ADD COLUMN full_name VARCHAR(255);
UPDATE users SET full_name = first_name || ' ' || last_name;
ALTER TABLE users DROP COLUMN first_name;
ALTER TABLE users DROP COLUMN last_name;

-- If any step fails, you're in trouble!
```

### 3. Use `ralph db:reset` for Local Development

If you've made a mess of your local database schema, you can quickly reset everything:

```bash
ralph db:reset
```

_Warning: This will drop your database and all its data!_

### 4. Don't Modify Existing Migrations

Once a migration has been committed and shared with other developers or deployed to production, you should never modify it. Instead, create a new migration to make further changes.

### 5. Test Migrations Both Ways

Before committing, verify that both `up` and `down` work correctly:

```bash
ralph db:migrate      # Apply
ralph db:rollback     # Roll back
ralph db:migrate      # Re-apply (should work identically)
```

### 6. Keep Migrations Small and Focused

Each migration should do one logical thing. Instead of creating multiple tables in one migration, create separate migrations for each table. This makes rollbacks more granular and debugging easier.

### 7. Write Backend-Appropriate SQL

Since migrations are plain SQL, write SQL that's appropriate for your database backend:

**PostgreSQL:**
```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    data JSONB DEFAULT '{}'
);
```

**SQLite:**
```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    data TEXT DEFAULT '{}'
);
```

## Workflow Example

1. **Generate**: `ralph g:migration add_role_to_users`
2. **Edit**: Add `ALTER TABLE users ADD COLUMN role VARCHAR(50) DEFAULT 'user';` to Up and `ALTER TABLE users DROP COLUMN role;` to Down.
3. **Migrate**: `ralph db:migrate`
4. **Test**: Verify your models can now use the `role` column.
5. **Commit**: Add the migration file to your version control (e.g., Git).

## Next Steps

- [Schema Reference](schema-builder.md) - Learn the schema DSL for generating reference documentation
- [Programmatic API](programmatic-api.md) - Run migrations from code, auto-migrate on startup
- [Error Handling](error-handling.md) - Understanding and handling migration errors

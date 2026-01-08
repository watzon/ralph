# Configuration

Ralph is designed to be easy to configure while providing flexibility for different environments and database backends.

## The Configure Block

The primary way to configure Ralph is through the `Ralph.configure` block. This block allows you to set global settings for the ORM, such as the database backend.

```crystal
require "ralph"

Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
end
```

### Settings Options

Currently, Ralph supports the following configuration options:

| Option     | Type                        | Description                                     |
| :--------- | :-------------------------- | :---------------------------------------------- |
| `database` | `Ralph::Database::Backend?` | The database backend to use for all operations. |

## Database Backends

Ralph uses a pluggable backend architecture. Currently, it supports SQLite and PostgreSQL.

### SqliteBackend

The `SqliteBackend` is initialized with a connection string. Ralph uses the standard `crystal-db` connection string format.

```crystal
require "ralph/backends/sqlite"

# File-based database
Ralph::Database::SqliteBackend.new("sqlite3://./db/development.sqlite3")

# In-memory database (useful for testing)
Ralph::Database::SqliteBackend.new("sqlite3::memory:")
```

#### WAL Mode

SQLite supports Write-Ahead Logging (WAL) mode, which improves concurrency by allowing readers to proceed while a write is in progress. This is especially beneficial for production applications with concurrent requests.

```crystal
# Enable WAL mode for better concurrency
Ralph::Database::SqliteBackend.new("sqlite3://./db/production.sqlite3", wal_mode: true)

# With custom busy timeout (milliseconds)
Ralph::Database::SqliteBackend.new("sqlite3://./db/production.sqlite3", wal_mode: true, busy_timeout: 10000)
```

**When to use WAL mode:**
- Production environments with concurrent reads and writes
- Applications requiring better read/write performance
- Multi-threaded web servers

**Trade-offs:**
- Creates additional files (`.sqlite3-wal`, `.sqlite3-shm`)
- Not supported for in-memory databases
- Slightly different file locking behavior

**Default behavior:** Without `wal_mode: true`, Ralph uses a mutex to serialize all write operations from the application, which prevents "database is locked" errors but limits write throughput.

### PostgresBackend

The `PostgresBackend` allows you to connect to a PostgreSQL database.

```crystal
require "ralph/backends/postgres"

# Standard connection string
Ralph::Database::PostgresBackend.new("postgres://user:pass@localhost:5432/my_database")

# Using Unix sockets
Ralph::Database::PostgresBackend.new("postgres://user@localhost/my_database?host=/var/run/postgresql")
```

## Environment-Specific Configuration

For real-world applications, you'll likely want different configurations for different environments (development, testing, production). A common pattern in Crystal applications is to use environment variables.

### Environment Variables

Ralph's CLI and backends respect several environment variables for database configuration. They are checked in the following order:

1. `DATABASE_URL` - General database URL
2. `POSTGRES_URL` - PostgreSQL specific URL
3. `SQLITE_URL` - SQLite specific URL

### Configuration Example

```crystal
Ralph.configure do |config|
  db_url = ENV["DATABASE_URL"]? || ENV["SQLITE_URL"]? || "sqlite3://./db/development.sqlite3"
  
  if db_url.starts_with?("postgres")
    require "ralph/backends/postgres"
    config.database = Ralph::Database::PostgresBackend.new(db_url)
  else
    require "ralph/backends/sqlite"
    config.database = Ralph::Database::SqliteBackend.new(db_url)
  end
end
```

### CLI Environment

The Ralph CLI also respects the `RALPH_ENV` environment variable. By default, it looks for a database at `./db/development.sqlite3`, but if `RALPH_ENV` is set to `production`, it will look for `./db/production.sqlite3`.

```bash
# Run migrations for the production environment
RALPH_ENV=production ralph db:migrate
```

## Testing Configuration

When writing tests, it's often best to use an in-memory database to ensure tests are fast and isolated.

```crystal
# spec/spec_helper.cr
require "spec"
require "../src/ralph"

Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3::memory:")
end

# Optional: Run migrations for the in-memory database
Ralph::Migrations::Migrator.new(Ralph.database, "./db/migrations").migrate
```

## Manual Access to Settings

You can also access and modify settings directly through `Ralph.settings`:

```crystal
Ralph.settings.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
```

However, using the `Ralph.configure` block is recommended for better readability and initialization order.

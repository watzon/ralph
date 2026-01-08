# Database

`module`

*Defined in [src/ralph/backends/postgres.cr:5](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L5)*

Abstract database backend interface

All database backends must implement this interface to provide
a common API for database operations.

## Backend Loading

Backends are NOT loaded automatically. Users must explicitly require
the backend they want to use:

```
require "ralph/backends/sqlite"   # For SQLite
require "ralph/backends/postgres" # For PostgreSQL
```

This allows backends to be truly optional - you only need the
database driver shard for the backend you're actually using.

## Nested Types

- [`PostgresBackend`](ralph-database-postgresbackend.md) - <p>PostgreSQL database backend implementation</p>
- [`SqliteBackend`](ralph-database-sqlitebackend.md) - <p>SQLite database backend implementation</p>


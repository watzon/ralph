# SqliteBackend

`class`

*Defined in [src/ralph/backends/sqlite.cr:46](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L46)*

SQLite database backend implementation

Provides SQLite-specific database operations for Ralph ORM.
Uses the crystal-sqlite3 shard for database connectivity.

## Example

```
# File-based database
backend = Ralph::Database::SqliteBackend.new("sqlite3://./db/development.sqlite3")

# In-memory database (useful for testing)
backend = Ralph::Database::SqliteBackend.new("sqlite3::memory:")

# Enable WAL mode for better concurrency in production
backend = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3", wal_mode: true)
```

## Connection String Format

SQLite connection strings follow the format: `sqlite3://path/to/database.db`

Special values:
- `sqlite3::memory:` - Creates an in-memory database

## Concurrency

SQLite only supports one writer at a time. This backend provides two modes:

1. **Default mode (wal_mode: false)**: Uses a mutex to serialize all write
   operations from this application. This prevents "database is locked"
   errors but limits write throughput to one operation at a time.

2. **WAL mode (wal_mode: true)**: Enables SQLite's Write-Ahead Logging,
   which allows concurrent reads during writes. Writes are still serialized
   by SQLite but don't block readers. Recommended for production use with
   concurrent requests.

Note: WAL mode creates additional files (.sqlite3-wal, .sqlite3-shm) and
is not supported for in-memory databases.

## Constructors

### `.new(connection_string : String, wal_mode : Bool = false, busy_timeout : Int32 = 5000)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L69)*

Creates a new SQLite backend with the given connection string

## Parameters

- `connection_string`: SQLite connection URI
- `wal_mode`: Enable WAL mode for better concurrency (default: false)
- `busy_timeout`: Milliseconds to wait for locks (default: 5000)

## Example

```
# Basic usage
backend = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")

# Production usage with WAL mode
backend = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3", wal_mode: true)
```

---

## Instance Methods

### `#begin_transaction_sql`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L153)*

SQL to begin a transaction

---

### `#close`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L140)*

Close the database connection

---

### `#closed?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L145)*

Check if the connection is open

---

### `#commit_sql`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L157)*

SQL to commit a transaction

---

### `#dialect`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L177)*

Returns the dialect identifier for this backend
Used by migrations and schema generation

---

### `#execute(query : String, args : Array(DB::Any) = [] of DB::Any)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L85)*

Execute a write query (INSERT, UPDATE, DELETE, DDL)
Serialized through mutex when not in WAL mode

---

### `#insert(query : String, args : Array(DB::Any) = [] of DB::Any) : Int64`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L93)*

Insert a record and return the last inserted row ID
Uses the same connection for both operations to ensure correctness

---

### `#query_all(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::ResultSet`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L109)*

Query for multiple rows

---

### `#query_one(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::ResultSet | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L103)*

Query for a single row, returns nil if no results

---

### `#release_savepoint_sql(name : String) : String`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L169)*

SQL to release a savepoint

---

### `#rollback_sql`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L161)*

SQL to rollback a transaction

---

### `#rollback_to_savepoint_sql(name : String) : String`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L173)*

SQL to rollback to a savepoint

---

### `#savepoint_sql(name : String) : String`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L165)*

SQL to create a savepoint

---

### `#scalar(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::Any | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L114)*

Execute a scalar query and return a single value

---

### `#transaction`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L132)*

Execute a block within a database transaction
The entire transaction is protected by the write lock

---

### `#wal_mode?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L182)*

Whether WAL mode is enabled

---


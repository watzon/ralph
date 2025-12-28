# SqliteBackend

`class`

*Defined in [src/ralph/backends/sqlite.cr:27](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L27)*

SQLite database backend implementation

Provides SQLite-specific database operations for Ralph ORM.
Uses the crystal-sqlite3 shard for database connectivity.

## Example

```
# File-based database
backend = Ralph::Database::SqliteBackend.new("sqlite3://./db/development.sqlite3")

# In-memory database (useful for testing)
backend = Ralph::Database::SqliteBackend.new("sqlite3::memory:")
```

## Connection String Format

SQLite connection strings follow the format: `sqlite3://path/to/database.db`

Special values:
- `sqlite3::memory:` - Creates an in-memory database

## Constructors

### `.new(connection_string : String)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L38)*

Creates a new SQLite backend with the given connection string

## Example

```
backend = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
```

---

## Instance Methods

### `#begin_transaction_sql`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L95)*

SQL to begin a transaction

---

### `#close`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L82)*

Close the database connection

---

### `#closed?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L87)*

Check if the connection is open

---

### `#commit_sql`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L99)*

SQL to commit a transaction

---

### `#dialect`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L119)*

Returns the dialect identifier for this backend
Used by migrations and schema generation

---

### `#execute(query : String, args : Array(DB::Any) = [] of DB::Any)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L42)*

Execute a query and return the raw result

---

### `#insert(query : String, args : Array(DB::Any) = [] of DB::Any) : Int64`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L46)*

Execute a query and return the last inserted ID

Implementation note: Different backends handle this differently:
- SQLite: Uses `SELECT last_insert_rowid()` after INSERT
- PostgreSQL: Uses `INSERT ... RETURNING id`

---

### `#query_all(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::ResultSet`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L56)*

Query multiple rows

---

### `#query_one(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::ResultSet | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L51)*

Query a single row and map it to a result

---

### `#release_savepoint_sql(name : String) : String`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L111)*

SQL to release a savepoint

---

### `#rollback_sql`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L103)*

SQL to rollback a transaction

---

### `#rollback_to_savepoint_sql(name : String) : String`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L115)*

SQL to rollback to a savepoint

---

### `#savepoint_sql(name : String) : String`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L107)*

SQL to create a savepoint

---

### `#scalar(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::Any | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L60)*

Execute a query and return a single scalar value (first column of first row)

---

### `#transaction`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L76)*

Begin a transaction

---


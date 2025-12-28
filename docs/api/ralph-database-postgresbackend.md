# PostgresBackend

`class`

*Defined in [src/ralph/backends/postgres.cr:39](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L39)*

PostgreSQL database backend implementation

Provides PostgreSQL-specific database operations for Ralph ORM.
Uses the crystal-pg shard for database connectivity.

## Example

```
# Standard connection
backend = Ralph::Database::PostgresBackend.new("postgres://user:pass@localhost:5432/mydb")

# Unix socket connection
backend = Ralph::Database::PostgresBackend.new("postgres://user@localhost/mydb?host=/var/run/postgresql")
```

## Connection String Format

PostgreSQL connection strings follow the format:
`postgres://user:password@host:port/database?options`

Common options:
- `host=/path/to/socket` - Unix socket path
- `sslmode=require` - Require SSL connection

## Placeholder Conversion

This backend automatically converts `?` placeholders to PostgreSQL's
`$1, $2, ...` format, so you can write queries the same way as SQLite.

## INSERT Behavior

PostgreSQL uses `INSERT ... RETURNING id` to get the last inserted ID,
which is handled automatically by the `insert` method.

## Constructors

### `.new(connection_string : String)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L50)*

Creates a new PostgreSQL backend with the given connection string

## Example

```
backend = Ralph::Database::PostgresBackend.new("postgres://localhost/mydb")
```

---

## Instance Methods

### `#begin_transaction_sql`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L110)*

SQL to begin a transaction

---

### `#close`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L97)*

Close the database connection

---

### `#closed?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L102)*

Check if the connection is open

---

### `#commit_sql`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L114)*

SQL to commit a transaction

---

### `#dialect`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L134)*

Returns the dialect identifier for this backend
Used by migrations and schema generation

---

### `#execute(query : String, args : Array(DB::Any) = [] of DB::Any)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L54)*

Execute a query and return the raw result

---

### `#insert(query : String, args : Array(DB::Any) = [] of DB::Any) : Int64`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L58)*

Execute a query and return the last inserted ID

Implementation note: Different backends handle this differently:
- SQLite: Uses `SELECT last_insert_rowid()` after INSERT
- PostgreSQL: Uses `INSERT ... RETURNING id`

---

### `#query_all(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::ResultSet`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L69)*

Query multiple rows

---

### `#query_one(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::ResultSet | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L64)*

Query a single row and map it to a result

---

### `#release_savepoint_sql(name : String) : String`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L126)*

SQL to release a savepoint

---

### `#rollback_sql`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L118)*

SQL to rollback a transaction

---

### `#rollback_to_savepoint_sql(name : String) : String`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L130)*

SQL to rollback to a savepoint

---

### `#savepoint_sql(name : String) : String`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L122)*

SQL to create a savepoint

---

### `#scalar(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::Any | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L73)*

Execute a query and return a single scalar value (first column of first row)

---

### `#transaction`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L91)*

Begin a transaction

---


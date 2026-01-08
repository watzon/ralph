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

## PostgreSQL-Specific Helper Methods

### Text Search Configuration

#### `#available_text_search_configs : Array(String)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L164)*

List all available text search configurations on the server.

Common configurations: 'english', 'simple', 'french', 'german', 'spanish', 'russian', and many more.

```crystal
backend = Ralph.settings.database.as(Ralph::Database::PostgresBackend)
configs = backend.available_text_search_configs
# => ["danish", "dutch", "english", "finnish", "french", ...]
```

---

#### `#text_search_config_info(config_name : String) : Hash(String, String)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L185)*

Get detailed information about a specific text search configuration.

Returns a hash with keys: `name`, `parser`, `schema`

```crystal
backend.text_search_config_info("english")
# => {
#   "name" => "english",
#   "parser" => "default",
#   "schema" => "pg_catalog"
# }
```

---

#### `#text_search_config_exists?(config_name : String) : Bool`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L205)*

Check if a text search configuration exists.

```crystal
backend.text_search_config_exists?("english")   # => true
backend.text_search_config_exists?("nonexistent") # => false
```

---

#### `#create_text_search_config(name : String, copy_from : String = "english")`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L225)*

Create a custom text search configuration by copying from an existing one.

Useful for custom dictionaries or language-specific tokenization.

```crystal
# Create custom English config
backend.create_text_search_config("my_english", copy_from: "english")

# Now can be used in queries
Article.query { |q|
  q.where_search("content", "programming", config: "my_english")
}
```

---

#### `#drop_text_search_config(name : String, if_exists : Bool = true)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L236)*

Drop a custom text search configuration.

```crystal
backend.drop_text_search_config("my_english")

# With if_exists to avoid errors
backend.drop_text_search_config("nonexistent", if_exists: true)
```

---

### PostgreSQL Server Information

#### `#postgres_version : String`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L251)*

Get the PostgreSQL server version.

Returns version as a string (e.g., "15.4", "14.2", "13.10").

```crystal
backend = Ralph.settings.database.as(Ralph::Database::PostgresBackend)
version = backend.postgres_version
# => "15.4"
```

Useful for feature detection:

```crystal
if backend.postgres_version.starts_with?("15") || backend.postgres_version.starts_with?("14")
  # Use PostgreSQL 14+ specific features
end
```

---

### PostgreSQL Extensions

#### `#extension_available?(name : String) : Bool`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L274)*

Check if a PostgreSQL extension is available for installation on the server.

```crystal
backend.extension_available?("pg_trgm")      # => true (usually available)
backend.extension_available?("postgis")      # => false (if not installed)
backend.extension_available?("uuid-ossp")    # => true
```

---

#### `#extension_installed?(name : String) : Bool`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L287)*

Check if a PostgreSQL extension is already installed in the database.

```crystal
backend.extension_installed?("pg_trgm")      # => true (if installed)
backend.extension_installed?("postgis")      # => false
```

---

#### `#create_extension(name : String, if_not_exists : Bool = true)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L306)*

Install a PostgreSQL extension.

Requires superuser or appropriate permissions.

```crystal
# Install extension
backend.create_extension("pg_trgm")

# With if_not_exists (default) to avoid errors
backend.create_extension("uuid-ossp", if_not_exists: true)
```

Common useful extensions:
- `pg_trgm` - Trigram matching for fuzzy text search
- `uuid-ossp` - Additional UUID generation functions
- `pgcrypto` - Cryptographic functions
- `postgis` - Geographic data types and functions
- `hstore` - Key-value data type

---

#### `#drop_extension(name : String, if_exists : Bool = true, cascade : Bool = false)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L312)*

Uninstall a PostgreSQL extension.

```crystal
# Drop extension safely
backend.drop_extension("pg_trgm", if_exists: true)

# Drop with cascade to remove dependent objects
backend.drop_extension("uuid-ossp", cascade: true)
```

**Parameters:**
- `name` - Extension name
- `if_exists` - Don't error if extension doesn't exist (default: true)
- `cascade` - Drop dependent objects (default: false)

---

## PostgreSQL Feature Detection Example

```crystal
backend = Ralph.settings.database.as(Ralph::Database::PostgresBackend)

# Check version for feature support
version = backend.postgres_version.split('.')[0].to_i
if version >= 11
  # Use websearch (available in PostgreSQL 11+)
  Article.query { |q|
    q.where_websearch("content", "crystal -ruby \"web framework\"")
  }
end

# Check extension availability
if backend.extension_available?("pg_trgm")
  # Can use trigram-based fuzzy search
  backend.create_extension("pg_trgm") unless backend.extension_installed?("pg_trgm")
end

# List available text search configs
configs = backend.available_text_search_configs
puts "Available text search configs: #{configs.join(', ')}"
```


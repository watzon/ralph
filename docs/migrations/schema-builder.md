# Schema Reference

The Schema module provides a DSL for describing database tables and columns. This is primarily used for:

- **Schema introspection**: Generating documentation about your database structure
- **Model code generation**: The `db:pull` command uses this to generate model files from existing tables
- **Schema comparison**: The `db:generate` command compares model definitions against the database

!!! note "SQL Migrations"
    For actual database migrations, Ralph uses plain SQL files with `-- +migrate Up/Down` markers.
    See the [Introduction](introduction.md) for details on creating and running migrations.

## Table Definition DSL

The `TableDefinition` class provides methods for describing table structures:

```crystal
definition = Ralph::Migrations::Schema::TableDefinition.new("products")
definition.primary_key
definition.string("name", size: 100, null: false)
definition.text("description")
definition.decimal("price", precision: 10, scale: 2)
definition.boolean("active", default: true)
definition.timestamps

# Generate SQL
puts definition.to_sql
```

## Available Column Types

Ralph supports a wide range of types that map to appropriate SQL types across backends.

### Basic Types

| Method      | SQLite Type | PostgreSQL Type | Description                           |
| :---------- | :---------- | :-------------- | :------------------------------------ |
| `string`    | `VARCHAR`   | `VARCHAR`       | Short text (default 255 chars)        |
| `text`      | `TEXT`      | `TEXT`          | Long text                             |
| `integer`   | `INTEGER`   | `INTEGER`       | Standard integer                      |
| `bigint`    | `BIGINT`    | `BIGINT`        | Large integer                         |
| `float`     | `REAL`      | `DOUBLE PRECISION` | Floating point number              |
| `decimal`   | `DECIMAL`   | `DECIMAL`       | Fixed-point number (use for currency) |
| `boolean`   | `BOOLEAN`   | `BOOLEAN`       | True or False                         |
| `date`      | `DATE`      | `DATE`          | Date (YYYY-MM-DD)                     |
| `timestamp` | `TIMESTAMP` | `TIMESTAMP`     | Date and time                         |
| `datetime`  | `DATETIME`  | `TIMESTAMP`     | Alias for timestamp                   |

### Advanced Types

Ralph provides specialized types with automatic backend adaptation:

| Method            | SQLite Type | PostgreSQL Type | Description                    |
| :---------------- | :---------- | :-------------- | :----------------------------- |
| `json`            | `TEXT`      | `JSON`          | JSON document (text-based)     |
| `jsonb`           | `TEXT`      | `JSONB`         | JSON document (binary, indexed) |
| `uuid`            | `CHAR(36)`  | `UUID`          | Universally unique identifier  |
| `enum`            | `VARCHAR`   | `ENUM` or `VARCHAR` | Enumerated values          |
| `soft_deletes`    | `DATETIME`  | `TIMESTAMP`     | Adds `deleted_at` column       |
| `string_array`    | `TEXT`      | `TEXT[]`        | Array of strings               |
| `integer_array`   | `TEXT`      | `INTEGER[]`     | Array of integers              |
| `bigint_array`    | `TEXT`      | `BIGINT[]`      | Array of large integers        |
| `float_array`     | `TEXT`      | `DOUBLE PRECISION[]` | Array of floats           |
| `boolean_array`   | `TEXT`      | `BOOLEAN[]`     | Array of booleans              |
| `uuid_array`      | `TEXT`      | `UUID[]`        | Array of UUIDs                 |
| `array`           | `TEXT`      | Varies          | Generic array (specify element_type) |

## Column Options

All column methods accept an optional set of options:

- `null: Bool` - Set to `false` to add a `NOT NULL` constraint.
- `default: Value` - Set a default value for the column.
- `primary: Bool` - Mark the column as a primary key.
- `size: Int32` - Specify the size for `string` (VARCHAR) columns.
- `precision: Int32` and `scale: Int32` - Specify dimensions for `decimal` columns.

## Dialect Support

The Schema module supports multiple database dialects:

```crystal
# SQLite dialect
sqlite_dialect = Ralph::Migrations::Schema::Dialect::Sqlite.new
definition = Ralph::Migrations::Schema::TableDefinition.new("users", sqlite_dialect)
definition.primary_key
puts definition.to_sql
# => CREATE TABLE IF NOT EXISTS "users" ("id" INTEGER PRIMARY KEY AUTOINCREMENT)

# PostgreSQL dialect  
pg_dialect = Ralph::Migrations::Schema::Dialect::Postgres.new
definition = Ralph::Migrations::Schema::TableDefinition.new("users", pg_dialect)
definition.primary_key
puts definition.to_sql
# => CREATE TABLE IF NOT EXISTS "users" ("id" BIGSERIAL PRIMARY KEY)
```

## Primary Key Types

The schema DSL supports various primary key types:

```crystal
# Auto-incrementing integer (default)
t.primary_key                    # INTEGER PRIMARY KEY AUTOINCREMENT (SQLite)
                                 # BIGSERIAL PRIMARY KEY (PostgreSQL)

# UUID primary key
t.uuid_primary_key               # CHAR(36) PRIMARY KEY NOT NULL (SQLite)
                                 # UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid() (PostgreSQL)

# String primary key
t.string_primary_key("key")      # TEXT PRIMARY KEY NOT NULL

# Typed primary key
t.primary_key("id", :uuid)       # Explicit type selection
```

## Index Definitions

The schema module can describe various index types:

```crystal
# Basic index
t.index("email", unique: true)

# PostgreSQL-specific indexes
t.gin_index("metadata")           # GIN index for JSONB/arrays
t.gist_index("coordinates")       # GiST index for geometric data
t.full_text_index("content")      # Full-text search index
t.partial_index("email", condition: "active = true")
t.expression_index("lower(email)", name: "idx_email_lower")
```

## Foreign Key Definitions

```crystal
# Reference column with foreign key
t.reference("user", null: false, on_delete: :cascade)

# Explicit foreign key
t.foreign_key("users", on_delete: :cascade)

# Polymorphic reference
t.reference("commentable", polymorphic: true)
```

## Using Schema for SQL Generation

While migrations should be written in plain SQL, you can use the schema DSL to help generate SQL:

```crystal
# Generate CREATE TABLE SQL
definition = Ralph::Migrations::Schema::TableDefinition.new("users")
definition.primary_key
definition.string("email", null: false)
definition.timestamps

sql = definition.to_sql
puts sql
# CREATE TABLE IF NOT EXISTS "users" (
#     "id" BIGSERIAL PRIMARY KEY,
#     "email" VARCHAR(255) NOT NULL,
#     "created_at" TIMESTAMP,
#     "updated_at" TIMESTAMP
# )
```

Then copy this SQL into your migration file:

```sql
-- +migrate Up
CREATE TABLE IF NOT EXISTS "users" (
    "id" BIGSERIAL PRIMARY KEY,
    "email" VARCHAR(255) NOT NULL,
    "created_at" TIMESTAMP,
    "updated_at" TIMESTAMP
);

-- +migrate Down
DROP TABLE IF EXISTS "users";
```

## PostgreSQL-Specific Indexes

For detailed documentation on PostgreSQL-specific indexes (GIN, GiST, Full-Text, Partial, Expression), see [PostgreSQL-Specific Indexes](postgres-indexes.md).

## See Also

- [Introduction](introduction.md) - Creating and running SQL migrations
- [PostgreSQL Indexes](postgres-indexes.md) - Advanced PostgreSQL index types
- [Types Documentation](../models/types.md) - Model type definitions

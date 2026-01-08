# Schema Builder

The Schema Builder provides a fluent DSL for defining and modifying your database tables within migrations.

## Creating Tables

Use `create_table` to define a new table. Inside the block, you define the columns and indexes.

```crystal compile=false
create_table :products do |t|
  t.primary_key             # Adds 'id' INTEGER PRIMARY KEY
  t.string :name, size: 100, null: false
  t.text :description
  t.decimal :price, precision: 10, scale: 2
  t.boolean :active, default: true
  t.timestamps              # Adds 'created_at' and 'updated_at'
  t.soft_deletes            # Adds 'deleted_at'

  t.index :name             # Adds an index on the 'name' column
end
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

**Note**: SQLite stores JSON and arrays as TEXT with validation constraints. PostgreSQL uses native types for better performance and indexing.

## Column Options

All column methods accept an optional set of options:

- `null: Bool` - Set to `false` to add a `NOT NULL` constraint.
- `default: Value` - Set a default value for the column.
- `primary: Bool` - Mark the column as a primary key.
- `size: Int32` - Specify the size for `string` (VARCHAR) columns.
- `precision: Int32` and `scale: Int32` - Specify dimensions for `decimal` columns.

```crystal compile=false
t.string :status, null: false, default: "draft", size: 50
```

## Associations and References

Use `reference` (or its aliases `references` and `belongs_to`) to create foreign key columns.

```crystal compile=false
create_table :comments do |t|
  t.references :user        # Adds 'user_id' BIGINT and an index
  t.references :post        # Adds 'post_id' BIGINT and an index
end

# Polymorphic associations
create_table :attachments do |t|
  t.references :attachable, polymorphic: true
  # Adds 'attachable_id' BIGINT, 'attachable_type' VARCHAR, and an index
end
```

## Modifying Existing Tables

You can also modify tables after they've been created.

### Adding Columns

```crystal compile=false
add_column :users, :bio, :text
add_column :users, :points, :integer, default: 0
```

### Removing Columns

```crystal compile=false
remove_column :users, :bio
```

_Note: In SQLite, removing a column is supported in modern versions, but older ones may require recreating the table._

### Renaming Columns

```crystal compile=false
rename_column :users, :points, :karma
```

### References

```crystal compile=false
add_reference :posts, :author             # Adds author_id
remove_reference :posts, :author          # Removes author_id
```

## Indexes

Indexes improve query performance but can slow down writes. Use them for columns that appear frequently in `WHERE` clauses.

### Creating Indexes

```crystal compile=false
# Inside create_table
t.index :email, unique: true

# Standalone
add_index :users, :last_name
add_index :users, :email, unique: true, name: "idx_user_emails"
```

### Removing Indexes

```crystal compile=false
remove_index :users, :last_name
remove_index :users, name: "idx_user_emails"
```

## Advanced Type Examples

### JSON/JSONB Columns

Use JSON for storing structured data that doesn't fit a fixed schema:

```crystal compile=false
create_table :posts do |t|
  t.primary_key
  t.string :title, null: false
  
  # Standard JSON (text storage)
  t.json :metadata, default: "{}"
  
  # JSONB (binary, better for queries - PostgreSQL optimized)
  t.jsonb :settings, default: "{}"
  
  t.timestamps
end

# PostgreSQL: Can add GIN index for fast JSON queries
add_index :posts, :settings, using: :gin  # PostgreSQL only
```

### UUID Columns

UUIDs are ideal for distributed systems and API keys:

```crystal compile=false
create_table :users do |t|
  # UUID primary key
  t.uuid :id, primary: true
  
  # UUID for API authentication
  t.uuid :api_key, null: false
  
  t.string :email, null: false
  t.timestamps
  
  t.index :api_key, unique: true
end
```

### Enum Columns

Store enumerated values with database-level validation:

```crystal compile=false
create_table :orders do |t|
  t.primary_key
  
  # String storage (default) - stores "pending", "processing", etc.
  t.enum :status, values: ["pending", "processing", "shipped", "delivered"]
  
  # Integer storage - stores 0, 1, 2
  t.enum :priority, values: [0, 1, 2], storage: :integer
  
  # Native ENUM (PostgreSQL only)
  t.enum :payment_method, values: ["card", "paypal", "crypto"], storage: :native
  
  t.timestamps
end
```

### Array Columns

Store homogeneous arrays with element type safety:

```crystal compile=false
create_table :articles do |t|
  t.primary_key
  t.string :title, null: false
  
  # String arrays
  t.string_array :tags, default: "[]"
  t.string_array :authors
  
  # Integer arrays
  t.integer_array :category_ids
  
  # Boolean arrays
  t.boolean_array :feature_flags, default: "[]"
  
  # Custom element type
  t.array :custom_data, element_type: :text
  
  t.timestamps
end

# PostgreSQL: GIN index for fast containment queries
add_index :articles, :tags, using: :gin  # PostgreSQL only
```

## Comprehensive Example

```crystal
class CreateStoreSchema_20240101120000 < Ralph::Migrations::Migration
  migration_version 20240101120000

  def up : Nil
    create_table :categories do |t|
      t.primary_key
      t.string :slug, null: false
      t.string :name, null: false
      t.timestamps
      t.index :slug, unique: true
    end

    create_table :products do |t|
      t.primary_key
      t.references :category
      t.string :sku, null: false
      t.string :title, null: false
      t.text :description
      t.decimal :price, precision: 12, scale: 2, default: 0.0
      t.integer :stock_quantity, default: 0
      t.boolean :published, default: false
      
      # Advanced types
      t.string_array :tags, default: "[]"
      t.jsonb :specifications, default: "{}"
      t.enum :status, values: ["draft", "active", "archived"]
      
      t.timestamps

      t.index :sku, unique: true
      t.index :published
    end
  end

  def down : Nil
    drop_table :products
    drop_table :categories
  end
end
```

## Advanced Type Migration Methods

### JSON Columns

```crystal compile=false
# Add JSON column
add_column :posts, :metadata, :json, default: "{}"

# Add JSONB column (PostgreSQL optimized)
add_column :posts, :settings, :jsonb

# With null constraint
add_column :articles, :config, :jsonb, null: false, default: "{}"
```

### UUID Columns

```crystal compile=false
# Add UUID column
add_column :users, :api_key, :uuid

# Add with uniqueness
add_column :sessions, :session_id, :uuid
add_index :sessions, :session_id, unique: true

# UUID primary key (best done in create_table)
create_table :distributed_records do |t|
  t.uuid :id, primary: true
  t.string :data
end
```

### Enum Columns

```crystal compile=false
# Add enum with string storage
add_column :users, :role, :enum, values: ["user", "admin", "moderator"]

# Add enum with integer storage
add_column :tasks, :priority, :enum, values: [1, 2, 3], storage: :integer

# Add with default value
add_column :posts, :visibility, :enum, 
  values: ["public", "private", "unlisted"],
  default: "public"
```

### Array Columns

```crystal compile=false
# Add string array
add_column :posts, :tags, :string_array, default: "[]"

# Add integer array
add_column :records, :related_ids, :integer_array

# Add with null constraint
add_column :users, :preferences, :string_array, null: false, default: "[]"

# Generic array with element type
add_column :data, :values, :array, element_type: :float
```

## Backend-Specific Considerations

### PostgreSQL

PostgreSQL provides native support for advanced types with full indexing:

```crystal compile=false
create_table :analytics do |t|
  t.primary_key
  t.jsonb :event_data
  t.uuid :session_id
  t.string_array :tags
  t.timestamps
end

# GIN indexes for fast JSON and array queries
add_index :analytics, :event_data, using: :gin
add_index :analytics, :tags, using: :gin

# B-tree index for UUID
add_index :analytics, :session_id
```

### SQLite

SQLite stores advanced types as TEXT with validation constraints:

```crystal compile=false
# Same migration works on SQLite
create_table :analytics do |t|
  t.primary_key
  t.jsonb :event_data      # Stored as TEXT with json_valid() CHECK
  t.uuid :session_id       # Stored as CHAR(36) with format CHECK
  t.string_array :tags     # Stored as TEXT with JSON array CHECK
  t.timestamps
end

# Standard indexes (no GIN equivalent)
add_index :analytics, :session_id
```

The same migration code works on both backends - Ralph automatically adapts the SQL generation.

## PostgreSQL-Specific Indexes

PostgreSQL provides several specialized index types for different use cases. These are PostgreSQL-only and will raise an error on SQLite.

### GIN Indexes

General Inverted Indexes are excellent for JSONB, array, and full-text search columns.

#### In Table Definition

```crystal compile=false
create_table :posts do |t|
  t.primary_key
  t.string :title
  t.text :content
  
  # Index JSONB metadata for fast containment queries
  t.gin_index("metadata", fastupdate: true)
  
  # Index arrays for fast array operations
  t.gin_index("tags", name: "idx_posts_tags_gin")
  
  t.timestamps
end
```

#### Standalone Index Creation

```crystal compile=false
# Add GIN index to existing table
add_gin_index :posts, :metadata

# Remove GIN index
remove_gin_index :posts, :metadata
```

**When to use**: JSONB queries with containment operators, array containment, overlaps, and full-text search.

### GiST Indexes

Generalized Search Tree indexes support range types, geometric types, and specialized queries.

#### In Table Definition

```crystal compile=false
create_table :places do |t|
  t.primary_key
  t.string :name
  
  # GiST index for geometric data
  t.gist_index("location")
  
  # Multi-column GiST for coordinate pairs
  t.gist_index(["latitude", "longitude"], name: "idx_coords_gist")
  
  t.timestamps
end
```

#### Standalone Operations

```crystal compile=false
# Add GiST index
add_gist_index :places, :location

# Remove GiST index
remove_gist_index :places, :location
```

**When to use**: Geometric/range type queries, nearest-neighbor searches, or overlap detection.

### Full-Text Search Indexes

Dedicated indexes for PostgreSQL full-text search operations.

#### Single Column

```crystal compile=false
create_table :articles do |t|
  t.primary_key
  t.string :title
  t.text :content
  
  # Full-text search on content with English tokenization
  t.full_text_index("content", config: "english")
  
  t.timestamps
end
```

#### Multi-Column

```crystal compile=false
create_table :documents do |t|
  t.primary_key
  t.string :title
  t.text :body
  t.text :summary
  
  # Search across multiple columns
  t.full_text_index(["title", "body"], config: "english", name: "idx_document_search")
  
  t.timestamps
end
```

#### Standalone Operations

```crystal compile=false
# Add full-text index
add_full_text_index :articles, :content, config: "english"

# Add multi-column full-text index
add_full_text_index :articles, [:title, :content], config: "english"

# Remove full-text index
remove_full_text_index :articles, :content
```

**When to use**: Querying with `where_search`, `where_phrase_search`, and `where_websearch` methods for optimal performance.

**Language Configurations**: Common configs include 'english', 'simple', 'french', 'german', 'spanish', 'russian', etc.

### Partial Indexes

Conditional indexes that only index rows matching a condition, reducing index size and improving performance for filtered queries.

#### In Table Definition

```crystal compile=false
create_table :users do |t|
  t.primary_key
  t.string :email
  t.boolean :active, default: true
  t.soft_deletes
  
  # Only index active users (smaller, faster index)
  t.partial_index("email", condition: "active = true", unique: true)
  
  # Only index non-deleted records
  t.partial_index("deleted_at", condition: "deleted_at IS NULL")
  
  t.timestamps
end
```

#### Standalone Operations

```crystal compile=false
# Add partial index
add_partial_index :users, :email, condition: "active = true", unique: true

# Add partial unique index for deleted records
add_partial_index :posts, :slug, condition: "deleted_at IS NULL", unique: true

# Remove partial index
remove_partial_index :users, :email
```

**When to use**: When most queries filter on specific conditions (soft deletes, status flags, active records). Reduces index size and maintenance overhead.

### Expression Indexes

Indexes on computed expressions rather than raw columns, useful for case-insensitive lookups or JSON extraction.

#### In Table Definition

```crystal compile=false
create_table :users do |t|
  t.primary_key
  t.string :email
  
  # Case-insensitive email lookup using lower()
  t.expression_index("lower(email)", name: "idx_email_lower", unique: true)
  
  # Index JSON field extraction
  t.expression_index("(data->>'category')", method: "btree")
  
  t.timestamps
end
```

#### Standalone Operations

```crystal compile=false
# Add expression index for case-insensitive search
add_expression_index :users, "lower(email)", unique: true

# Add expression index on JSON extraction
add_expression_index :posts, "(metadata->>'status')", unique: false

# Remove expression index
remove_expression_index :users, name: "idx_email_lower"
```

**When to use**: 
- Case-insensitive lookups (use `lower()` or `upper()`)
- Extracting and indexing JSON fields
- Complex computed values used in WHERE clauses
- Indexes on function results

### Index Strategy Summary

| Index Type | Best For | Reduces | Example |
|------------|----------|---------|---------|
| **GIN** | JSONB, arrays, full-text | Containment queries | `tags @> ARRAY['active']` |
| **GiST** | Ranges, geometry, near searches | Range overlaps | Location-based queries |
| **Full-Text** | Text search queries | Full-text patterns | `where_search("content", "...")` |
| **Partial** | Filtered data (soft deletes, status) | Index size | "active = true" only |
| **Expression** | Computed/transformed lookups | Function calls | `lower(email) = ...` |

### PostgreSQL Index Examples

```crystal
class CreateBlogSchema_20240115100000 < Ralph::Migrations::Migration
  migration_version 20240115100000

  def up : Nil
    create_table :articles do |t|
      t.primary_key
      t.string :title, null: false
      t.text :content
      t.string_array :tags, default: "[]"
      t.jsonb :metadata, default: "{}"
      t.boolean :published, default: false
      t.soft_deletes
      t.timestamps
      
      # Full-text search on content
      t.full_text_index("content", config: "english")
      
      # Case-insensitive email lookup
      t.expression_index("lower(title)", name: "idx_title_lower")
      
      # Only active published articles
      t.partial_index("published", condition: "deleted_at IS NULL", unique: false)
      
      # Fast array operations
      t.gin_index("tags")
      
      # Fast JSONB queries
      t.gin_index("metadata")
    end
  end

  def down : Nil
    drop_table :articles
  end
end
```

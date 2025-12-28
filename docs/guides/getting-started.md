# Getting Started

This guide will walk you through the process of setting up Ralph in your Crystal project and performing your first database operations.

## Installation

First, add Ralph to your `shard.yml` dependencies:

```yaml
dependencies:
  ralph:
    github: watzon/ralph
```

Install the dependencies using the Crystal shards tool:

```bash
shards install
```

## Configuration

Ralph needs to know how to connect to your database. Configure it at your application's entry point (usually `src/your_app.cr`):

### SQLite

```crystal
require "ralph"
require "ralph/backends/sqlite"

Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
end
```

### PostgreSQL

```crystal
require "ralph"
require "ralph/backends/postgres"

Ralph.configure do |config|
  config.database = Ralph::Database::PostgresBackend.new("postgres://user:pass@localhost:5432/my_db")
end
```

## Defining Your First Model

Models in Ralph are Crystal classes that inherit from `Ralph::Model`. Use the `table` macro to specify the database table and the `column` macro to define your fields.

```crystal
class Post < Ralph::Model
  table :posts

  column id : Int64, primary: true
  column title : String
  column content : String?
  column published : Bool = false
  column created_at : Time?
  column updated_at : Time?
end
```

### Supported Types

Ralph maps Crystal types to their SQL equivalents:

- `String` → `TEXT` / `VARCHAR`
- `Int32`, `Int64` → `INTEGER` / `BIGINT` / `BIGSERIAL`
- `Float64` → `REAL` / `DOUBLE PRECISION`
- `Bool` → `INTEGER (0/1)` / `BOOLEAN`
- `Time` → `DATETIME` / `TIMESTAMP`

For PostgreSQL, Ralph also supports:
- `UUID`
- `JSONB`
- `JSON`

## Basic CRUD Operations

### Creating Records

You can instantiate a model and save it, or use the `.create` convenience method.

```crystal
# Option 1: Instantiate and save
post = Post.new(title: "Hello Ralph", content: "My first post")
post.save # Returns true if successful

# Option 2: Create immediately
post = Post.create(title: "Quick Start", published: true)
```

### Finding Records

Find a record by its primary key or retrieve the first match.

```crystal
# Find by ID
post = Post.find(1)

# Find first matching record
post = Post.find_by(title: "Hello Ralph")
```

### Updating Records

Modify attributes and call `save`. Ralph tracks "dirty" attributes and only updates what has changed.

```crystal
post = Post.find(1)
post.title = "Updated Title"
post.save
```

### Deleting Records

Call `destroy` to remove a record from the database.

```crystal
post = Post.find(1)
post.destroy
```

## Introduction to the Query Builder

Ralph's query builder is **immutable** and **fluent**. Every method call returns a new builder instance, allowing you to compose queries safely.

```crystal
# Simple filtering
active_posts = Post.query { |q|
  q.where("published = ?", true)
   .order("created_at", :desc)
   .limit(5)
}

# Advanced queries (CTEs, Window functions)
# Ralph supports complex SQL features while maintaining type safety
posts_with_rank = Post.query { |q|
  q.window("row_number()", order_by: "created_at DESC", as: "pos")
}
```

## Migration Quickstart

Migrations are the recommended way to manage your database schema.

### 1. Generate a Migration

Use the Ralph CLI to create a new migration file:

```bash
ralph g:migration CreatePosts
```

### 2. Define the Schema

Edit the generated file in `db/migrations/`:

```crystal
class CreatePosts_20240107120000 < Ralph::Migrations::Migration
  def up : Nil
    create_table :posts do |t|
      t.primary_key
      t.string :title, size: 255
      t.text :content
      t.bool :published, default: false
      t.timestamps
    end
  end

  def down : Nil
    drop_table :posts
  end
end
```

### 3. Run the Migration

Apply the changes to your database:

```bash
ralph db:migrate
```

## CLI Commands Overview

The `ralph` CLI is your companion for database management:

| Command        | Description                             |
| :------------- | :-------------------------------------- |
| `db:setup`     | Create database and run all migrations  |
| `db:migrate`   | Run pending migrations                  |
| `db:rollback`  | Roll back the last migration            |
| `db:status`    | Show the status of all migrations       |
| `g:model Name` | Generate a model and its migration      |
| `db:seed`      | Populate your database with sample data |

---

## Next Steps

- Dive deeper into [**Model Definitions**](models.md)
- Learn about [**Associations**](associations.md) (belongs_to, has_many)
- Explore the full power of the [**Query Builder**](query-builder.md)

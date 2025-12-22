# Ralph

An Active Record-style ORM for Crystal with a focus on developer experience, type safety, and explicit over implicit behavior.

**[📖 Full Documentation](https://watzon.github.io/ralph/)** | [Getting Started](https://watzon.github.io/ralph/guides/getting-started/) | [API Reference](https://watzon.github.io/ralph/api/)

## Features

- **Active Record Pattern** - Simple, intuitive API for database operations
- **Type-Safe Query Builder** - Immutable, fluent interface with advanced SQL support
- **Associations** - belongs_to, has_one, has_many with polymorphic support
- **Validations** - Built-in validation macros for data integrity
- **Callbacks** - Lifecycle hooks for model events
- **Migration System** - Version-controlled schema changes with rollback support
- **CLI Tool** - Command-line interface for database operations and code generation
- **Pluggable Backends** - Currently SQLite with more planned
- **Explicit Over Implicit** - No lazy loading by default, predictable behavior

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  ralph:
    github: watzon/ralph
```

Run `shards install`

## Quick Start

### Configuration

```crystal
require "ralph"

Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
end
```

### Defining Models

```crystal
class User < Ralph::Model
  table :users

  column id : Int64, primary: true
  column name : String
  column email : String
  column age : Int32?
  column created_at : Time?
end
```

### CRUD Operations

```crystal
# Create
user = User.new(name: "Alice", email: "alice@example.com")
user.save

# Or use create
user = User.create(name: "Bob", email: "bob@example.com")

# Read
user = User.find(1)

# Query
users = User.query { |q|
  q.where("age > ?", 18)
   .order("name", :asc)
   .limit(10)
}

# Update
user.name = "Alice Updated"
user.save

# Delete
user.destroy
```

### Query Builder

The query builder provides a fluent interface for building queries:

```crystal
User.query { |q|
  q.where("name = ?", "Alice")
   .order("created_at", :desc)
   .limit(5)
}
```

### Migrations

Create a migration file:

```bash
ralph g:migration CreateUsersTable
```

Run migrations:

```bash
ralph db:migrate
```

Rollback:

```bash
ralph db:rollback
```

Check status:

```bash
ralph db:status
```

### Migration Example

```crystal
require "ralph"

class CreateUsersTable_20240101120000 < Ralph::Migrations::Migration
  migration_version 20240101120000

  def up : Nil
    create_table :users do |t|
      t.primary_key
      t.string :name, size: 255
      t.string :email, size: 255
      t.integer :age
      t.timestamps
    end

    add_index :users, :email, unique: true
  end

  def down : Nil
    drop_table :users
  end
end

Ralph::Migrations::Migrator.register(CreateUsersTable_20240101120000)
```

## Documentation

For comprehensive documentation, visit **[https://watzon.github.io/ralph/](https://watzon.github.io/ralph/)**

### Guides
- [Getting Started](https://watzon.github.io/ralph/guides/getting-started/) - Installation and quick start
- [Configuration](https://watzon.github.io/ralph/guides/configuration/) - Database setup and settings

### Models
- [Introduction](https://watzon.github.io/ralph/models/introduction/) - Model basics and column definitions
- [CRUD Operations](https://watzon.github.io/ralph/models/crud-operations/) - Create, read, update, delete
- [Associations](https://watzon.github.io/ralph/models/associations/) - Relationships between models
- [Validations](https://watzon.github.io/ralph/models/validations/) - Data validation
- [Callbacks](https://watzon.github.io/ralph/models/callbacks/) - Lifecycle hooks
- [Scopes](https://watzon.github.io/ralph/models/scopes/) - Reusable queries

### Query Builder
- [Introduction](https://watzon.github.io/ralph/query-builder/introduction/) - Basic querying
- [Advanced](https://watzon.github.io/ralph/query-builder/advanced/) - CTEs, window functions, set operations

### Migrations
- [Introduction](https://watzon.github.io/ralph/migrations/introduction/) - Migration basics
- [Schema Builder](https://watzon.github.io/ralph/migrations/schema-builder/) - Table and column definitions

### CLI
- [Commands](https://watzon.github.io/ralph/cli/commands/) - All CLI commands and usage

### API Reference
- [API Documentation](https://watzon.github.io/ralph/api/) - Complete API reference

## CLI Commands

```bash
ralph db:migrate                   # Run pending migrations
ralph db:rollback                  # Roll back the last migration
ralph db:status                    # Show migration status
ralph g:migration NAME             # Create a new migration
ralph --help                       # Show all commands
```

## Development

Run tests:

```bash
crystal spec
```

Build the CLI:

```bash
crystal build src/bin/ralph.cr -o bin/ralph
```

Generate API documentation:

```bash
crystal run scripts/generate_api_docs.cr
```

## Contributing

1. Fork it (<https://github.com/watzon/ralph/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Chris Watson](https://github.com/watzon) - creator and maintainer

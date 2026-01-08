# Ralph

[![Crystal](https://img.shields.io/badge/crystal-%3E%3D1.18.2-black)](https://crystal-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![standard-readme compliant](https://img.shields.io/badge/readme%20style-standard-brightgreen.svg)](https://github.com/RichardLitt/standard-readme)

<div align="center">
  <img src="./docs/assets/images/ralph.png" alt="Ralph Logo" width="200">
</div>

An Active Record-style ORM for Crystal with a focus on developer experience, type safety, and explicit behavior.

Ralph provides a familiar Active Record API with models, associations, validations, callbacks, and migrations. It supports SQLite and PostgreSQL backends with a type system that handles cross-database compatibility automatically.

## Table of Contents

- [Install](#install)
- [Usage](#usage)
- [API](#api)
- [Maintainers](#maintainers)
- [Contributing](#contributing)
- [License](#license)

## Install

Add Ralph and your preferred database driver to `shard.yml`:

```yaml
dependencies:
  ralph:
    github: watzon/ralph

  # SQLite
  sqlite3:
    github: crystal-lang/crystal-sqlite3

  # Or PostgreSQL
  pg:
    github: will/crystal-pg
```

Then run:

```sh
shards install
```

## Usage

```crystal
require "ralph"
require "ralph/backends/sqlite"

# Configure database
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
end

# Define a model
class User < Ralph::Model
  table :users

  column id : Int64, primary: true
  column name : String
  column email : String

  validates_presence_of :name
  has_many :posts
end

# CRUD operations
user = User.create(name: "Alice", email: "alice@example.com")
user = User.find(1)
user.name = "Bob"
user.save
user.destroy

# Query builder
User.query { |q| q.where("name = ?", "Alice").order("created_at", :desc) }
```

For comprehensive documentation including associations, validations, callbacks, migrations, and advanced query builder features, visit **[ralph-docs.wtz.nz](https://ralph-docs.wtz.nz)**.

### CLI

Ralph includes a CLI for database management. Create a `ralph.cr` file in your project (see [CLI docs](https://ralph-docs.wtz.nz/cli/customization/)), then:

```sh
# Initial setup
./ralph.cr db:create      # Create the database
./ralph.cr db:migrate     # Run pending migrations
./ralph.cr db:seed        # Seed with initial data (optional)

# Start your application
crystal run src/app.cr
```

Other useful commands:

```sh
./ralph.cr db:rollback    # Roll back last migration
./ralph.cr db:status      # Show migration status
./ralph.cr g:model User   # Generate model
./ralph.cr g:migration X  # Generate migration
```

## API

See the [API Reference](https://ralph-docs.wtz.nz/api/) for complete documentation.

## Maintainers

[@watzon](https://github.com/watzon)

## Contributing

PRs accepted. Please open an issue first to discuss major changes.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a Pull Request

## License

MIT © Chris Watson

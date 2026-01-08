# PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-07
**Commit:** b59ecb1
**Branch:** main

## OVERVIEW

Active Record-style ORM for Crystal. Dual backend: SQLite + PostgreSQL. Heavy macro usage for DSL (column, validates_*, belongs_to, has_many). Query builder generates parameterized SQL. Type system handles cross-backend compatibility.

**GREENFIELD PROJECT**: No backward compatibility requirements. Feel free to make breaking changes when they improve the design.

## STRUCTURE

```
ralph/
├── src/
│   ├── ralph.cr              # Entry point, module definition, requires
│   ├── bin/ralph.cr          # CLI binary entry
│   └── ralph/
│       ├── model.cr          # Base model class (1906 lines) - CORE
│       ├── associations.cr   # belongs_to/has_many/has_one macros (1537 lines)
│       ├── validations.cr    # validates_* macros
│       ├── callbacks.cr      # @[BeforeSave] annotations
│       ├── transactions.cr   # Transaction support with nested transactions
│       ├── eager_loading.cr  # Preloading system (532 lines)
│       ├── database.cr       # Backend interface
│       ├── settings.cr       # Configuration
│       ├── query/
│       │   └── builder.cr    # Query DSL (1821 lines) - CTEs, window functions, set ops
│       ├── migrations/
│       │   ├── migration.cr  # Base migration class with schema DSL
│       │   ├── migrator.cr   # Run/rollback logic, registry
│       │   ├── schema.cr     # Table/column/index definitions (567 lines)
│       │   └── dialect.cr    # Backend-specific SQL generation
│       ├── types/
│       │   ├── base.cr       # Three-phase type system (cast/dump/load)
│       │   ├── registry.cr   # Backend-specific type registration
│       │   ├── array.cr      # JSON (SQLite) / native (PostgreSQL)
│       │   ├── enum.cr       # String/integer/native storage
│       │   ├── uuid.cr       # CHAR(36) / native UUID
│       │   └── json.cr       # TEXT / JSONB
│       ├── cli/
│       │   ├── runner.cr     # Command dispatch (509 lines)
│       │   └── generators/   # Model/scaffold templates
│       └── backends/
│           ├── sqlite.cr     # SQLite implementation
│           └── postgres.cr   # PostgreSQL implementation
├── spec/
│   ├── spec_helper.cr        # Base helper
│   ├── postgres_spec_helper.cr
│   └── ralph/
│       ├── test_helper.cr    # Database setup/cleanup utilities
│       ├── unit/             # Query builder, migrations, clauses
│       └── integration/      # Full database operations
├── examples/website/         # Kemal-based example app
├── docs/                     # Documentation markdown
└── justfile                  # Build commands (use `just`)
```

## WHERE TO LOOK

| Task                   | Location                            | Notes                                  |
| ---------------------- | ----------------------------------- | -------------------------------------- |
| Add model feature      | `src/ralph/model.cr`                | Use `macro inherited` pattern          |
| Add validation         | `src/ralph/validations.cr`          | Follow `validates_*` macro pattern     |
| Add association option | `src/ralph/associations.cr`         | Modify belongs_to/has_many/has_one     |
| Query builder change   | `src/ralph/query/builder.cr`        | Clause classes + Builder methods       |
| Migration feature      | `src/ralph/migrations/migration.cr` | Schema DSL methods                     |
| Add custom type        | `src/ralph/types/`                  | Extend BaseType, register in registry  |
| Backend-specific SQL   | `src/ralph/migrations/dialect.cr`   | Type mapping per backend               |
| CLI command            | `src/ralph/cli/runner.cr`           | Add case in dispatch                   |
| New generator          | `src/ralph/cli/generators/`         | Follow model_generator pattern         |
| Eager loading          | `src/ralph/eager_loading.cr`        | Preload strategies                     |

## CODE MAP

### Core Inheritance

```
Ralph::Model (abstract)
├── includes Ralph::Validations
├── includes Ralph::Callbacks
├── includes Ralph::Associations
├── includes Ralph::Transactions
└── macro inherited → generates save/destroy/valid? methods
```

### Key Macros (model.cr)

| Macro                          | Purpose           | Generates                      |
| ------------------------------ | ----------------- | ------------------------------ |
| `table :name`                  | Set table name    | `@@table_name`                 |
| `column name, Type`            | Define column     | getter/setter, metadata        |
| `scope :name, ->(q){}`         | Named query scope | Class method returning Builder |
| `from_result_set(rs)`          | Hydrate from DB   | Instance with all columns      |
| `__get_by_key_name(name)`      | Dynamic getter    | Case statement by attr name    |
| `__set_by_key_name(name, val)` | Dynamic setter    | Type-coerced assignment        |

### Association Macros (associations.cr)

| Macro              | Creates                                                                   |
| ------------------ | ------------------------------------------------------------------------- |
| `belongs_to :user` | `user_id` column, `user` getter/setter, `build_user`, `create_user`       |
| `has_one :profile` | `profile` getter/setter, `build_profile`, `create_profile`                |
| `has_many :posts`  | `posts` getter, `build_post`, `create_post`, `posts_any?`, `posts_empty?` |

Options: `class_name:`, `foreign_key:`, `primary_key:`, `polymorphic:`, `through:`, `dependent:`, `counter_cache:`, `touch:`

### Query Builder (query/builder.cr)

| Method                                     | SQL Generated        |
| ------------------------------------------ | -------------------- |
| `.where("x = ?", val)`                     | `WHERE x = $1`       |
| `.join(table, on, :left)`                  | `LEFT JOIN`          |
| `.group("col")`                            | `GROUP BY`           |
| `.having("COUNT(*) > ?", n)`               | `HAVING`             |
| `.with_cte(name, subquery)`                | `WITH name AS (...)` |
| `.exists(subquery)`                        | `WHERE EXISTS (...)` |
| `.union(other)` / `.intersect` / `.except` | Set operations       |
| `.window("ROW_NUMBER()")`                  | Window functions     |

### Type System (types/)

Three-phase transformation: `cast` (external→internal) → `dump` (internal→DB) → `load` (DB→internal)

| Type  | SQLite Storage        | PostgreSQL Storage       |
| ----- | --------------------- | ------------------------ |
| Array | JSON text             | Native array             |
| Enum  | String/Integer        | Native ENUM or String    |
| UUID  | CHAR(36)              | Native UUID              |
| JSON  | TEXT + json_valid()   | JSONB                    |

### Validation Macros (validations.cr)

```crystal
validates_presence_of :name
validates_length_of :name, min: 3, max: 50
validates_format_of :email, pattern: /@/
validates_uniqueness_of :email
validates_inclusion_of :status, allow: ["draft", "published"]
validates_numericality_of :age
```

### Callback Annotations (callbacks.cr)

```crystal
@[BeforeValidation]
@[AfterValidation]
@[BeforeSave]
@[AfterSave]
@[BeforeCreate]
@[AfterCreate]
@[BeforeUpdate]
@[AfterUpdate]
@[BeforeDestroy]
@[AfterDestroy]
```

Conditional: `@[Ralph::Callbacks::CallbackOptions(if: :method_name, unless: :other_method)]`

## CONVENTIONS

### Crystal-Specific

- No lazy loading by design (explicit > implicit)
- All queries use parameterized placeholders `?` → converted to `$1, $2`
- Model callbacks generated via `macro finished` (compile-time code gen)
- Dirty tracking: `@_changed_attributes`, `@_original_attributes`
- Private ivars prefixed with `_` to avoid column conflicts
- Macro-generated methods prefixed with `_ralph_`

### Naming

- Table names: plural, snake_case (`:users`, `:blog_posts`)
- Foreign keys: `{association}_id` (e.g., `user_id`)
- Polymorphic: `{name}_id` + `{name}_type` columns
- Counter cache: `{child_table}_count` on parent
- Foreign key constraints: `fk_{table}_{column}`
- Indexes: `index_{table}_on_{column}`

### Model Definition Order

```crystal
class User < Ralph::Model
  table :users                    # 1. Table name first

  column id : Int64, primary: true  # 2. Columns
  column name : String

  validates_presence_of :name     # 3. Validations

  belongs_to :organization        # 4. Associations
  has_many :posts

  # 5. Custom methods last
end
```

### Backend Selection

```crystal
# SQLite
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
end

# PostgreSQL
Ralph.configure do |config|
  config.database = Ralph::Database::PostgresBackend.new("postgres://user:pass@host/db")
end
```

## ANTI-PATTERNS (THIS PROJECT)

| Do NOT                                              | Instead                                    |
| --------------------------------------------------- | ------------------------------------------ |
| Use `as` type coercion loosely                      | Use proper `case` type narrowing           |
| Skip `macro finished` in Model subclass             | Always let inherited macro complete        |
| Create non-primary instance vars without `_` prefix | Prefix with `_` (e.g., `@_cache`)          |
| Return `nil` from validation methods                | Return `Nil` (void) or `Bool`              |
| Modify `@wheres` directly                           | Use `where()` builder method               |
| Call `Ralph.database` before `configure`            | Check with `settings.database?` first      |
| Assume backend in type implementations              | Use dialect checks for backend-specific SQL|

## UNIQUE STYLES

### Macro-Generated Methods

Model save/destroy are NOT defined directly - they're generated by `macro finished` inside `macro inherited`. This allows callback annotations to be woven into the method body at compile time.

### Query Builder Immutability

**Builder is IMMUTABLE**: Each method returns a NEW Builder instance. Safe for branching:

```crystal
base = User.query { |q| q.where("active = ?", true) }
admins = base.where("role = ?", "admin")  # base is unchanged
users = base.where("role = ?", "user")    # base is unchanged
```

The block passed to `query { }`, `scoped { }`, and scope lambdas MUST return the modified builder:

```crystal
# CORRECT: Return the result of chaining
User.query { |q| q.where("active = ?", true).order("name") }
scope :active, ->(q : Query::Builder) { q.where("active = ?", true) }

# WRONG: Won't work - block return value is used
User.query { |q| q.where("active = ?", true); q }  # returns old q
```

### Association Metadata Registry

`Ralph::Associations.associations` stores runtime metadata keyed by class name string:

```crystal
Ralph::Associations.associations["User"]["posts"]  # => AssociationMetadata
```

### Type System Architecture

Types use registry pattern with backend-specific registration:
- Global types registered once
- Backend-specific types registered per adapter
- Three-phase transformation ensures cross-backend compatibility

## COMMANDS

```bash
# Development
just install          # Install library deps
just install-cli      # Install CLI deps (includes all backends)
just test             # Run all specs
just test-file FILE   # Run specific spec
just fmt              # Format code
just check            # Type check without codegen

# Building
just build            # Debug CLI binary
just build-release    # Release CLI binary
just run ARGS         # Build and run CLI

# CLI Commands
ralph db:create       # Create database
ralph db:migrate      # Run pending migrations
ralph db:rollback     # Roll back last migration
ralph db:status       # Show migration status
ralph db:reset        # Drop, create, migrate, seed
ralph g:migration N   # Generate migration
ralph g:model N F:T   # Generate model with fields
ralph g:scaffold N    # Generate full CRUD
```

## TESTING

```bash
# Default: SQLite (in-memory, fast)
crystal spec

# PostgreSQL integration
DB_ADAPTER=postgres POSTGRES_URL=postgres://postgres@localhost:5432/ralph_test crystal spec spec/ralph/integration/
```

Test helpers:
- `RalphTestHelper.setup_test_database` - Creates users/posts tables
- `RalphTestHelper.cleanup_test_database` - Truncates/drops for isolation
- `TestSchema` module - Table creation/truncation utilities

## NOTES

- **Complexity centers**: model.cr (1906 lines), builder.cr (1821 lines), associations.cr (1537 lines)
- **Dependencies**: crystal-sqlite3, crystal-pg
- **Polymorphic**: Requires `Ralph::Associations.register_polymorphic_type` at class load
- **No CI configured**: Manual testing via `just test`
- **Crystal version**: >= 1.18.2 required

---
hide:
  - navigation
---

# Roadmap

Ralph is under active development. This roadmap outlines completed features and planned work.

## Current Status

**Version:** 0.1.0 (pre-release)

Ralph is feature-complete for most common ORM use cases. The core is stable and suitable for new projects, though APIs may evolve before 1.0.

## Completed Features

### Core ORM
- **Models** - CRUD operations, dirty tracking, type coercion, default values
- **Validations** - presence, uniqueness, length, format, numericality, inclusion/exclusion, custom
- **Callbacks** - full lifecycle hooks with conditional execution
- **Scopes** - reusable query fragments, chainable, anonymous scopes

### Query Builder
- **Basic** - WHERE, ORDER, LIMIT, OFFSET, SELECT, DISTINCT
- **Aggregates** - COUNT, SUM, AVG, MIN, MAX
- **Joins** - INNER, LEFT, RIGHT, CROSS, FULL OUTER, association-based joins, aliases
- **Advanced** - GROUP BY, HAVING, CTEs, window functions, subqueries, UNION/INTERSECT/EXCEPT
- **Locking** - FOR UPDATE, FOR SHARE, NOWAIT, SKIP LOCKED

### Associations
- **Types** - belongs_to, has_one, has_many, polymorphic, through
- **Options** - class_name, foreign_key, primary_key, dependent behaviors
- **Features** - counter cache, touch, scoping, eager loading with N+1 detection

### Database
- **Backends** - SQLite, PostgreSQL
- **Transactions** - nested transactions (savepoints), after_commit/after_rollback callbacks
- **Migrations** - full schema DSL, foreign keys, indexes, column modifications
- **Connection Pooling** - configurable pool size/timeouts, idle connection management, health checks

### Type System
- **Built-in** - Enum (string/integer/native), JSON/JSONB, UUID, Arrays
- **Custom** - extensible type registry with cast/dump/load phases, backend-specific types

### CLI
- **Database** - create, migrate, rollback, status, reset, setup, seed
- **Generators** - migration, model, scaffold

---

## In Progress

### Query Logging & Debugging
- SQL query logging with parameters and execution time
- EXPLAIN query plans
- Performance profiling mode

### Documentation
- Complete API documentation
- Migration guides from other ORMs
- Performance tuning guide

---

## Planned

### Near Term

#### Bulk Operations
- Batch insert (`import`)
- Upsert (insert or update)
- Batch update/delete

#### Soft Deletes
- `deleted_at` column support
- `with_deleted` / `only_deleted` scopes
- Permanent delete

### Medium Term

#### MySQL Backend
- Full MySQL/MariaDB support
- MySQL-specific types (SET, ENUM)
- Full-text search

#### Multiple Databases
- Read replica routing
- Per-model database connections
- Cross-database associations

#### Serialization
- JSON serialization with filtering
- Custom serializers
- API response formatting

### Long Term

#### Advanced Features
- Single Table Inheritance (STI)
- Nested attributes (`accepts_nested_attributes_for`)
- Query objects pattern

#### Caching
- Query result caching
- Identity map
- Cache store interface (Redis, Memcached)

#### Framework Integration
- Lucky framework
- Amber framework
- Generic HTTP handlers

#### Testing Support
- Factory library
- Transactional tests
- Fixture support

---

## Contributing

Contributions are welcome! To get started:

1. Check the [GitHub issues](https://github.com/watzon/ralph/issues) for open tasks
2. Open an issue to discuss significant changes before starting work
3. Submit PRs with tests and documentation

See the [Contributing guide](https://github.com/watzon/ralph/blob/main/README.md#contributing) for details.

## Versioning

Ralph follows [Semantic Versioning](https://semver.org/). Until 1.0:

- Breaking changes may occur in minor versions
- Patch versions are for bug fixes only
- The CHANGELOG documents all changes

**Target for 1.0:** Stable API, comprehensive documentation.

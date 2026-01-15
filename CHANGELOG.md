# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0-beta.5] - 2026-01-14

### Added

- **Query Builder**: Array support for IN clauses - `where()` method now automatically expands arrays into parameterized IN clauses. Pass arrays of strings or UUIDs directly: `User.query { |q| q.where("id IN ?", [1, 2, 3]) }` generates `WHERE id IN ($1, $2, $3)`.
- **Athena Plugin**: Auto-connect on first database access when `lazy_connect: true` is configured. The database connection is automatically established on the first call to `Ralph.database`, eliminating the need for manual `ensure_connected` calls in middleware.

## [1.0.0-beta.4] - 2026-01-12

### Added

- **Schema Validation**: `db:check` CLI command validates model definitions against database schemas, catching mismatches at runtime with detailed error reporting and fix suggestions. Configurable via `strict_resultset_validation` and `validate_schema_on_boot` settings. (closes #216)
- **Composite Primary Keys**: Support for models with multiple primary key columns via `@@primary_keys` array, `primary_key_values` method, and composite WHERE clauses in update/delete operations.
- **UUID in DBValue**: UUID type added to `Query::DBValue` union enabling seamless UUID primary keys throughout the ORM including soft deletes.
- **Float32 Support** (PostgreSQL): Handle PostgreSQL NUMERIC/REAL columns with Float32 type conversion.
- **SQL Migration Generator**: Topological sorting for CREATE TABLE statements based on foreign key dependencies with circular dependency handling via deferred ALTER TABLE constraints.

### Fixed

- **associations**: Support both polymorphic belongs_to syntax forms (`belongs_to name, polymorphic: true` and `belongs_to polymorphic: :name`).
- **model**: Prevent duplicate column definitions when polymorphic columns are manually defined before `belongs_to` declaration.
- **ci**: Skip postgres tests at compile time to prevent connection errors in CI.

### Changed

- **Breaking**: `db:generate` now generates SQL migrations instead of Crystal migrations. The `db:compile`, `db:migrate:sql`, and `db:rollback:sql` commands have been removed.
- **schema**: String columns now use TEXT instead of VARCHAR(255) by default. VARCHAR(n) is still used when size is explicitly specified.

### Documentation

- Regenerate API documentation with Athena plugin.

## [1.0.0-beta.3] - 2026-01-09

### Added

- **Athena Framework Plugin**: New plugin system with Athena framework integration including configuration, migration listeners, and service integration.
- **Schema Introspection CLI**: `db:pull` command introspects existing database and generates Ralph model files with columns, associations, and validations inferred from schema constraints.
- **Schema Diff CLI**: `db:generate` command compares model definitions against database schema and generates diff-based migrations for synchronization.
- **Nil-Safe Column Types**: Non-nullable column declarations now return their declared type instead of always returning `Type | Nil`, eliminating excessive nil-guards. Non-nullable columns get a `column?` accessor for safe nil-checking.
- **Bulk Operations**: `insert_all`, `upsert_all`, `update_all`, `delete_all` methods for high-performance batch database operations.
- **Statement Cache**: LRU prepared statement cache for improved query performance.
- **Identity Map**: Per-request model caching for reduced memory usage and consistent object identity.
- **Soft Deletes**: `ActsAsParanoid` module for soft delete support with `deleted_at` column, `restore` method, and scopes (`with_deleted`, `only_deleted`).
- **Documentation Validation**: Parallel code block validation infrastructure for ensuring documentation examples compile.
- **Type Declaration Syntax**: Crystal-idiomatic type declaration syntax for column and association macros (e.g., `column name : String`, `has_many posts : Post`).

### Fixed

- **validations**: Use fully qualified `Query::Builder` namespace to avoid compilation errors.
- **cli**: Use correct singularize method in schema puller.
- **postgres**: Handle non-Int primary keys in insert; split insert method for auto-increment vs non-auto-increment PKs.

### Changed

- **Breaking**: Remove deprecated symbol syntax from association macros; use type declaration syntax instead.
- Extract timestamps functionality to standalone `Ralph::Timestamps` module for better modularity.
- Reorganize examples into framework-specific directories (athena-blog, kemal-blog).

### Documentation

- Split large documentation pages into focused modules for better navigation and maintainability.
- Add soft deletes guide covering `ActsAsParanoid` usage.
- Expand and reorganize migrations documentation into focused pages.
- Update timestamps documentation to module pattern.
- Add testing and development guide with `--tag "~docs"` for fast test execution.

## [1.0.0-beta.2] - 2026-01-08

### Added

- **Connection Pooling**: Configurable connection pooling with `initial_pool_size`, `max_pool_size`, `checkout_timeout`, and retry options. New APIs: `Ralph.pool_stats`, `Ralph.pool_healthy?`, `Ralph.pool_info`, and `db:pool` CLI command.
- **Timestamps Macro**: `timestamps` macro for automatic `created_at`/`updated_at` column management.
- **Type-Aware Primary Keys**: Migration DSL methods `uuid_primary_key`, `string_primary_key`, and `bigint_primary_key` for non-integer primary keys.
- **Flexible Primary Key Types**: `PrimaryKeyType` alias pattern enabling String, UUID, and other non-Int64 primary keys in associations.
- **Finder Methods**: `find_or_create_by` and `find_or_initialize_by` methods for idempotent record creation, plus `set_attribute` for runtime attribute assignment.
- **Polymorphic PK Flexibility**: Polymorphic associations now support any primary key type by storing foreign keys as strings.
- **PostgreSQL Full-Text Search**: `where_search`, `where_websearch`, `where_phrase_search`, `order_by_search_rank`, `select_search_headline` query methods.
- **PostgreSQL Functions**: Date/time (`where_before_now`, `where_age`, `where_within_last`), string (`where_regex`, `where_ilike`, `where_starts_with`), array (`where_array_contains_all`, `where_cardinality`, `select_unnest`), and aggregation (`select_array_agg`, `select_percentile`, `select_json_agg`) methods.
- **PostgreSQL Index Types**: GIN, GiST, partial, expression, and full-text search indexes in schema builder.
- **Error Handling**: `Ralph::Error` hierarchy with `MigrationError`, `UnsupportedOperationError`, `RecordNotFound`, `RecordInvalid`, and `QueryError` for better debugging with contextual messages and smart hints.

### Fixed

- CLI now supports colon syntax for commands (`db:migrate`) in addition to space-separated (`db migrate`).
- Migration `current_version` query now reads ResultSet correctly.
- Migration version strings no longer append `_i64` suffix.

### Changed

- CLI requires user-compiled binary instead of shipping pre-built. Users create their own `ralph.cr` entry point that requires their migrations and models.
- Scaffold generator removed (framework feature, not ORM).
- Website example reorganized for manual migrations with idempotent seed file.

### Documentation

- Added PostgreSQL-specific features documentation (full-text search, functions, index types).
- Updated CLI documentation for user-compiled approach.
- Documented `find_or_create_by`, seed files, and CLI workflow.
- Updated primary key documentation for flexible types.

## [1.0.0-beta.1] - 2026-01-07

Initial beta release.

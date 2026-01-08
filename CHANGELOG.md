# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

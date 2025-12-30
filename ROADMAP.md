# Ralph ORM Roadmap

This roadmap outlines the planned development path for Ralph to become a production-ready, feature-rich ORM for Crystal.

## Status

**Current Version:** 0.1.0

**What's Working:**
- ✅ **ALL IMMEDIATE MVP FEATURES COMPLETE** - Phase 1 + Phase 2.1 Advanced Clauses + Phase 2.2 Aggregates + Phase 3.1 Basic Associations (incl. Polymorphic) + Phase 3.2 Association Options + Phase 3.3 Association Features + Phase 3.4 Eager Loading + Phase 4.1 Transactions + Phase 2.3 Join Improvements + Phase 7.1 CLI Enhancements + Phase 6.1 Built-in Types + Phase 6.2 Custom Types
- ✅ Phase 1: Core Model Features (CRUD, Validations, Callbacks, Attributes)
- ✅ Phase 2.1: Advanced Clauses (GROUP BY, HAVING, DISTINCT)
- ✅ Phase 2.2: Aggregates (count, sum, avg, min, max)
- ✅ Phase 3.1: Basic Associations (belongs_to, has_one, has_many, polymorphic)
- ✅ Phase 3.2: Association Options (class_name, foreign_key, dependent behaviors)
- ✅ Phase 3.3: Association Features (counter cache, touch, scoping, through associations)
- ✅ Phase 4.1: Transactions (Model.transaction, nested transactions, callbacks)
- ✅ Phase 2.3: Join Improvements (CROSS/FULL OUTER JOIN, join aliases, association joins)
- ✅ Phase 7.1: CLI Enhancements (seed, reset, setup, model/scaffold generators)
- ✅ Phase 5.1: PostgreSQL Backend
- ✅ Phase 6.1: Built-in Types (Enum, JSON/JSONB, UUID, Arrays)
- ✅ Phase 6.2: Custom Types (Type system infrastructure, backend-agnostic type support)
- Pluggable backend architecture with SQLite and PostgreSQL implementation
- Query builder with SELECT, INSERT, UPDATE, DELETE
- Migration system with schema DSL
- CLI with database operations and generators
- Model base class with macros
- Advanced type system with backend-specific support
- **Comprehensive test coverage (497 tests, all passing)**

---

## Phase 1: Core Model Features (MVP) ✅ COMPLETE

### 1.1 Model CRUD Operations ✅
- [x] `Model.find(id)` - Find by primary key
- [x] `Model.find_by(column, value)` - Find by specific column
- [x] `Model.all` - Return all records
- [x] `Model.first` / `Model.last` - Return single records
- [x] `Model.create(**args)` - Create and persist in one call
- [x] `model.update(**args)` - Update attributes and save
- [x] `model.save` - Persist changes (insert or update)
- [x] `model.destroy` - Delete record
- [x] `model.new_record?` / `model.persisted?` - State predicates
- [x] `model.id` - Auto-populated primary key after save

### 1.2 Attribute Handling ✅
- [x] Automatic attribute assignment from query results
- [x] Dirty tracking - track which attributes have changed
- [x] `model.changed?` / `model.changed_attributes`
- [x] Type coercion from database types to Crystal types
- [x] Nil handling for nullable columns
- [x] Default values from schema

### 1.3 Validations ✅
- [x] Presence validation (`validates_presence_of :name`)
- [x] Uniqueness validation (`validates_uniqueness_of :email`)
- [x] Length validation (`validates_length_of :name, min: 3, max: 50`)
- [x] Format validation with regex (`validates_format_of :email, pattern: /@/`)
- [x] Numericality validation (`validates_numericality_of :age`)
- [x] Inclusion validation (`validates_inclusion_of :status, allow: [...]`)
- [x] Exclusion validation (`validates_exclusion_of :name, forbid: [...]`)
- [x] Custom validation methods (`validate :method_name`)
- [x] `errors` object for accessing validation messages
- [x] `valid?` / `invalid?` predicates

### 1.4 Callbacks ✅
- [x] `before_save` / `after_save`
- [x] `before_create` / `after_create`
- [x] `before_update` / `after_update`
- [x] `before_destroy` / `after_destroy`
- [x] `before_validation` / `after_validation`
- [x] Callback chains with `if` / `unless` conditions

---

## Phase 2: Query Builder Enhancements

### 2.1 Advanced Clauses ✅
- [x] `having` clause for GROUP BY filtering
- [x] `group` clause for aggregation
- [x] Distinct select (`distinct` / `distinct(column)`)
- [ ] `for_update` - SELECT FOR UPDATE locking
- [ ] `lock` clause variants

### 2.2 Aggregates ✅
- [x] `count` / `count(column)`
- [x] `sum(column)`
- [x] `avg(column)`
- [x] `min(column)` / `max(column)`
- [x] Aggregate methods on model (`User.count`, `User.average(:age)`)

### 2.3 Join Improvements ✅
- [x] Association-based joins (`Model.join_assoc(:association)`)
- [x] Join aliases for self-joins (`join(table, on, type, alias: "name")`)
- [x] CROSS JOIN, FULL OUTER JOIN (`cross_join`, `full_outer_join`)

### 2.4 Subqueries
- [x] WHERE EXISTS / NOT EXISTS
- [x] WHERE IN with subquery
- [x] FROM subqueries
- [x] CTEs (Common Table Expressions)

### 2.5 Query Composition
- [x] Query merging (`or`, `and` methods)
- [x] Query scopes (`scope :active, -> { where("active = ?", true) }`)
- [x] Chained scopes on model class
- [x] Anonymous scopes

### 2.6 Additional Features
- [x] Window functions
- [x] UNION / UNION ALL
- [x] INTERSECT / EXCEPT
- [x] Query caching / memoization

---

## Phase 3: Associations

### 3.1 Basic Associations ✅
- [x] `belongs_to` - Single record association
- [x] `has_one` - Single owned record
- [x] `has_many` - Collection of records
- [x] Polymorphic associations

### 3.2 Association Options ✅
- [x] `class_name` - Specify related model class
- [x] `foreign_key` - Custom foreign key
- [x] `primary_key` - Custom primary key
- [x] `dependent` - Cascade destroy behaviors
  - [x] `:destroy` - Run callbacks
  - [x] `:delete` / `:delete_all` - Skip callbacks
  - [x] `:nullify` - Set foreign key to NULL
  - [x] `:restrict_with_error` / `:restrict_with_exception`

### 3.3 Association Features ✅
- [x] Automatic foreign key management
- [x] Counter cache for has_many (`counter_cache: true`)
- [x] Touch option (`touch: true` to update parent timestamp on association change)
- [x] Association scoping (`has_many :comments, -> { where(published: true) }`)
- [x] Through associations (`has_many :tags, through: :posts`)
- [ ] Nested attributes (`accepts_nested_attributes_for`) - Deferred to Phase 9

### 3.4 Eager Loading ✅
- [x] Preloading (separate queries)
- [x] Eager loading via `Model.preload(models, :association)`
- [x] Nested includes (`Model.preload(models, {posts: :comments})`)
- [x] Automatic N+1 detection/warnings (`Ralph::EagerLoading.enable_n_plus_one_warnings!`)

---

## Phase 4: Database Features

### 4.1 Transactions ✅
- [x] Model-level transactions (`User.transaction { ... }`)
- [x] Nested transaction support (savepoints)
- [x] Transaction callbacks (`after_commit`, `after_rollback`)
- [ ] Retry on deadlock

### 4.2 Connection Pooling
- [ ] Configurable pool size
- [ ] Connection timeout
- [ ] Idle connection timeout
- [ ] Pool health checks

### 4.3 Multiple Databases
- [ ] Read replica support
- [ ] Write database splitting
- [ ] Per-model database connection
- [ ] Cross-database associations

### 4.4 Schema Features
- [ ] Add/drop columns
- [ ] Rename columns/tables
- [ ] Change column types
- [ ] Add/drop indexes
- [ ] Foreign key constraints
- [ ] Check constraints
- [ ] Unique constraints

---

## Phase 5: Additional Backends ✅ COMPLETE

### 5.1 PostgreSQL ✅
- [x] PostgreSQL backend implementation
- [x] ARRAY column support (Partial - schema generation works)
- [x] JSONB column support (Partial - schema generation works)
- [x] UUID column type (Partial - schema generation works)
- [ ] ENUM types
- [ ] Full-text search
- [ ] Special functions (NOW(), gen_random_uuid(), etc.)

### 5.2 MySQL
- [ ] MySQL backend implementation
- [ ] MySQL-specific types (SET, ENUM, JSON)
- [ ] Full-text search

### 5.3 Other Databases
- [ ] CockroachDB (PostgreSQL-compatible)
- [ ] TiDB (MySQL-compatible)
- [ ] SQL.js (WASM SQLite for browser/client-side)

---

## Phase 6: Type System Enhancements

### 6.1 Built-in Types ✅ COMPLETE
- [x] Enum support with multiple storage strategies (string, integer, native)
- [x] Array types (String[], Int32[], Int64[], Float64[], Bool[])
- [x] JSON/JSONB columns with backend-aware storage
- [x] UUID type with auto-generation support
- [ ] Money/Decimal type with proper precision
- [ ] Date/Time with timezone support
- [ ] Interval type

### 6.2 Custom Types ✅ COMPLETE
- [x] Type mapping system (BaseType, Registry)
- [x] User-defined types with serialization (cast/dump/load)
- [x] Backend-specific type registration
- [x] Migration DSL integration for advanced types
- [x] Query builder operators for JSON and Arrays
- [ ] Composed types (value objects)
- [ ] Immutable types

---

## Phase 7: Development Tools

### 7.1 CLI Enhancements ✅
- [x] `ralph g:model NAME` - Generate model with migration
- [x] `ralph g:scaffold NAME` - Generate full CRUD
- [x] `ralph db:seed` - Run seed file
- [x] `ralph db:reset` - Drop, create, migrate, seed
- [x] `ralph db:setup` - Create database and run migrations

### 7.2 Migration Generator
- [ ] Auto-generate migration from model changes
- [ ] Migration diff from schema.rb
- [ ] Reversible migration helpers

### 7.3 Debugging
- [ ] Query logging (SQL, params, execution time)
- [ ] Explain query plans
- [ ] Query annotations for debugging
- [ ] Performance profiling mode

### 7.4 Documentation
- [ ] API documentation with crystal doc
- [ ] Usage guides for each feature
- [ ] Migration guide from other ORMs
- [ ] Best practices guide
- [ ] Performance tuning guide

---

## Phase 8: Performance & Scalability

### 8.1 Query Optimization
- [ ] Automatic query batching
- [ ] Bulk insert/update (`import`, `upsert`)
- [ ] Prepared statement caching
- [ ] Query plan caching

### 8.2 Caching
- [ ] Query result caching
- [ ] Identity map per-request
- [ ] Fragment caching
- [ ] Cache store interface (Redis, Memcached)

### 8.3 Connection Features
- [ ] Statement pooling
- [ ] Read replica routing
- [ ] Circuit breaker for external database failures

---

## Phase 9: Advanced Features

### 9.1 Soft Deletes
- [ ] `paranoid` column option
- [ ] `with_deleted` / `only_deleted` scopes
- [ ] Permanent delete method

### 9.2 Timestamps
- [ ] Automatic `created_at` / `updated_at`
- [ ] Touching parent associations
- [ ] Custom timestamp columns

### 9.3 Serialization
- [ ] JSON serialization (`to_json`, `from_json`)
- [ ] YAML serialization
- [ ] Attribute filtering (`as_json`, `except`)

### 9.4 Nested Attributes
- [ ] `accepts_nested_attributes_for`
- [ ] Autosave associations
- [ ] Nested transaction handling

### 9.5 Single Table Inheritance
- [ ] STI support with type column
- [ ] Class-specific scopes
- [ ] Automatic type discrimination

### 9.6 Query Objects
- [ ] Extract complex queries to objects
- [ ] Composable query objects
- [ ] Reusable query fragments

---

## Phase 10: Ecosystem & Integration

### 10.1 Web Framework Integration
- [ ] Lucky framework integration
- [ ] Amber framework integration
- [ ] Spider-Gazelle integration
- [ ] Agnostic HTTP handler for any framework

### 10.2 Testing Support
- [ ] Factory bot-like library
- [ ] Test database fixtures
- [ ] Transactional tests (rollback after each test)
- [ ] Factories for associations

### 10.3 Sharding & Partitioning
- [ ] Horizontal sharding support
- [ ] Table partitioning
- [ ] Read/write splitting per shard

---

## Priority Order

**Immediate (Next 2-4 weeks):**
1. ~~Phase 1.1 - Model CRUD Operations~~ ✅
2. ~~Phase 1.2 - Attribute Handling~~ ✅
3. ~~Phase 1.3 - Validations~~ ✅
4. ~~Phase 1.4 - Callbacks~~ ✅
5. ~~Phase 2.1 - Advanced Clauses~~ ✅
6. ~~Phase 2.2 - Aggregates~~ ✅

**All Immediate Priority Features COMPLETE!** ✅

**Short-term (Next priorities):**
10. Phase 7.1 - CLI Enhancements ✅
11. Phase 2.5 - Query Composition/Scopes
12. Phase 3.2 - Association Options ✅

**Medium-term (3-6 months):**
13. Phase 3.3 - Association Features ✅
14. Phase 3.4 - Eager Loading ✅
15. Phase 2.4 - Subqueries
16. Phase 5.2 - MySQL Backend

**Long-term (6-12 months):**
17. Phase 6 - Type System Enhancements
18. Phase 7 - Development Tools
19. Phase 8 - Performance & Scalability
20. Phase 9 - Advanced Features
21. Phase 10 - Ecosystem & Integration

---

## Contributing

If you'd like to contribute to Ralph, please:
1. Check this roadmap for open items
2. Open an issue to discuss what you plan to work on
3. Submit PRs with tests and documentation

Items marked with 🔥 are high priority and great starting points for new contributors.

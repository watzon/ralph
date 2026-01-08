# Model

`class`

*Defined in [src/ralph/model.cr:18](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L18)*

Base class for all ORM models

Models should inherit from this class and define their columns
using the `column` macro.

## Constructors

### `.create`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1212)*

Create a new record and save it

---

### `.find_or_create_by(conditions : Hash(String, DB::Any), &block : self -> ) : self`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1012)*

Find a record by conditions, or create a new one if not found

The new record will have the search conditions set as attributes.
If a block is given, it will be yielded the new record for additional setup
before saving.

Example:
```
# Without block - creates with just the search conditions
user = User.find_or_create_by({"email" => "alice@example.com"})

# With block for additional attributes
user = User.find_or_create_by({"email" => "alice@example.com"}) do |u|
  u.name = "Alice"
  u.role = "user"
end
```

---

### `.find_or_create_by(conditions : Hash(String, DB::Any)) : self`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1026)*

Find a record by conditions, or create a new one if not found (without block)

---

### `.find_or_initialize_by(conditions : Hash(String, DB::Any), &block : self -> ) : self`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L978)*

Find a record by conditions, or initialize a new one if not found

The new record will have the search conditions set as attributes.
If a block is given, it will be yielded the new record for additional setup.
The record is NOT saved automatically.

Example:
```
# Without block
user = User.find_or_initialize_by({"email" => "alice@example.com"})

# With block for additional attributes
user = User.find_or_initialize_by({"email" => "alice@example.com"}) do |u|
  u.name = "Alice"
  u.role = "user"
end
user.save # Must save manually
```

---

### `.find_or_initialize_by(conditions : Hash(String, DB::Any)) : self`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L991)*

Find a record by conditions, or initialize a new one if not found (without block)

---

### `.new`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1219)*

Initialize with attributes

---

## Class Methods

### `._preload_fetch_all(query : Ralph::Query::Builder) : Array(self)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L836)*

Helper for preloading - fetch all records matching a query
This is called by the generated _preload_* methods

---

### `.all`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L508)*

Find all records

---

### `.average(column : String) : Float64 | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1177)*

Get the average of a column

Example:
```
User.average(:age)
```

---

### `.column_names_ordered`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L476)*

Get column names in the order they should be read from result sets.
This matches the order of instance variables in from_result_set.
Generated at compile time to ensure consistency.

---

### `.columns`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L469)*

Get all column metadata

---

### `.count`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1069)*

Count all records

---

### `.count_by(column : String, value) : Int64`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1139)*

Count records matching a column value

---

### `.count_with_query(query : Ralph::Query::Builder) : Int32`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1057)*

Count records using a pre-built query builder

Used for counting scoped associations.

---

### `.distinct`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L648)*

Build a query with DISTINCT

---

### `.distinct`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L654)*

Build a query with DISTINCT and block
The block receives a Builder and should return the modified Builder

---

### `.distinct(*columns : String) : Ralph::Query::Builder`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L660)*

Build a query with DISTINCT on specific columns

---

### `.distinct(*columns : String, &block : Ralph::Query::Builder -> Ralph::Query::Builder) : Ralph::Query::Builder`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L666)*

Build a query with DISTINCT on specific columns and block
The block receives a Builder and should return the modified Builder

---

### `.find(id)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L496)*

Find a record by ID

---

### `.find_all_by(column : String, value) : Array(self)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L902)*

Find all records matching a column value

Example:
```
User.find_all_by("age", 25)
```

---

### `.find_all_by_conditions(conditions : Hash(String, DB::Any)) : Array(self)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L925)*

Find all records matching multiple column conditions

Used primarily for polymorphic associations where we need to match
both type and id columns.

Example:
```
Comment.find_all_by_conditions({"commentable_type" => "Post", "commentable_id" => 1})
```

---

### `.find_all_with_query(query : Ralph::Query::Builder) : Array(self)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1041)*

Find all records using a pre-built query builder

Used primarily for scoped associations where additional WHERE conditions
are added to the query via a lambda.

Example:
```
query = Ralph::Query::Builder.new(User.table_name)
query.where("age > ?", 18)
User.find_all_with_query(query)
```

---

### `.find_by(column : String, value) : self | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L883)*

Find a record by a specific column value

Example:
```
User.find_by("email", "user@example.com")
```

---

### `.find_by_conditions(conditions : Hash(String, DB::Any)) : self | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L945)*

Find one record matching multiple column conditions

Used primarily for polymorphic associations where we need to match
both type and id columns.

---

### `.first`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L850)*

Find the first record matching conditions

---

### `.group_by(*columns : String) : Ralph::Query::Builder`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L636)*

Build a query with GROUP BY clause

---

### `.group_by(*columns : String, &block : Ralph::Query::Builder -> Ralph::Query::Builder) : Ralph::Query::Builder`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L642)*

Build a query with GROUP BY clause and block
The block receives a Builder and should return the modified Builder

---

### `.join_assoc(association_name : Symbol, join_type : Symbol = :inner, alias as_alias : String | Nil = nil) : Ralph::Query::Builder`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L682)*

Join an association by name

This method looks up the association metadata and automatically
generates the appropriate join condition.

Example:
```
User.join_assoc(:posts)              # INNER JOIN posts ON posts.user_id = users.id
Post.join_assoc(:author, :left)      # LEFT JOIN users ON users.id = posts.user_id
User.join_assoc(:posts, :inner, "p") # INNER JOIN posts AS p ON p.user_id = users.id
```

---

### `.last`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L864)*

Find the last record

---

### `.maximum(column : String) : DB::Any | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1206)*

Get the maximum value of a column

Example:
```
User.maximum(:age)
```

---

### `.minimum(column : String) : DB::Any | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1195)*

Get the minimum value of a column

Example:
```
User.minimum(:age)
```

---

### `.preload(models : Array(self), associations : Symbol) : Array(self)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L738)*

Preload associations on an existing collection of models

This uses the preloading strategy (separate queries with IN batching).
Useful when you already have a collection and want to preload associations.

Example:
```
authors = Author.all
Author.preload(authors, :posts)
authors.each { |a| a.posts } # Already loaded, no additional queries

# Multiple associations
Author.preload(authors, [:posts, :profile])

# Nested associations
Author.preload(authors, {posts: :comments})
```

---

### `.primary_key`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L459)*

Get the primary key field name

---

### `.primary_key_type`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L464)*

Get the primary key type as a string (e.g., "Int64", "UUID", "String")

---

### `.query`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L522)*

Get a query builder for this model

---

### `.query`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L529)*

Find records matching conditions
The block receives a Builder and should return the modified Builder
(since Builder is immutable, each method returns a new instance)

---

### `.reset_all_counter_caches(counter_column : String, child_class, foreign_key : String)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1118)*

Reset all counter caches for this model to their actual counts

Example:
```
Publisher.reset_all_counter_caches("books_count", Book, "publisher_id")
```

---

### `.reset_counter_cache(id, counter_column : String, child_class, foreign_key : String)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1094)*

Reset a counter cache column to the actual count

This is useful when counter caches get out of sync.
Call this on the parent model to reset the counter for a specific record.

Example:
```
# Reset books_count for publisher with id 1
Publisher.reset_counter_cache(1, "books_count", Book, "publisher_id")

# Or more commonly via instance method
publisher.reset_counter_cache!("books_count", Book, "publisher_id")
```

---

### `.scoped`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L630)*

Apply an inline/anonymous scope to a query

This is useful for one-off query customizations that don't need
to be defined as named scopes.

The block receives a Builder and should return the modified Builder
(since Builder is immutable, each method returns a new instance)

Example:
```
User.scoped { |q| q.where("active = ?", true).order("name", :asc) }
User.scoped { |q| q.where("age > ?", 18) }.limit(10)
```

---

### `.sum(column : String) : Float64 | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1159)*

Get the sum of a column

Example:
```
User.sum(:age)
```

---

### `.table_name`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L454)*

Get the table name for this model

---

### `.transaction`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/transactions.cr#L110)*

Execute a block within a transaction

If an exception is raised, the transaction is rolled back.
If no exception is raised, the transaction is committed.

Example:
```
User.transaction do
  user = User.create(name: "Alice")
  Post.create(title: "Hello", user_id: user.id)
end
```

---

### `.with_query`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L535)*

Find records matching conditions (alias for query)

---

## Instance Methods

### `#_clear_preloaded!`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1295)*

Clear all preloaded associations

---

### `#_get_attribute(name : String) : DB::Any | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1715)*

Runtime dynamic getter by string key name
This is a method (not macro) that can be called across class boundaries

---

### `#_get_preloaded_many(association : String) : Array(Model) | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1285)*

Get preloaded collection

---

### `#_get_preloaded_one(association : String) : Model | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1280)*

Get a preloaded single record

---

### `#_has_preloaded?(association : String) : Bool`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1290)*

Check if an association has been preloaded

---

### `#_preload_on_class(records : Array(Ralph::Model), assoc : Symbol) : Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L821)*

Instance method to dispatch preloading on this class
Used for nested preloading when we have Array(Model) but need to call
class-specific preload methods
Base implementation - subclasses override this via macro

---

### `#_set_preloaded_many(association : String, records : Array(Model)) : Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1274)*

Set preloaded collection (has_many)

---

### `#_set_preloaded_one(association : String, record : Model | Nil) : Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1268)*

Set a preloaded single record (belongs_to, has_one)

---

### `#changed?(attribute : String) : Bool`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1232)*

Check if a specific attribute has changed

---

### `#changed?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1227)*

Check if any attributes have changed

---

### `#changed_attributes`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1237)*

Get list of changed attributes

---

### `#changes`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1247)*

Get changes as a hash of attribute => [old, new]

---

### `#clear_changes_information`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1258)*

Mark all attributes as clean (no changes)

---

### `#errors`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L19)*

Errors object accessor (using private ivar name to avoid conflicts)

---

### `#new_record?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1425)*

Check if this is a new record (not persisted)

---

### `#original_value(attribute : String) : DB::Any | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1242)*

Get original value of an attribute before changes

---

### `#persisted?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1431)*

Check if this record has been persisted
For non-nil primary keys, also checks if the value is "empty" (blank string, zero, etc.)

---

### `#reload`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1353)*

Reload the record from the database

Example:
```
user = User.find(1)
user.reload
```

---

### `#reset_counter_cache!(counter_column : String, child_class, foreign_key : String)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1131)*

Instance method to reset a counter cache

---

### `#set_attribute(name : String, value : DB::Any) : Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1325)*

Set an attribute by name at runtime

This is useful for dynamic attribute assignment when you have
the attribute name as a string.

Example:
```
user = User.new
user.set_attribute("name", "Alice")
user.set_attribute("email", "alice@example.com")
```

---

### `#to_h`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1489)*

Convert model to hash for database operations
Handles serialization of advanced types (JSON, UUID, Array, Enum)

---

### `#update`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1336)*

Update attributes and save the record

Example:
```
user = User.find(1)
user.update(name: "New Name", age: 30)
```

---

## Macros

### `.__get_by_key_name(name)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1731)*

Dynamic getter by string key name

---

### `.__set_by_key_name(name, value)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1746)*

Dynamic setter by string key name
Handles advanced types (JSON, UUID, Array, Enum) with proper type coercion

---

### `._generate_preload_dispatcher`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L756)*

Macro to generate dispatch method for preloading associations
This is called at compile time to generate a case statement that dispatches
to the correct _preload_<name> method for each association

---

### `._generate_preload_on_class`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L826)*

This is a macro that generates a proper typed method in subclasses

---

### `.after_commit(method_name)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/transactions.cr#L174)*

Register an after_commit callback

The callback will be executed after the current transaction commits.
If not in a transaction, the callback executes immediately.

Example:
```
class User < Ralph::Model
  after_commit :send_welcome_email

  def send_welcome_email
    # Send email logic
  end
end
```

---

### `.after_rollback(method_name)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/transactions.cr#L209)*

Register an after_rollback callback

The callback will be executed if the current transaction is rolled back.

Example:
```
class User < Ralph::Model
  after_rollback :log_rollback

  def log_rollback
    # Log rollback logic
  end
end
```

---

### `.column(name, type, primary = false, default = nil)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L415)*

Define a column on the model

---

### `.from_result_set(rs)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L1524)*

Create a model instance from a result set

---

### `.scope(name, block)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L577)*

Define a named scope for this model

Scopes are reusable query fragments that can be chained together.
They're defined as class methods that return Ralph::Query::Builder instances.

The block receives a Ralph::Query::Builder and should return it after applying conditions.

Example without arguments:
```
class User < Ralph::Model
  table "users"
  column id, Int64, primary: true
  column active, Bool
  column age, Int32

  scope :active, ->(q : Ralph::Query::Builder) { q.where("active = ?", true) }
  scope :adults, ->(q : Ralph::Query::Builder) { q.where("age >= ?", 18) }
end

User.active                    # Returns Builder with active = true
User.active.merge(User.adults) # Chains scopes together
User.active.limit(10)          # Chains with other query methods
```

Example with arguments:
```
class User < Ralph::Model
  scope :older_than, ->(q : Ralph::Query::Builder, age : Int32) { q.where("age > ?", age) }
  scope :with_role, ->(q : Ralph::Query::Builder, role : String) { q.where("role = ?", role) }
end

User.older_than(21)
User.with_role("admin").merge(User.older_than(18))
```

---

### `.table(name)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/model.cr#L410)*

Set the table name for this model

---

## Nested Types

- [`PrimaryKeyType`](ralph-model-primarykeytype.md) - <p>Default primary key type alias (Int64) - overridden by column macro when primary: true This allows associations to reference Model::PrimaryKeyType at compile time</p>


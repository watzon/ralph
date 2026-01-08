# Models Introduction

Ralph follows the **Active Record** pattern, where each class represents a table in your database, and each instance of that class represents a single row. This approach provides an intuitive API for interacting with your data by mapping database operations directly to Crystal objects.

## Defining Your First Model

To create a model, simply define a class that inherits from `Ralph::Model`. Within the class, you use the `column` macro to define your table's schema.

```crystal
require "ralph"

class User < Ralph::Model
  table :users

  column id : Int64, primary: true
  column name : String
  column email : String
  column age : Int32?
  column active : Bool, default: true
  column created_at : Time?
end
```

## Table Configuration

### Table Name

By default, Ralph expects the table name to be the pluralized, snake_case version of your model name (e.g., `User` -> `users`). You can explicitly set the table name using the `table` macro:

```crystal
class User < Ralph::Model
  table "custom_users_table"
end
```

## Column Definitions

Columns are defined using the `column` macro. It takes the column name, its Crystal type, and optional parameters.

```crystal
column name, Type, primary: false, default: nil
```

### Common Column Types

Ralph uses standard Crystal types, which it maps to the underlying database types:

| Crystal Type      | SQLite Type | PostgreSQL Type | Notes                        |
| :---------------- | :---------- | :-------------- | :--------------------------- |
| `Int64` / `Int32` | `INTEGER`   | `BIGINT` / `INT` | Use `Int64` for primary keys |
| `String`          | `TEXT`      | `VARCHAR` / `TEXT` |                              |
| `Bool`            | `INTEGER`   | `BOOLEAN`   | SQLite: 0 or 1               |
| `Time`            | `DATETIME`  | `TIMESTAMP` |                              |
| `Float64`         | `REAL`      | `DOUBLE PRECISION` |                              |

### Advanced Types

Ralph provides built-in support for advanced database types with automatic backend adaptation:

| Crystal Type      | Purpose | PostgreSQL | SQLite | Documentation |
| :---------------- | :------ | :--------- | :----- | :------------ |
| `Enum`            | Enumerated values | Native ENUM or VARCHAR | VARCHAR with CHECK | [Types Guide](./types.md#enum-types) |
| `JSON::Any`       | JSON documents | JSONB or JSON | TEXT with json_valid | [Types Guide](./types.md#jsonjsonb-types) |
| `UUID`            | Unique identifiers | Native UUID | CHAR(36) | [Types Guide](./types.md#uuid-types) |
| `Array(T)`        | Homogeneous arrays | Native arrays | JSON arrays | [Types Guide](./types.md#array-types) |

For comprehensive documentation on advanced types including usage examples, query operators, and custom type creation, see the **[Advanced Types Guide](./types.md)**.

### Nullable Columns

To make a column nullable in the database, use the Crystal nilable type syntax (`?`):

```crystal
column middle_name : String?
column age : Int32?
```

### Default Values

You can specify a default value for a column. This value will be assigned to the attribute when a new instance is created:

```crystal
column status : String, default: "pending"
column active : Bool, default: true
```

## Primary Keys

Every model must have a primary key. By default, Ralph looks for a column named `id`. You can designate any column as the primary key by passing `primary: true` to the `column` macro.

```crystal
class Post < Ralph::Model
  column slug : String, primary: true
  column title : String
end
```

Ralph supports flexible primary key types including `Int64`, `Int32`, `String`, and `UUID`. When you define a primary key, Ralph automatically creates a `PrimaryKeyType` type alias that associations use for foreign key columns:

```crystal
class Organization < Ralph::Model
  column id : String, primary: true  # Creates alias PrimaryKeyType = String
  column name : String
  
  has_many :teams
end

class Team < Ralph::Model
  column id : Int64, primary: true
  column name : String
  
  belongs_to :organization  # Foreign key is String (matches Organization's PK type)
end
```

> **Note:** Polymorphic associations store foreign key IDs as strings to support any primary key type (`Int64`, `String`, `UUID`, etc.). This provides maximum flexibility while maintaining type safety through the registry-based lookup system.

## Column Name Conversion

Ralph automatically handles the conversion between Crystal's camelCase (for properties) and the database's snake_case (for column names).

- **Crystal Property:** `created_at`
- **Database Column:** `created_at`

Wait, Crystal usually uses `snake_case` for variables and methods too! Ralph follows Crystal's standard naming conventions. If you define a column as `firstName`, it will map to `first_name` in the database if using standard migration generators, but the ORM itself uses the exact name provided in the `column` macro for the SQL.

## Model Configuration Order

For clarity and to ensure macros work correctly, it is recommended to define your model in the following order:

1. Table name (`table :name`)
2. Primary key and columns (`column ...`)
3. Validations (`validates_...`)
4. Associations (`belongs_to`, `has_many`, etc.)
5. Custom methods and logic

```crystal
class User < Ralph::Model
  table :users

  column id : Int64, primary: true
  column email : String

  validates_presence_of :email

  has_many :posts

  def display_name
    email.split("@").first
  end
end
```

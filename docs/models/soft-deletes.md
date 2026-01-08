# Soft Deletes (Acts As Paranoid)

Soft Deletes allow you to mark records as "deleted" without actually removing them from the database. This is useful for auditing, data recovery, or maintaining referential integrity while hiding records from normal application flow.

## Introduction

When a model includes `Ralph::ActsAsParanoid`, calling `destroy` on an instance won't issue a `DELETE` statement. Instead, it sets a `deleted_at` timestamp. Most queries will then automatically filter out these records.

## Setup

### Migration

First, your database table needs a `deleted_at` column. You can use the `soft_deletes` helper in your migrations:

```crystal
create_table :users do |t|
  t.primary_key
  t.string :name
  t.timestamps    # adds created_at and updated_at
  t.soft_deletes # adds deleted_at
end
```

### Model Definition

Include the `Ralph::ActsAsParanoid` module in your model:

```crystal
class User < Ralph::Model
  include Ralph::Timestamps
  include Ralph::ActsAsParanoid

  table :users
  column id : Int64, primary: true
  column name : String
end
```

## Basic Usage

### Soft Deleting

Calling `destroy` on a paranoid model sets the `deleted_at` column to the current time:

```crystal
user = User.find(1)
user.destroy
user.deleted? # => true
```

### Checking Delete Status

You can check if a record has been soft-deleted using the `deleted?` method:

```crystal
user.deleted? # => true
```

### Restoring Records

To bring a soft-deleted record back to life, use the `restore` method:

```crystal
user.restore
user.deleted? # => false
```

### Permanent Deletion

If you truly need to remove a record from the database, use `really_destroy!`:

```crystal
user.really_destroy! # Records is gone forever
```

## Querying

By default, all Ralph queries on a paranoid model exclude soft-deleted records.

```crystal
User.all.count # => Only counts non-deleted users
```

### Including Deleted Records

To include soft-deleted records in your query, use the `with_deleted` scope:

```crystal
User.with_deleted.all # Includes everyone
```

### Only Deleted Records

To find only records that have been soft-deleted, use the `only_deleted` scope:

```crystal
User.only_deleted.all # Only soft-deleted records
```

### Finding by ID

`User.find(id)` will return `nil` if the record is soft-deleted. To find a record by ID regardless of its deletion status, use `find_with_deleted`:

```crystal
user = User.find_with_deleted(1)
```

## Advanced Details

### Integration with Timestamps

If your model also includes `Ralph::Timestamps`, the `updated_at` column will be updated whenever a record is soft-deleted or restored.

### Callbacks

Standard `before_destroy` and `after_destroy` callbacks still run when a record is soft-deleted. They also run when `really_destroy!` is called.

### Associations

Currently, soft deletes are handled at the model level. When you query an association (e.g., `user.posts`), Ralph will respect the soft delete settings of the target model.

# CRUD Operations

Ralph provides a comprehensive set of methods for performing Create, Read, Update, and Delete (CRUD) operations on your models.

## Creating Records

There are two primary ways to create a new database record.

### Using `new` and `save`

You can instantiate a model using `new`, set its attributes, and then call `save` to persist it to the database.

```crystal
user = User.new(name: "Alice", email: "alice@example.com")
user.name = "Alice Smith"
if user.save
  puts "User saved successfully!"
else
  puts "Validation errors: #{user.errors.join(", ")}"
end
```

### Using the `create` Class Method

The `create` method instantiates a model and immediately attempts to save it.

```crystal
user = User.create(name: "Bob", email: "bob@example.com")
# Returns the instance, regardless of whether save succeeded.
# Check user.persisted? or user.errors.empty?
```

## Reading Records

Ralph offers several methods to retrieve data from the database.

### Finding by ID

The `find` method retrieves a record by its primary key. It returns `nil` if no record is found.

```crystal
user = User.find(1)
if user
  puts "Found user: #{user.name}"
end
```

### Retrieving All Records

The `all` method returns an array of all records in the table.

```crystal
users = User.all
users.each do |user|
  puts user.email
end
```

### First and Last

You can quickly get the first or last record (ordered by primary key).

```crystal
first_user = User.first
last_user = User.last
```

### Finding by Attributes

Use `find_by` to get the first record matching a specific column value, or `find_all_by` for all matches.

```crystal
user = User.find_by("email", "alice@example.com")
active_users = User.find_all_by("active", true)
```

### Find or Initialize / Find or Create

These methods are useful when you want to find an existing record or create a new one if it doesn't exist. They're particularly helpful for seeding databases or implementing idempotent operations.

#### `find_or_initialize_by`

Finds a record matching the given conditions, or initializes a new one (without saving) if no match is found. The new record will have the search conditions set as attributes.

```crystal
# Without block - just sets the search conditions
user = User.find_or_initialize_by({"email" => "alice@example.com"})

# With block - set additional attributes on new records
user = User.find_or_initialize_by({"email" => "alice@example.com"}) do |u|
  u.name = "Alice"
  u.role = "user"
end

# The block is only called for NEW records, not existing ones
if user.new_record?
  user.save  # Must save manually
end
```

#### `find_or_create_by`

Similar to `find_or_initialize_by`, but automatically saves the new record if one is created.

```crystal
# Find existing or create new (and save)
user = User.find_or_create_by({"email" => "alice@example.com"}) do |u|
  u.name = "Alice"
  u.role = "user"
end

# The record is already persisted if it was newly created
puts user.persisted?  # => true
```

#### Use Cases

These methods are ideal for:

- **Database seeding**: Create records only if they don't already exist
- **Idempotent operations**: Safely run the same code multiple times
- **Upsert-like patterns**: Find existing or create new in one operation

```crystal
# Example: Idempotent seed file
admin = User.find_or_create_by({"email" => "admin@example.com"}) do |u|
  u.name = "Administrator"
  u.role = "admin"
  u.password = "secure_password"
end
```

## Querying Records

For more complex queries, Ralph provides a fluent, type-safe query builder via the `query` block.

```crystal
users = User.query { |q|
  q.where("age >= ?", 18)
   .where("active = ?", true)
   .order("name", :asc)
   .limit(10)
}
```

Because Ralph's query builder is **immutable**, each method call returns a new builder instance. This allows for safe query branching:

```crystal
base_query = User.query { |q| q.where("active = ?", true) }

admins = base_query.where("role = ?", "admin")
regular_users = base_query.where("role = ?", "user")
```

## Updating Records

### Modifying Properties

The most common way to update a record is to change its attributes and call `save`.

```crystal
user = User.find(1)
if user
  user.email = "newemail@example.com"
  user.save
end
```

### The `update` Method

You can also use the `update` method to set multiple attributes and save in a single call.

```crystal
user = User.find(1)
user.update(name: "New Name", age: 30) if user
```

### Dynamic Attribute Assignment

For cases where you need to set an attribute by name at runtime (e.g., when the attribute name is stored in a variable), use `set_attribute`:

```crystal
user = User.new
user.set_attribute("name", "Alice")
user.set_attribute("email", "alice@example.com")
user.save
```

This is primarily useful for dynamic scenarios like building records from form data or implementing generic update logic.

## Deleting Records

### Instance Destruction

To delete a specific record, call `destroy` on the instance.

```crystal
user = User.find(1)
user.destroy if user
```

### Batch Deletion

Currently, Ralph focuses on instance-level destruction to ensure callbacks and dependent association logic are executed correctly. For raw batch deletion, you can use the database interface directly, though this is generally discouraged for model-managed data.

## Error Handling Patterns

Ralph's `save` and `update` methods return a `Bool` indicating success. If they return `false`, you can inspect the `errors` object.

```crystal
user = User.new(name: "")
unless user.save
  user.errors.each do |error|
    # error is a Ralph::Validations::Error object
    puts "#{error.column}: #{error.message}"
  end
end
```

## Best Practices

1. **Check Return Values:** Always check the return value of `save`, `update`, and `destroy`.
2. **Use Parameterized Queries:** When using the query builder's `where` method, always use the `?` placeholder to prevent SQL injection.
3. **Explicit over Implicit:** Ralph does not perform lazy loading. If you need associated data, use eager loading (to be covered in Association docs) or explicit queries.

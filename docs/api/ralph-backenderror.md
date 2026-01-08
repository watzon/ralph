# BackendError

`class`

*Defined in [src/ralph.cr:60](https://github.com/watzon/ralph/blob/main/src/ralph.cr#L60)*

Exception raised when attempting to use backend-specific features on an unsupported backend

This is raised when PostgreSQL-specific features (like full-text search, regex operators,
or special functions) are used on a non-PostgreSQL backend.

## Example

```
# Using SQLite backend
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
end

# This will raise BackendError
User.query { |q| q.where_search("name", "john") }
# => Ralph::BackendError: Full-text search is only available on PostgreSQL backend
```


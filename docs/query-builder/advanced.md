# Advanced Query Building

Ralph's query builder supports advanced SQL features like Common Table Expressions (CTEs), window functions, set operations, and complex subqueries while maintaining type safety and an immutable interface.

## Common Table Expressions (CTEs)

CTEs allow you to define temporary result sets that can be referenced within a larger query. They are particularly useful for breaking down complex queries into readable parts.

### Simple CTEs

Use `with_cte` to add a CTE to your query.

```crystal
# Define the subquery for the CTE
active_users = User.query
  .select("id")
  .where("active = ?", true)

# Use the CTE in a main query
query = User.query
  .with_cte("active_user_ids", active_users)
  .where("id IN (SELECT id FROM active_user_ids)")
```

### Recursive CTEs

Ralph supports recursive CTEs for querying hierarchical data like category trees or organizational charts.

```crystal
# Base case: Root categories
base = Category.query
  .select("id", "name", "parent_id")
  .where("parent_id IS NULL")

# Recursive case: Child categories joined back to the CTE
recursive = Category.query
  .select("categories.id", "categories.name", "categories.parent_id")
  .join("category_tree", "categories.parent_id = category_tree.id")

# Build the recursive query
query = Category.query.with_recursive_cte("category_tree", base, recursive)
```

## Window Functions

Window functions perform calculations across a set of table rows that are somehow related to the current row.

### Basic Usage

Use the `window` method to add a window function to your `SELECT` clause.

```crystal
# Rank employees by salary within each department
query = Employee.query
  .select("name", "department", "salary")
  .window("RANK()",
    partition_by: "department",
    order_by: "salary DESC",
    as: "salary_rank")
```

### Helper Methods

Ralph provides convenience helpers for common window functions:

```crystal
# ROW_NUMBER()
query.row_number(order_by: "created_at ASC", as: "join_order")

# RANK()
query.rank(partition_by: "category_id", order_by: "price DESC")

# DENSE_RANK()
query.dense_rank(order_by: "score DESC")

# Aggregate window functions
query.window_sum("total", partition_by: "user_id", as: "running_total")
query.window_avg("rating", partition_by: "product_id", as: "avg_rating")
query.window_count("id", partition_by: "group_id", as: "members_count")
```

## Set Operations

Set operations allow you to combine the results of two or more queries.

### UNION and UNION ALL

`union` combines results and removes duplicates, while `union_all` keeps all rows.

```crystal
active_users = User.query.where("active = ?", true)
premium_users = User.query.where("subscription = ?", "premium")

# Combined result set (duplicates removed)
all_relevant_users = active_users.union(premium_users)

# Combined result set (including duplicates)
every_user = active_users.union_all(premium_users)
```

### INTERSECT and EXCEPT

`intersect` returns rows common to both queries, and `except` returns rows from the first query that are not in the second.

```crystal
# Users who are BOTH active and premium
active_premium = active_users.intersect(premium_users)

# Users who are active but NOT premium
active_only = active_users.except(premium_users)
```

## EXISTS Subqueries

`exists` and `not_exists` are used to filter results based on the presence or absence of related data in a subquery.

```crystal
# Find users who have at least one pending order
pending_orders = Order.query
  .select("1")
  .where("orders.user_id = users.id")
  .where("status = ?", "pending")

users_with_pending = User.query.exists(pending_orders)

# Find users with no orders at all
users_without_orders = User.query.not_exists(
  Order.query.where("orders.user_id = users.id")
)
```

## Subqueries in FROM

You can treat a subquery as a table in the `FROM` clause using `from_subquery`.

```crystal
# Subquery to calculate totals per user
totals = Order.query
  .select("user_id", "SUM(total) as total_spent")
  .group("user_id")

# Use the subquery as the source for the main query
query = User.query
  .from_subquery(totals, "user_stats")
  .select("users.*", "user_stats.total_spent")
  .join("users", "users.id = user_stats.user_id")
  .where("user_stats.total_spent > ?", 1000)
```

## Query Composition (OR/AND)

You can explicitly group and combine entire query objects using `or` and `and`.

```crystal
query1 = User.query.where("age > ?", 18).where("active = ?", true)
query2 = User.query.where("role = ?", "admin")

# WHERE (age > $1 AND active = $2) OR (role = $3)
combined = query1.or(query2)
```

## JSON Query Operators

Ralph provides cross-backend JSON query methods for working with JSON and JSONB columns.

### Querying JSON Fields

```crystal
# Find records where JSON field matches a value
# Uses JSON path syntax: $.key.nested.field
Post.query { |q|
  q.where_json("metadata", "$.author", "Alice")
}

# PostgreSQL generates: metadata->>'author' = 'Alice'
# SQLite generates: json_extract(metadata, '$.author') = 'Alice'
```

### Checking JSON Key Existence

```crystal
# Find records where JSON has a specific key
User.query { |q|
  q.where_json_has_key("preferences", "theme")
}

# PostgreSQL generates: preferences ? 'theme'
# SQLite generates: json_extract(preferences, '$.theme') IS NOT NULL
```

### JSON Containment

```crystal
# Find records where JSON contains a value or object
Post.query { |q|
  q.where_json_contains("metadata", %({"status": "published"}))
}

# PostgreSQL generates: metadata @> '{"status": "published"}'
# SQLite generates: json_extract equivalent comparison
```

### Complex JSON Queries

```crystal
# Combine multiple JSON conditions
Post.query { |q|
  q.where_json("metadata", "$.author", "Alice")
   .where_json_has_key("metadata", "tags")
   .where_json_contains("settings", %({"notify": true}))
}

# Nested JSON paths
Article.query { |q|
  q.where_json("config", "$.display.theme", "dark")
}
```

### JSON Array Operations

```crystal
# Query JSON arrays (stored in JSON columns)
Event.query { |q|
  # Check if JSON array contains element
  q.where("json_extract(data, '$.attendees') LIKE ?", "%Alice%")
}

# For native array columns, use array operators instead (see below)
```

## Array Query Operators

Ralph provides cross-backend array query methods for working with native array columns.

### Array Contains Element

Check if an array contains a specific element:

```crystal
# Find posts tagged with "crystal"
Post.query { |q|
  q.where_array_contains("tags", "crystal")
}

# PostgreSQL generates: tags @> ARRAY['crystal']
# SQLite generates: EXISTS (SELECT 1 FROM json_each(tags) WHERE value = 'crystal')
```

### Array Overlaps

Check if two arrays have any common elements:

```crystal
# Find posts with any of these tags
Post.query { |q|
  q.where_array_overlaps("tags", ["crystal", "ruby", "python"])
}

# PostgreSQL generates: tags && ARRAY['crystal', 'ruby', 'python']
# SQLite generates: Complex EXISTS subquery with json_each
```

### Array Contained By

Check if an array is a subset of given values:

```crystal
# Find posts where all tags are in the allowed list
Post.query { |q|
  q.where_array_contained_by("tags", ["crystal", "database", "orm", "performance"])
}

# PostgreSQL generates: tags <@ ARRAY['crystal', 'database', 'orm', 'performance']
# SQLite generates: Complex NOT EXISTS subquery
```

### Array Length

Compare the length of an array:

```crystal
# Find posts with more than 3 tags
Post.query { |q|
  q.where_array_length("tags", ">", 3)
}

# PostgreSQL generates: array_length(tags, 1) > 3
# SQLite generates: json_array_length(tags) > 3

# Operators: =, !=, <, >, <=, >=
Post.query { |q|
  q.where_array_length("tags", ">=", 5)
}
```

### Combining Array Queries

```crystal
# Complex array queries
Post.query { |q|
  q.where_array_contains("tags", "crystal")
   .where_array_length("tags", ">", 2)
   .where_array_overlaps("categories", ["tutorial", "guide"])
}
```

### Array with Integers

Array operators work with any element type:

```crystal
# Integer arrays
Record.query { |q|
  q.where_array_contains("user_ids", 123)
}

# Boolean arrays
Feature.query { |q|
  q.where_array_contains("flags", true)
}

# UUID arrays (if registered)
Session.query { |q|
  q.where_array_contains("participant_ids", UUID.random)
}
```

## Advanced Type Query Examples

### Real-World JSON Queries

```crystal
# E-commerce product search
Product.query { |q|
  q.where_json("specifications", "$.brand", "Apple")
   .where_json_has_key("specifications", "warranty")
   .where("price < ?", 1000)
}

# User preferences filtering
User.query { |q|
  q.where_json_contains("preferences", %({"notifications": {"email": true}}))
   .where_json("settings", "$.theme", "dark")
}

# Event filtering by metadata
Event.query { |q|
  q.where_json("metadata", "$.location.city", "San Francisco")
   .where_json_has_key("metadata", "attendees")
   .where("created_at > ?", Time.utc - 7.days)
}
```

### Real-World Array Queries

```crystal
# Tag-based search (any match)
Post.query { |q|
  q.where_array_overlaps("tags", ["crystal", "tutorial"])
   .where("published = ?", true)
   .order("created_at", :desc)
}

# Category filtering (must have all)
Article.query { |q|
  q.where_array_contains("categories", "programming")
   .where_array_contains("categories", "beginner")
   .where_array_length("tags", ">=", 3)
}

# Related records by ID arrays
User.query { |q|
  q.where_array_overlaps("following_ids", [123, 456, 789])
}
```

### Combining Advanced Types

```crystal
# Mix JSON, arrays, and standard queries
Post.query { |q|
  q.where_array_contains("tags", "featured")
   .where_json("metadata", "$.author.verified", true)
   .where("view_count > ?", 1000)
   .where("created_at > ?", Time.utc - 30.days)
   .order("view_count", :desc)
   .limit(10)
}
```

## Performance Tips

1. **Use UNION ALL instead of UNION** if you know there are no duplicates or don't care about them, as it avoids a costly duplicate-removal step.
2. **CTEs are not always materialized** in SQLite (depending on version and complexity). If you have performance issues with a large CTE, check the `EXPLAIN QUERY PLAN`.
3. **Index your subquery joins**. Ensure columns used in `WHERE EXISTS` or `JOIN` conditions are properly indexed in the database.
4. **Use Window Functions** instead of multiple self-joins or subqueries for calculations like ranking and running totals; they are usually much more efficient.
5. **JSON/Array Indexes** (PostgreSQL):
   - Use GIN indexes for JSON containment: `CREATE INDEX idx_data ON table USING GIN (json_column)`
   - Use GIN indexes for array containment: `CREATE INDEX idx_tags ON table USING GIN (tags)`
   - B-tree indexes work for exact JSON field lookups: `CREATE INDEX idx_author ON table ((metadata->>'author'))`
6. **SQLite JSON/Array Performance**:
   - JSON queries use `json_extract()` which can be slow on large datasets
   - Consider denormalizing frequently queried JSON fields to regular columns
   - Array operations in SQLite use JSON functions - avoid on huge arrays (100k+ elements)
7. **Choose JSONB over JSON** (PostgreSQL) for frequently queried fields - it's binary and indexed efficiently.

## PostgreSQL-Specific Features

Ralph provides many PostgreSQL-specific query methods for advanced database operations. These methods raise `Ralph::BackendError` when used on SQLite.

### Full-Text Search

PostgreSQL's full-text search capabilities are powerful for searching text content with linguistic understanding.

#### Basic Full-Text Search

Use `where_search` for single-column full-text search with language-aware tokenization:

```crystal
# Find articles about "crystal programming"
Article.query { |q|
  q.where_search("content", "crystal programming")
}
# SQL: WHERE to_tsvector('english', "content") @@ plainto_tsquery('english', 'crystal programming')
```

#### Multi-Column Full-Text Search

Search across multiple columns simultaneously with `where_search_multi`:

```crystal
# Search across title and content
Article.query { |q|
  q.where_search_multi(["title", "content"], "web framework")
}
# Combines: "Learn web framework" from title or content
```

#### Web Search Syntax

Use `where_websearch` for queries with web search operators (PostgreSQL 11+):

```crystal
# Support for AND, OR, -, and quoted phrases
Article.query { |q|
  q.where_websearch("content", "crystal -ruby \"web framework\"")
}
# Finds: articles with "crystal" AND "web framework" but NOT "ruby"
```

#### Phrase Matching

Match exact phrases with `where_phrase_search`:

```crystal
# Only matches "web framework", not "web application framework"
Article.query { |q|
  q.where_phrase_search("content", "web framework")
}
```

#### Search Ranking

Order results by relevance using `order_by_search_rank`:

```crystal
Article.query { |q|
  q.where_search("content", "crystal")
   .order_by_search_rank("content", "crystal")
}
```

Normalize rankings with optional parameters (0-32, combinable with bitwise OR):

```crystal
# Rank more relevant when matching terms are close together
Article.query { |q|
  q.where_search("content", "crystal orm")
   .order_by_search_rank_cd("content", "crystal orm", normalization: 1 | 4)
}
```

#### Search Headlines

Extract highlighted excerpts matching search terms:

```crystal
Article.query { |q|
  q.where_search("content", "crystal")
   .select_search_headline("content", "crystal", max_words: 50, start_tag: "<mark>", stop_tag: "</mark>")
}
# Returns: "Learn about <mark>Crystal</mark> programming language"
```

### Date/Time Functions

PostgreSQL provides advanced date/time operations useful for temporal queries.

#### Current Time Comparisons

```crystal
# Find records created in the past (before now)
Event.query { |q| q.where_before_now("created_at") }

# Find upcoming events (after now)
Event.query { |q| q.where_after_now("scheduled_for") }

# Custom operator comparison with NOW()
Event.query { |q| q.where_now("updated_at", ">=") }

# Using CURRENT_TIMESTAMP (SQL standard)
Event.query { |q| q.where_current_timestamp("created_at", "=") }
```

#### Select Current Time

```crystal
# Get server time in result
Event.query { |q|
  q.select("id", "name")
   .select_now("server_time")
}
```

#### Age Calculation

Calculate intervals between timestamps:

```crystal
# Find records older than 7 days
Post.query { |q| q.where_older_than("created_at", "7 days") }

# Find records updated within 1 hour
Post.query { |q| q.where_age("updated_at", "<", "1 hour") }

# Custom interval format: '1 year 2 months 3 days 4 hours 5 minutes 6 seconds'
```

#### Date Truncation

Round dates to specific precision:

```crystal
# Find posts created on a specific day
Post.query { |q|
  q.where_date_trunc("day", "created_at", "2024-01-15")
}

# Group by month in results
Post.query { |q|
  q.select("title")
   .select_date_trunc("month", "created_at", as: "month")
   .group("month")
}

# Supported precisions: microseconds, milliseconds, second, minute, hour,
# day, week, month, quarter, year, decade, century, millennium
```

#### Date Component Extraction

Extract specific date/time components:

```crystal
# Find posts from 2024
Post.query { |q| q.where_extract("year", "created_at", 2024) }

# Find posts from January (any year)
Post.query { |q| q.where_extract("month", "created_at", 1) }

# Get day of week for display
Post.query { |q|
  q.select("title")
   .select_extract("dow", "created_at", as: "day_of_week")
}

# Supported parts: century, day, decade, dow, doy, epoch, hour, isodow,
# isoyear, microseconds, millennium, milliseconds, minute, month, quarter,
# second, timezone, timezone_hour, timezone_minute, week, year
```

#### Relative Date Ranges

Filter by relative time intervals:

```crystal
# Posts from the last 7 days
Post.query { |q| q.where_within_last("created_at", "7 days") }

# Comments from the last 2 hours
Comment.query { |q| q.where_within_last("created_at", "2 hours") }
```

### String Functions

PostgreSQL string manipulation for flexible text queries.

#### Regular Expressions

```crystal
# Case-sensitive regex matching
User.query { |q|
  q.where_regex("username", "^[a-zA-Z][a-zA-Z0-9_]*$")
}

# Case-insensitive regex
User.query { |q|
  q.where_regex_i("email", "^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$")
}

# Negation - NOT matching
User.query { |q| q.where_not_regex("code", "\\d+") }
User.query { |q| q.where_not_regex_i("name", "temp") }
```

#### Case-Insensitive Pattern Matching

```crystal
# ILIKE for flexible searching
User.query { |q| q.where_ilike("name", "%john%") }

# NOT ILIKE
User.query { |q| q.where_not_ilike("email", "%@test.com") }
```

#### String Prefix/Suffix

```crystal
# Find names starting with "John"
User.query { |q| q.where_starts_with("name", "John") }

# Find emails ending with specific domain
User.query { |q| q.where_ends_with("email", "@example.com") }
```

#### String Length

```crystal
# Find names longer than 10 characters
User.query { |q| q.where_length("name", ">", 10) }

# Select with length in result
User.query { |q|
  q.select("name")
   .select_length("name", as: "name_length")
}
```

#### Case Conversion

```crystal
# Case-insensitive lookup using lower()
User.query { |q| q.where_lower("email", "test@example.com") }

# Uppercase comparison
User.query { |q| q.where_upper("code", "ABC123") }

# Select converted values
User.query { |q|
  q.select_lower("email", as: "email_lower")
   .select_upper("code", as: "code_upper")
}
```

#### Substring Operations

```crystal
# Check substring at position
Post.query { |q|
  q.where_substring("code", 1, 3, "ABC")
}

# Select substring in results
Post.query { |q|
  q.select_substring("code", 1, 3, as: "prefix")
}
```

#### String Replacement

```crystal
Post.query { |q|
  q.select_replace("email", "@old.com", "@new.com", as: "migrated_email")
}
```

### Array Functions

PostgreSQL native array operations for complex data.

#### Array Containment

```crystal
# Check if array contains ALL specified values
Post.query { |q|
  q.where_array_contains_all("tags", ["crystal", "orm"])
}
# SQL: WHERE "tags" @> ARRAY['crystal', 'orm']

# Check if array is subset of given values
Post.query { |q|
  q.where_array_is_contained_by("tags", ["programming", "tutorial", "reference"])
}
```

#### Array Cardinality

Compare array length:

```crystal
# Find posts with more than 3 tags
Post.query { |q|
  q.where_cardinality("tags", ">", 3)
}

# Array operations: =, !=, <, >, <=, >=
```

#### Array Element Operations

```crystal
# Add element to array (for UPDATE)
Post.query { |q|
  q.select_array_append("tags", "featured", as: "new_tags")
}

# Remove element from array
Post.query { |q|
  q.select_array_remove("tags", "deprecated", as: "updated_tags")
}

# Get element at index (1-based in PostgreSQL)
Post.query { |q|
  q.select_array_element("tags", 1, as: "first_tag")
}
```

#### Expand Arrays to Rows

```crystal
# Convert array elements into individual rows
Tag.query { |q|
  q.select_unnest("tag_list", as: "tag")
}
# Useful for joining expanded arrays with other tables
```

### Advanced Aggregations

PostgreSQL aggregation functions for complex data analysis.

#### Array and String Aggregation

```crystal
# Collect values into array
Post.query { |q|
  q.group("author_id")
   .select_array_agg("id", distinct: true, as: "post_ids")
}

# Aggregate strings with delimiter
Category.query { |q|
  q.group("parent_id")
   .select_string_agg("name", ", ", order_by: "name", as: "categories")
}
```

#### Statistical Aggregations

```crystal
# Most common value
Rating.query { |q|
  q.group("product_id")
   .select_mode("score", as: "most_common_rating")
}

# Percentile calculations (continuous - interpolated)
Response.query { |q|
  q.select_percentile("response_time", 0.95, as: "p95_time")
  q.select_percentile("response_time", 0.99, as: "p99_time")
}

# Median (50th percentile)
Response.query { |q|
  q.select_median("response_time", as: "median_time")
}

# Percentile discrete (actual value from dataset)
Score.query { |q|
  q.select_percentile_disc("score", 0.75, as: "q3_score")
}
```

#### JSON Aggregations

```crystal
# Collect values into JSON array
Order.query { |q|
  q.group("user_id")
   .select_json_agg("total", order_by: "created_at", as: "order_totals")
}

# JSONB version for PostgreSQL 11+
Event.query { |q|
  q.group("session_id")
   .select_jsonb_agg("event_id", as: "events_jsonb")
}

# Build JSON objects
User.query { |q|
  q.select_json_build_object(
    {"name" => "name", "email" => "email", "active" => "active"},
    as: "user_info"
  )
}
```

### UUID Functions

Generate UUIDs in queries:

```crystal
# Generate random UUID v4
Session.query { |q|
  q.select("id")
   .select_random_uuid("new_session_id")
}
```

### Real-World PostgreSQL Examples

#### Full-Text Search with Ranking

```crystal
# Search articles and rank by relevance
results = Article.query { |q|
  q.select("id", "title", "excerpt")
   .where_search("content", "crystal database")
   .order_by_search_rank("content", "crystal database", normalization: 1)
}
```

#### Time-Series Analysis

```crystal
# Daily metrics with age filter
Metric.query { |q|
  q.select_date_trunc("day", "recorded_at", as: "day")
   .select("avg(value) AS avg_value")
   .where_age("recorded_at", ">", "30 days")
   .group("day")
   .order("day", :desc)
}
```

#### Array and JSON Combination

```crystal
# Complex data structure queries
Document.query { |q|
  q.where_array_contains_all("categories", ["active", "featured"])
   .where_json_contains("metadata", %({"verified": true}))
   .select_json_build_object(
     {"title" => "title", "cats" => "categories"},
     as: "summary"
   )
}
```

#### Aggregation Pipeline

```crystal
# Complex grouping with multiple aggregations
Sales.query { |q|
  q.group("product_id", "date_trunc('month', created_at)")
   .select("product_id")
   .select_date_trunc("month", "created_at", as: "month")
   .select_sum("amount", as: "total_sales")
   .select_count("id", as: "transaction_count")
   .select_array_agg("customer_id", distinct: true, as: "unique_customers")
}
```

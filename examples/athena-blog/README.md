# Ralph Blog Example (Athena Framework)

A blog application demonstrating Ralph ORM with Athena Framework, featuring **UUID primary keys** and the **Ralph::Athena plugin** for seamless integration.

This example showcases how Ralph integrates with Athena's dependency injection system, providing database access, transactions, caching, and health monitoring through an injectable service.

## Features

- **Ralph::Athena Plugin**: One-line setup with `require "ralph/plugins/athena"`
- **DI Service Injection**: `Ralph::Athena::Service` available in all controllers
- **Transaction Support**: Wrap operations in transactions via `@ralph.transaction`
- **Cache Management**: Query cache invalidation after writes
- **Health Monitoring**: Pool stats and health check endpoints
- **UUID Primary Keys**: All models use UUID strings as primary keys
- **Auto Migrations**: Migrations run automatically on app startup
- User authentication with bcrypt password hashing
- Posts with draft/published states
- Comments on posts
- Cookie-based session management

## Project Structure

```
src/
├── server.cr            # HTTP server entry point
├── main.cr              # App setup, Ralph::Athena.configure
├── models/              # User, Post, Comment (all with UUID PKs)
├── controllers/
│   ├── auth_controller.cr      # Login/register/logout (uses @ralph)
│   ├── posts_controller.cr     # Post CRUD (uses @ralph transactions)
│   ├── comments_controller.cr  # Comment routes (uses @ralph)
│   └── api_controller.cr       # JSON API with health/pool endpoints
├── services/
│   ├── session_service.cr      # Cookie-based sessions
│   └── view_helpers.cr         # Template helpers
├── views/
│   ├── layouts/application.ecr
│   ├── posts/*.ecr
│   └── auth/*.ecr
└── listeners/
    └── static_file_listener.cr # Serves public/ files
db/
└── migrations/          # Schema migrations (UUID tables)
public/
└── css/style.css        # Stylesheet
```

## Running

```bash
cd examples/athena-blog
shards install
crystal run src/server.cr
```

Server starts at `http://localhost:3000`. Migrations run automatically on startup.

## Ralph::Athena Plugin Usage

### Simple Configuration

```crystal
require "athena"
require "ralph"
require "ralph/backends/sqlite"
require "ralph/plugins/athena"

# Load migrations before configure
require "../db/migrations/*"

# One-line setup!
Ralph::Athena.configure(
  database_url: "sqlite3://./blog.sqlite3",
  auto_migrate: true
)
```

### Service Injection

The plugin registers a `Ralph::Athena::Service` with Athena's DI container:

```crystal
@[ADI::Register]
class PostsController < ATH::Controller
  def initialize(
    @session_service : Blog::SessionService,
    @ralph : Ralph::Athena::Service
  )
  end

  @[ARTA::Post("/posts")]
  def create(request : ATH::Request) : ATH::Response
    # ... validation ...

    if @post.save
      # Invalidate cache after write
      @ralph.invalidate_cache("posts")
      # ...
    end
  end

  @[ARTA::Post("/posts/{id}/delete")]
  def delete(request : ATH::Request, id : String) : ATH::Response
    # Use transaction for multi-model operations
    @ralph.transaction do
      post.comments.each(&.destroy)
      post.destroy
    end

    # Invalidate multiple caches
    @ralph.invalidate_cache("posts")
    @ralph.invalidate_cache("comments")
    # ...
  end
end
```

### Available Service Methods

| Method | Description |
|--------|-------------|
| `database` | Returns the raw database backend |
| `transaction(&)` | Execute block in transaction with auto-rollback |
| `healthy?` | Check database connectivity |
| `pool_stats` | Get connection pool statistics |
| `pool_info` | Get detailed pool information |
| `clear_cache` | Clear the entire query cache |
| `invalidate_cache(table)` | Invalidate cache for specific table |

## API Endpoints

### Public API

| Endpoint | Description |
|----------|-------------|
| `GET /api/posts` | List published posts (JSON) |
| `GET /api/posts/:id` | Get a post with comment count (JSON) |
| `GET /api/posts/:id/comments` | Get comments for a post (JSON) |
| `GET /api/stats` | Blog statistics (posts, users, comments) |

### Monitoring API

| Endpoint | Description |
|----------|-------------|
| `GET /api/health` | Health check with DB status and cache stats |
| `GET /api/pool` | Connection pool information |
| `POST /api/cache/clear` | Clear the query cache |

### Example Responses

**GET /api/health**
```json
{
  "status": "ok",
  "database": true,
  "cache": {
    "enabled": true,
    "hit_rate": 0.85,
    "size": 42
  }
}
```

**GET /api/pool**
```json
{
  "initial_pool_size": 1,
  "max_pool_size": 0,
  "max_idle_pool_size": 1,
  "checkout_timeout": 5.0,
  "retry_attempts": 3,
  "retry_delay": 0.2,
  "healthy": true,
  "dialect": "sqlite",
  "closed": false
}
```

**GET /api/stats**
```json
{
  "posts": {
    "total": 10,
    "published": 8,
    "drafts": 2
  },
  "users": 5,
  "comments": 23
}
```

## Key Patterns Demonstrated

### Transactions for Multi-Model Operations

```crystal
# Delete post and all its comments atomically
@ralph.transaction do
  post.comments.each(&.destroy)
  post.destroy
end
```

### Cache Invalidation After Writes

```crystal
if @post.save
  @ralph.invalidate_cache("posts")
end
```

### Health Check Endpoints

```crystal
@[ARTA::Get("/api/health")]
def health_check
  cache_stats = Ralph.cache_stats
  {
    status:   "ok",
    database: @ralph.healthy?,
    cache:    {
      enabled:  Ralph.cache_enabled?,
      hit_rate: cache_stats.hit_rate,
      size:     cache_stats.size,
    },
  }
end
```

## Athena vs Kemal Comparison

| Aspect | Kemal (website example) | Athena (this example) |
|--------|------------------------|----------------------|
| Routing | DSL macros (get, post) | Annotation-based (@[ARTA::Get]) |
| Controllers | Route blocks | Controller classes |
| Sessions | kemal-session shard | Custom SessionService |
| Static Files | `public_folder` helper | StaticFileListener |
| Views | ECR templates | ECR via `render` macro |
| DI | Manual | Built-in ADI container |
| Ralph Setup | `Ralph.configure { }` | `Ralph::Athena.configure()` |
| Transactions | `Model.transaction { }` | `@ralph.transaction { }` |
| Cache | Manual | `@ralph.invalidate_cache(table)` |

## Notes

- Models use `Blog::` namespace for proper macro resolution
- Association types must be fully qualified (e.g., `belongs_to user : Blog::User`)
- SQLite database (`blog.sqlite3`) is created automatically
- UUIDs are stored as TEXT in SQLite
- Migrations are loaded before `Ralph::Athena.configure` for auto-migrate to work
- All controllers inject both `SessionService` and `Ralph::Athena::Service`

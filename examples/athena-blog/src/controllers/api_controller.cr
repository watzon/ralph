module Blog::Controllers
  @[ADI::Register]
  class ApiController < ATH::Controller
    # Inject the Ralph service for database operations
    # This demonstrates how you can use DI with the Athena plugin
    def initialize(@ralph : Ralph::Athena::Service)
    end

    # GET /api/posts - List published posts as JSON
    @[ARTA::Get("/api/posts")]
    def posts_index : Array(NamedTuple(id: String?, title: String?, excerpt: String, published: Bool?, user_id: String?, created_at: Time?))
      Blog::Post.find_all_with_query(Blog::Post.published).map do |post|
        {
          id:         post.id,
          title:      post.title,
          excerpt:    post.excerpt,
          published:  post.published,
          user_id:    post.user_id,
          created_at: post.created_at,
        }
      end
    end

    # GET /api/posts/:id - Get single post as JSON
    @[ARTA::Get("/api/posts/{id}")]
    def posts_show(id : String) : NamedTuple(id: String?, title: String?, body: String?, published: Bool?, user_id: String?, created_at: Time?, comments_count: Int32)
      post = Blog::Post.find_by("id", id)

      if post && post.published
        {
          id:             post.id,
          title:          post.title,
          body:           post.body,
          published:      post.published,
          user_id:        post.user_id,
          created_at:     post.created_at,
          comments_count: post.comments.size,
        }
      else
        raise ATH::Exception::NotFound.new("Post not found")
      end
    end

    # GET /api/posts/:id/comments - Get comments for a post
    @[ARTA::Get("/api/posts/{id}/comments")]
    def post_comments(id : String) : Array(NamedTuple(id: String?, body: String?, user_id: String?, created_at: Time?))
      post = Blog::Post.find_by("id", id)

      unless post && post.published
        raise ATH::Exception::NotFound.new("Post not found")
      end

      post.comments.map do |comment|
        {
          id:         comment.id,
          body:       comment.body,
          user_id:    comment.user_id,
          created_at: comment.created_at,
        }
      end
    end

    # GET /api/stats - Blog statistics
    @[ARTA::Get("/api/stats")]
    def stats : NamedTuple(posts: NamedTuple(total: Int32, published: Int32, drafts: Int32), users: Int32, comments: Int32)
      all_posts = Blog::Post.all
      published_posts = Blog::Post.find_all_with_query(Blog::Post.published)

      {
        posts: {
          total:     all_posts.size,
          published: published_posts.size,
          drafts:    all_posts.size - published_posts.size,
        },
        users:    Blog::User.all.size,
        comments: Blog::Comment.all.size,
      }
    end

    # GET /api/health - Health check endpoint demonstrating Ralph service usage
    @[ARTA::Get("/api/health")]
    def health_check : NamedTuple(status: String, database: Bool, cache: NamedTuple(enabled: Bool, hit_rate: Float64, size: Int32))
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

    # GET /api/pool - Connection pool information (for monitoring/debugging)
    @[ARTA::Get("/api/pool")]
    def pool_info : Hash(String, String | Int32 | Float64 | Bool)
      @ralph.pool_info
    end

    # POST /api/cache/clear - Clear the query cache (admin endpoint)
    @[ARTA::Post("/api/cache/clear")]
    def clear_cache : NamedTuple(status: String, message: String)
      @ralph.clear_cache
      {
        status:  "ok",
        message: "Query cache cleared",
      }
    end
  end
end

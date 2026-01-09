module Blog::Controllers
  @[ADI::Register]
  class PostsController < ATH::Controller
    include Blog::ViewHelpers

    @session_service : Blog::SessionService
    @ralph : Ralph::Athena::Service
    @flash_success : String?
    @flash_error : String?
    @flash_info : String?
    @current_user : Blog::User?
    @page_title : String?
    @show_author : Bool
    @posts : Array(Blog::Post)
    @post : Blog::Post
    @comments : Array(Blog::Comment)
    @errors : Array(String)

    def initialize(
      @session_service : Blog::SessionService,
      @ralph : Ralph::Athena::Service,
    )
      @flash_success = nil
      @flash_error = nil
      @flash_info = nil
      @current_user = nil
      @page_title = nil
      @show_author = true
      @posts = [] of Blog::Post
      @post = Blog::Post.new
      @comments = [] of Blog::Comment
      @errors = [] of String
    end

    # GET / - Homepage - Posts Index
    @[ARTA::Get("/")]
    def index(request : ATH::Request) : ATH::Response
      session = @session_service.get_session(request)
      @current_user = @session_service.current_user(request)
      @flash_success = session.flash_success
      @flash_error = session.flash_error
      @flash_info = session.flash_info
      @page_title = nil
      @show_author = true

      @posts = if @current_user
                 Blog::Post.all.sort_by { |p| p.created_at || Time.utc }.reverse
               else
                 Blog::Post.find_all_with_query(Blog::Post.published).sort_by { |p| p.created_at || Time.utc }.reverse
               end

      response = render "src/views/posts/index.ecr", "src/views/layouts/application.ecr"
      @session_service.update_session(response, session)
      response
    end

    # GET /posts/new - New post form
    @[ARTA::Get("/posts/new")]
    def new_form(request : ATH::Request) : ATH::Response
      session = @session_service.get_session(request)
      @current_user = @session_service.current_user(request)

      unless @current_user
        new_session = Blog::SessionService::SessionData.new(
          user_id: session.user_id,
          return_to: "/posts/new"
        )
        response = redirect("/login")
        @session_service.set_session(response, new_session)
        return response
      end

      @flash_success = session.flash_success
      @flash_error = session.flash_error
      @flash_info = session.flash_info
      @page_title = "New Post"
      @post = Blog::Post.new
      @errors = [] of String

      response = render "src/views/posts/form.ecr", "src/views/layouts/application.ecr"
      @session_service.update_session(response, session)
      response
    end

    # POST /posts - Create post
    @[ARTA::Post("/posts")]
    def create(request : ATH::Request) : ATH::Response
      session = @session_service.get_session(request)
      @current_user = @session_service.current_user(request)

      unless @current_user
        return redirect("/login")
      end

      data = request.request_data
      title = data["title"]?.to_s
      body = data["body"]?.to_s
      published = data["published"]? == "true"

      @post = Blog::Post.new(title: title, body: body, published: published)
      current_user_id = @current_user.not_nil!.id
      @post.user_id = current_user_id

      if @post.save
        # Invalidate posts cache after creating a new post
        @ralph.invalidate_cache("posts")

        new_session = Blog::SessionService::SessionData.new(
          user_id: session.user_id,
          flash_success: "Post created successfully!"
        )
        response = redirect("/posts/#{@post.id}")
        @session_service.set_session(response, new_session)
        response
      else
        @flash_success = session.flash_success
        @flash_error = session.flash_error
        @flash_info = session.flash_info
        @page_title = "New Post"
        @errors = @post.errors.full_messages

        render "src/views/posts/form.ecr", "src/views/layouts/application.ecr"
      end
    end

    # GET /posts/:id - Show post
    @[ARTA::Get("/posts/{id}")]
    def show(request : ATH::Request, id : String) : ATH::Response
      session = @session_service.get_session(request)
      @current_user = @session_service.current_user(request)
      @flash_success = session.flash_success
      @flash_error = session.flash_error
      @flash_info = session.flash_info

      post = Blog::Post.find_by("id", id)

      if post.nil?
        raise ATH::Exception::NotFound.new("Post not found")
      end

      @post = post

      # Check access for drafts
      current_user_id = @current_user.try(&.id)
      if !@post.published && (current_user_id.nil? || current_user_id != @post.user_id)
        raise ATH::Exception::NotFound.new("Post not found")
      end

      @comments = @post.comments
      @page_title = @post.title

      response = render "src/views/posts/show.ecr", "src/views/layouts/application.ecr"
      @session_service.update_session(response, session)
      response
    end

    # GET /posts/:id/edit - Edit post form
    @[ARTA::Get("/posts/{id}/edit")]
    def edit_form(request : ATH::Request, id : String) : ATH::Response
      session = @session_service.get_session(request)
      @current_user = @session_service.current_user(request)

      unless @current_user
        new_session = Blog::SessionService::SessionData.new(
          user_id: session.user_id,
          return_to: "/posts/#{id}/edit"
        )
        response = redirect("/login")
        @session_service.set_session(response, new_session)
        return response
      end

      post = Blog::Post.find_by("id", id)

      current_user_id = @current_user.try(&.id)
      if post.nil? || current_user_id != post.user_id
        new_session = Blog::SessionService::SessionData.new(
          user_id: session.user_id,
          flash_error: "Post not found or you don't have permission to edit it."
        )
        response = redirect("/")
        @session_service.set_session(response, new_session)
        return response
      end

      @post = post
      @flash_success = session.flash_success
      @flash_error = session.flash_error
      @flash_info = session.flash_info
      @page_title = "Edit Post"
      @errors = [] of String

      response = render "src/views/posts/form.ecr", "src/views/layouts/application.ecr"
      @session_service.update_session(response, session)
      response
    end

    # POST /posts/:id - Update post
    @[ARTA::Post("/posts/{id}")]
    def update(request : ATH::Request, id : String) : ATH::Response
      session = @session_service.get_session(request)
      @current_user = @session_service.current_user(request)

      unless @current_user
        return redirect("/login")
      end

      post = Blog::Post.find_by("id", id)

      current_user_id = @current_user.try(&.id)
      if post.nil? || current_user_id != post.user_id
        new_session = Blog::SessionService::SessionData.new(
          user_id: session.user_id,
          flash_error: "Post not found or you don't have permission to edit it."
        )
        response = redirect("/")
        @session_service.set_session(response, new_session)
        return response
      end

      @post = post

      data = request.request_data
      @post.title = data["title"]?.to_s
      @post.body = data["body"]?.to_s
      @post.published = data["published"]? == "true"

      if @post.save
        # Invalidate posts cache after updating
        @ralph.invalidate_cache("posts")

        new_session = Blog::SessionService::SessionData.new(
          user_id: session.user_id,
          flash_success: "Post updated successfully!"
        )
        response = redirect("/posts/#{@post.id}")
        @session_service.set_session(response, new_session)
        response
      else
        @flash_success = session.flash_success
        @flash_error = session.flash_error
        @flash_info = session.flash_info
        @page_title = "Edit Post"
        @errors = @post.errors.full_messages

        render "src/views/posts/form.ecr", "src/views/layouts/application.ecr"
      end
    end

    # POST /posts/:id/delete - Delete post
    @[ARTA::Post("/posts/{id}/delete")]
    def delete(request : ATH::Request, id : String) : ATH::Response
      session = @session_service.get_session(request)
      @current_user = @session_service.current_user(request)

      unless @current_user
        return redirect("/login")
      end

      post = Blog::Post.find_by("id", id)

      current_user_id = @current_user.try(&.id)
      if post.nil? || current_user_id != post.user_id
        new_session = Blog::SessionService::SessionData.new(
          user_id: session.user_id,
          flash_error: "Post not found or you don't have permission to delete it."
        )
        response = redirect("/")
        @session_service.set_session(response, new_session)
        return response
      end

      # Use transaction for deleting post and its comments
      @ralph.transaction do
        # Delete all comments first, then the post
        post.comments.each(&.destroy)
        post.destroy
      end

      # Invalidate caches after deletion
      @ralph.invalidate_cache("posts")
      @ralph.invalidate_cache("comments")

      new_session = Blog::SessionService::SessionData.new(
        user_id: session.user_id,
        flash_success: "Post deleted successfully."
      )
      response = redirect("/")
      @session_service.set_session(response, new_session)
      response
    end
  end
end

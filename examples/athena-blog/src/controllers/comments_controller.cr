module Blog::Controllers
  @[ADI::Register]
  class CommentsController < ATH::Controller
    def initialize(
      @session_service : Blog::SessionService,
      @ralph : Ralph::Athena::Service,
    )
    end

    # POST /posts/:id/comments - Create comment
    @[ARTA::Post("/posts/{post_id}/comments")]
    def create(request : ATH::Request, post_id : String) : ATH::Response
      session = @session_service.get_session(request)
      current_user = @session_service.current_user(request)

      unless current_user
        return redirect("/login")
      end

      post = Blog::Post.find_by("id", post_id)

      if post.nil?
        new_session = Blog::SessionService::SessionData.new(
          user_id: session.user_id,
          flash_error: "Post not found."
        )
        response = redirect("/")
        @session_service.set_session(response, new_session)
        return response
      end

      data = request.request_data
      body = data["body"]?.to_s

      comment = Blog::Comment.new(body: body)
      comment.user_id = current_user.id.not_nil!
      comment.post_id = post_id

      if comment.save
        # Invalidate comments cache after creating
        @ralph.invalidate_cache("comments")

        new_session = Blog::SessionService::SessionData.new(
          user_id: session.user_id,
          flash_success: "Comment added!"
        )
      else
        new_session = Blog::SessionService::SessionData.new(
          user_id: session.user_id,
          flash_error: "Could not add comment: #{comment.errors.full_messages.join(", ")}"
        )
      end

      response = redirect("/posts/#{post_id}")
      @session_service.set_session(response, new_session)
      response
    end

    # POST /comments/:id/delete - Delete comment
    @[ARTA::Post("/comments/{id}/delete")]
    def delete(request : ATH::Request, id : String) : ATH::Response
      session = @session_service.get_session(request)
      current_user = @session_service.current_user(request)

      unless current_user
        return redirect("/login")
      end

      comment = Blog::Comment.find_by("id", id)

      if comment.nil? || comment.user_id != current_user.id
        new_session = Blog::SessionService::SessionData.new(
          user_id: session.user_id,
          flash_error: "Comment not found or you don't have permission to delete it."
        )
        response = redirect("/")
        @session_service.set_session(response, new_session)
        return response
      end

      post_id = comment.post_id
      comment.destroy

      # Invalidate comments cache after deleting
      @ralph.invalidate_cache("comments")

      new_session = Blog::SessionService::SessionData.new(
        user_id: session.user_id,
        flash_success: "Comment deleted."
      )
      response = redirect("/posts/#{post_id}")
      @session_service.set_session(response, new_session)
      response
    end
  end
end

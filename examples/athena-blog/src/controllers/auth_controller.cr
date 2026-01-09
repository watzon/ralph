module Blog::Controllers
  @[ADI::Register]
  class AuthController < ATH::Controller
    include Blog::ViewHelpers

    @session_service : Blog::SessionService
    @ralph : Ralph::Athena::Service
    @flash_success : String?
    @flash_error : String?
    @flash_info : String?
    @error : String?
    @email : String
    @current_user : Blog::User?
    @page_title : String
    @username : String
    @errors : Array(String)

    def initialize(
      @session_service : Blog::SessionService,
      @ralph : Ralph::Athena::Service,
    )
      @flash_success = nil
      @flash_error = nil
      @flash_info = nil
      @error = nil
      @email = ""
      @current_user = nil
      @page_title = ""
      @username = ""
      @errors = [] of String
    end

    # GET /login - Show login form
    @[ARTA::Get("/login")]
    def login_form(request : ATH::Request) : ATH::Response
      session = @session_service.get_session(request)

      # Redirect if already logged in
      if @current_user = @session_service.current_user(request)
        return redirect("/")
      end

      @flash_success = session.flash_success
      @flash_error = session.flash_error
      @flash_info = session.flash_info
      @error = nil
      @email = ""
      @current_user = nil
      @page_title = "Login"

      response = render "src/views/auth/login.ecr", "src/views/layouts/application.ecr"
      @session_service.update_session(response, session)
      response
    end

    # POST /login - Handle login
    @[ARTA::Post("/login")]
    def login(request : ATH::Request) : ATH::Response
      data = request.request_data
      email = data["email"]?.to_s
      password = data["password"]?.to_s

      if user = Blog::User.authenticate(email, password)
        session = @session_service.get_session(request)
        return_to = session.return_to
        return_to = "/" if return_to.nil? || return_to.empty?

        new_session = Blog::SessionService::SessionData.new(
          user_id: user.id,
          flash_success: "Welcome back, #{user.username}!",
          return_to: nil
        )

        response = redirect(return_to)
        @session_service.set_session(response, new_session)
        response
      else
        # Login failed - re-render form with error
        session = @session_service.get_session(request)
        @flash_success = session.flash_success
        @flash_error = session.flash_error
        @flash_info = session.flash_info
        @error = "Invalid email or password"
        @email = email
        @current_user = nil
        @page_title = "Login"

        render "src/views/auth/login.ecr", "src/views/layouts/application.ecr"
      end
    end

    # GET /register - Show registration form
    @[ARTA::Get("/register")]
    def register_form(request : ATH::Request) : ATH::Response
      session = @session_service.get_session(request)

      # Redirect if already logged in
      if @current_user = @session_service.current_user(request)
        return redirect("/")
      end

      @flash_success = session.flash_success
      @flash_error = session.flash_error
      @flash_info = session.flash_info
      @errors = [] of String
      @username = ""
      @email = ""
      @current_user = nil
      @page_title = "Register"

      response = render "src/views/auth/register.ecr", "src/views/layouts/application.ecr"
      @session_service.update_session(response, session)
      response
    end

    # POST /register - Handle registration
    @[ARTA::Post("/register")]
    def register(request : ATH::Request) : ATH::Response
      data = request.request_data
      username = data["username"]?.to_s
      email = data["email"]?.to_s
      password = data["password"]?.to_s
      password_confirmation = data["password_confirmation"]?.to_s

      errors = [] of String

      if password != password_confirmation
        errors << "Passwords do not match"
      end

      if password.size < 6
        errors << "Password must be at least 6 characters"
      end

      if Blog::User.find_by_email(email)
        errors << "Email is already taken"
      end

      if Blog::User.find_by_username(username)
        errors << "Username is already taken"
      end

      if errors.empty?
        user = Blog::User.new(username: username, email: email)
        user.password = password

        # Use transaction for user creation (good practice for multi-step operations)
        @ralph.transaction do
          if user.save
            # Invalidate users cache after registration
            @ralph.invalidate_cache("users")

            new_session = Blog::SessionService::SessionData.new(
              user_id: user.id,
              flash_success: "Welcome to Ralph Blog, #{user.username}!"
            )

            response = redirect("/")
            @session_service.set_session(response, new_session)
            return response
          else
            errors = user.errors.full_messages
          end
        end
      end

      # Registration failed - re-render form with errors
      session = @session_service.get_session(request)
      @flash_success = session.flash_success
      @flash_error = session.flash_error
      @flash_info = session.flash_info
      @errors = errors
      @username = username
      @email = email
      @current_user = nil
      @page_title = "Register"

      render "src/views/auth/register.ecr", "src/views/layouts/application.ecr"
    end

    # GET /logout - Log out
    @[ARTA::Get("/logout")]
    def logout(request : ATH::Request) : ATH::Response
      new_session = Blog::SessionService::SessionData.new(
        flash_info: "You have been logged out."
      )

      response = redirect("/")
      @session_service.set_session(response, new_session)
      response
    end
  end
end

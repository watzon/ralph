require "kemal"

# Load models first (they define Blog module and model classes)
require "./models/user"
require "./models/post"
require "./models/comment"

# Load configuration (Ralph, sessions)
require "./config"

# Load views (depends on models being loaded)
require "./views/base"

# Load routes (depends on models, config, and views)
require "./routes/auth"
require "./routes/posts"
require "./routes/comments"
require "./routes/api"

# Serve static files from public directory
public_folder "public"

Kemal.run

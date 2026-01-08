#!/usr/bin/env crystal

# Seed file for the Blog example
# Run with: ./ralph.cr db:seed

require "ralph"
require "ralph/backends/sqlite"
require "../src/models/user"
require "../src/models/post"
require "../src/models/comment"

# Configure database connection
ENV["DATABASE_URL"] ||= "sqlite3://./blog.sqlite3"
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new(ENV["DATABASE_URL"])
end

puts "Seeding database..."

# Create demo user (find existing or create new)
puts "Creating demo user..."
demo_user = Blog::User.find_or_initialize_by({"username" => "demo"}) do |u|
  u.email = "demo@example.com"
  u.password = "password123"
end

if demo_user.new_record?
  if demo_user.save
    puts "  Created user: #{demo_user.username} (#{demo_user.email})"
  else
    puts "  Failed to create demo user: #{demo_user.errors.full_messages.join(", ")}"
    puts "  Aborting seed"
    exit 1
  end
else
  puts "  Using existing demo user"
end

# Create author user (find existing or create new)
puts "Creating author user..."
author = Blog::User.find_or_initialize_by({"username" => "author"}) do |u|
  u.email = "author@example.com"
  u.password = "password123"
end

if author.new_record?
  if author.save
    puts "  Created user: #{author.username} (#{author.email})"
  else
    puts "  Failed to create author user: #{author.errors.full_messages.join(", ")}"
    puts "  Continuing without author user..."
  end
else
  puts "  Using existing author user"
end

# Create blog posts for demo user
puts "Creating blog posts..."

posts_data = [
  {
    title:     "Welcome to Ralph Blog",
    body:      "This is the first post on our Ralph-powered blog! Ralph is an Active Record-style ORM for Crystal that makes database interactions a breeze.\n\nWith Ralph, you get:\n- Type-safe models and queries\n- Flexible associations (belongs_to, has_many, has_one)\n- Powerful validations\n- Database migrations\n- And much more!",
    published: true,
  },
  {
    title:     "Understanding UUID Primary Keys",
    body:      "This blog example demonstrates Ralph's support for UUID primary keys. Instead of auto-incrementing integers, each record gets a universally unique identifier.\n\nBenefits of UUIDs:\n- No collisions across distributed systems\n- Can generate IDs client-side\n- Harder to enumerate/guess\n- Better for eventual consistency scenarios",
    published: true,
  },
  {
    title:     "Draft: Upcoming Features",
    body:      "This is a draft post that won't be visible to the public. We're working on some exciting new features for the blog:\n\n- Rich text editing\n- Image uploads\n- Post categories and tags\n- Comment moderation",
    published: false,
  },
]

posts_data.each do |data|
  # Find existing post by title or initialize new one
  post = Blog::Post.find_or_initialize_by({"title" => data[:title]}) do |p|
    p.body = data[:body]
    p.published = data[:published]
    p.user_id = demo_user.id
  end

  if post.new_record?
    if post.save
      status = data[:published] ? "published" : "draft"
      puts "  Created #{status} post: #{data[:title]}"
    else
      puts "  Failed to create post '#{data[:title]}': #{post.errors.full_messages.join(", ")}"
    end
  else
    puts "  Post already exists: #{data[:title]}"
  end
end

# Create a post for the author user
author_post = Blog::Post.find_or_initialize_by({"title" => "Guest Post: Crystal Language Tips"}) do |p|
  p.body = "Crystal is a wonderful language that combines Ruby-like syntax with the performance of compiled languages. Here are some tips:\n\n1. Use type inference when possible\n2. Leverage macros for metaprogramming\n3. Take advantage of the standard library\n4. Profile before optimizing"
  p.published = true
  p.user_id = author.id
end

if author_post.new_record?
  if author_post.save
    puts "  Created published post: #{author_post.title}"
  else
    puts "  Failed to create author post: #{author_post.errors.full_messages.join(", ")}"
  end
else
  puts "  Post already exists: #{author_post.title}"
end

puts ""
puts "Seed complete!"
puts ""
puts "Login credentials:"
puts "  Username: demo / Password: password123"
puts "  Username: author / Password: password123"

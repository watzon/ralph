require "./spec_helper"

module Ralph
  class SimpleModel < Model
    table "users"
    column id, Int64
    column name, String
  end
end

puts "SimpleModel compiled successfully!"

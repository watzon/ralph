#!/usr/bin/env crystal

# Custom Ralph CLI Example
#
# This example shows how to create a custom Ralph CLI with custom paths
# for migrations and model generation.
#
# Usage:
#   1. Add ralph to your shard.yml dependencies
#   2. Copy this file to your project root as `ralph.cr`
#   3. Customize the paths below
#   4. Build: crystal build ralph.cr -o bin/ralph
#   5. Run: ./bin/ralph [commands]
#
# Note: In a real project, you would use:
#   require "ralph"
# This example uses a relative path for demonstration purposes.

require "../src/ralph"

# Create a custom CLI runner with your preferred paths
Ralph::Cli::Runner.new(
  migrations_dir: "./db/migrations", # Where migrations are stored and read from
  models_dir: "./src/my_app/models"  # Where models are generated
).run

# You can also override these paths at runtime with flags:
#
#   ./bin/ralph g:model User name:string -m ./other/migrations --models ./other/models
#
# The initialization values serve as defaults, and CLI flags override them.

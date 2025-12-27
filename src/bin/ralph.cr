#!/usr/bin/env crystal

require "../ralph"

# CLI requires both backends to be available
require "../ralph/backends/sqlite"
require "../ralph/backends/postgres"

Ralph::Cli::Runner.new.run

# Full test for db:pull with all tables
require "./src/ralph"
require "./src/ralph/backends/postgres"
require "./src/ralph/cli/association_inferrer"
require "./src/ralph/cli/generators/pulled_model_generator"
require "./src/ralph/cli/schema_puller"

db = Ralph::Database::PostgresBackend.new("postgres://postgres@localhost:5432/butterbase_js")
output_dir = "/tmp/ralph_models_v4"

puts "Generating models for ALL tables..."
puts ""

puller = Ralph::Cli::SchemaPuller.new(
  db: db,
  output_dir: output_dir,
  tables: nil,                                                             # All tables
  skip_tables: ["adonis_schema", "adonis_schema_versions", "rate_limits"], # Skip framework tables
  overwrite: true,
  output: STDOUT
)

puller.run

puts ""
puts "=" * 60
puts "Sample models:"
puts "=" * 60

# Athena Framework integration - DI Service
#
# Provides a dependency-injectable service for accessing Ralph's database
# functionality within Athena controllers and services.
#
# ## Example
#
# ```
# require "ralph/plugins/athena"
#
# class UsersController < ATH::Controller
#   def initialize(@ralph : Ralph::Athena::Service)
#   end
#
#   @[ARTA::Get("/users")]
#   def index : Array(User)
#     User.all.to_a
#   end
#
#   @[ARTA::Post("/users")]
#   def create(request : ATH::Request) : User
#     @ralph.transaction do
#       user = User.new(name: "Alice")
#       user.save!
#       user
#     end
#   end
# end
# ```
module Ralph::Athena
  # A dependency-injectable service that provides access to Ralph's database
  # functionality within Athena applications.
  #
  # This service is automatically registered with Athena's DI container when
  # you `require "ralph/plugins/athena"`.
  #
  # ## Injection
  #
  # Inject this service into your controllers or other services:
  #
  # ```
  # class MyController < ATH::Controller
  #   def initialize(@ralph : Ralph::Athena::Service)
  #   end
  # end
  # ```
  #
  # ## Features
  #
  # - Access to the configured database backend
  # - Transaction helpers with automatic rollback on exceptions
  # - Connection pool statistics
  # - Health check support
  @[ADI::Register]
  class Service
    # Returns the configured Ralph database backend.
    #
    # ## Example
    #
    # ```
    # @ralph.database.execute("SELECT 1")
    # ```
    def database : Ralph::Database::Backend
      Ralph.database
    end

    # Execute a block within a database transaction.
    #
    # If the block raises an exception, the transaction is rolled back.
    # Otherwise, the transaction is committed when the block completes.
    #
    # ## Example
    #
    # ```
    # @ralph.transaction do
    #   user = User.create!(name: "Alice")
    #   profile = Profile.create!(user_id: user.id)
    # end
    # ```
    #
    # ## Nested Transactions
    #
    # Ralph supports nested transactions via savepoints:
    #
    # ```
    # @ralph.transaction do
    #   User.create!(name: "Alice")
    #
    #   @ralph.transaction do
    #     # This creates a savepoint
    #     Post.create!(title: "Hello")
    #   end
    # end
    # ```
    #
    # ## Note
    #
    # This method wraps `Ralph::Model.transaction`. You can use any model
    # class's `.transaction` method directly if preferred:
    #
    # ```
    # User.transaction do
    #   # ...
    # end
    # ```
    def transaction(&)
      # Use the Transactions module directly to avoid needing a specific model class
      Ralph::Transactions.transaction_depth += 1
      db = Ralph.database

      begin
        if Ralph::Transactions.transaction_depth > 1
          savepoint_name = "savepoint_#{Ralph::Transactions.transaction_depth}"

          begin
            db.execute(db.savepoint_sql(savepoint_name))
            yield
            db.execute(db.release_savepoint_sql(savepoint_name))
          rescue ex : Exception
            db.execute(db.rollback_to_savepoint_sql(savepoint_name))
            db.execute(db.release_savepoint_sql(savepoint_name))
            raise ex
          end
        else
          Ralph::Transactions.transaction_committed = false

          begin
            db.execute(db.begin_transaction_sql)

            begin
              yield
              db.execute(db.commit_sql)
              Ralph::Transactions.transaction_committed = true

              Ralph::Transactions.run_after_commit_callbacks
            rescue ex : Exception
              begin
                db.execute(db.rollback_sql)
              rescue
              end
              Ralph::Transactions.transaction_committed = false
              Ralph::Transactions.run_after_rollback_callbacks
              raise ex
            end
          end
        end
      ensure
        Ralph::Transactions.transaction_depth -= 1 if Ralph::Transactions.transaction_depth > 0

        if Ralph::Transactions.transaction_depth == 0
          Ralph::Transactions.clear_transaction_callbacks
        end
      end
    end

    # Check if the database connection pool is healthy.
    #
    # Performs a simple health check query to verify database connectivity.
    #
    # ## Example
    #
    # ```
    # @[ARTA::Get("/health")]
    # def health_check : NamedTuple(status: String, database: Bool)
    #   {status: "ok", database: @ralph.healthy?}
    # end
    # ```
    def healthy? : Bool
      Ralph.pool_healthy?
    end

    # Get connection pool statistics.
    #
    # Returns pool statistics if available, nil otherwise.
    #
    # ## Example
    #
    # ```
    # if stats = @ralph.pool_stats
    #   puts "Open connections: #{stats.open_connections}"
    # end
    # ```
    def pool_stats : Ralph::Database::PoolStats?
      Ralph.pool_stats
    end

    # Get detailed pool information including configuration.
    #
    # ## Example
    #
    # ```
    # @[ARTA::Get("/admin/pool-info")]
    # def pool_info
    #   @ralph.pool_info
    # end
    # ```
    def pool_info : Hash(String, String | Int32 | Float64 | Bool)
      Ralph.pool_info
    end

    # Clear the query cache.
    #
    # Useful after bulk updates or when you need fresh data.
    def clear_cache : Nil
      Ralph.clear_cache
    end

    # Invalidate cached queries for a specific table.
    #
    # ## Parameters
    #
    # - `table`: The table name to invalidate
    #
    # ## Returns
    #
    # The number of cache entries invalidated.
    def invalidate_cache(table : String) : Int32
      Ralph.invalidate_table_cache(table)
    end
  end
end

module Ralph
  # Transaction support for models
  #
  # This module provides transaction management capabilities including:
  # - Model-level transactions (`Model.transaction { ... }`)
  # - Nested transaction support (savepoints)
  # - Transaction callbacks (after_commit, after_rollback)
  #
  # Example:
  # ```
  # User.transaction do
  #   user1 = User.create(name: "Alice")
  #   user2 = User.create(name: "Bob")
  #   # Both will be saved or both will be rolled back
  # end
  # ```
  module Transactions
    # Track current transaction depth for nested transactions
    @@transaction_depth : Int32 = 0

    # Track whether current transaction is committed or rolled back
    @@transaction_committed : Bool = true

    # Track after_commit callbacks
    @@after_commit_callbacks : Array(Proc(Nil)) = [] of Proc(Nil)

    # Track after_rollback callbacks
    @@after_rollback_callbacks : Array(Proc(Nil)) = [] of Proc(Nil)

    # Get the current transaction depth
    def self.transaction_depth : Int32
      @@transaction_depth
    end

    # Increment transaction depth
    def self.transaction_depth=(value : Int32)
      @@transaction_depth = value
    end

    # Check if currently in a transaction
    def self.in_transaction? : Bool
      @@transaction_depth > 0
    end

    # Check if the current transaction is committed (not rolled back)
    def self.transaction_committed? : Bool
      @@transaction_committed
    end

    # Setter for transaction committed state
    def self.transaction_committed=(value : Bool)
      @@transaction_committed = value
    end

    # Register an after_commit callback
    def self.after_commit(&block : Proc(Nil))
      if in_transaction?
        @@after_commit_callbacks << block
      else
        # If not in a transaction, execute immediately
        block.call
      end
    end

    # Register an after_rollback callback
    def self.after_rollback(&block : Proc(Nil))
      if in_transaction?
        @@after_rollback_callbacks << block
      else
        # If not in a transaction, this will never be called
        # so we just ignore it
      end
    end

    # Run after_commit callbacks
    def self.run_after_commit_callbacks
      callbacks = @@after_commit_callbacks.dup
      @@after_commit_callbacks.clear
      callbacks.each(&.call)
    end

    # Run after_rollback callbacks
    def self.run_after_rollback_callbacks
      callbacks = @@after_rollback_callbacks.dup
      @@after_rollback_callbacks.clear
      callbacks.each(&.call)
    end

    # Clear all transaction callbacks
    def self.clear_transaction_callbacks
      @@after_commit_callbacks.clear
      @@after_rollback_callbacks.clear
    end
  end

  # Extend Model class with transaction support
  class Model
    # Execute a block within a transaction
    #
    # If an exception is raised, the transaction is rolled back.
    # If no exception is raised, the transaction is committed.
    #
    # Example:
    # ```
    # User.transaction do
    #   user = User.create(name: "Alice")
    #   Post.create(title: "Hello", user_id: user.id)
    # end
    # ```
    def self.transaction
      Ralph::Transactions.transaction_depth += 1

      begin
        if Ralph::Transactions.transaction_depth > 1
          # Nested transaction - use savepoints
          savepoint_name = "savepoint_#{Ralph::Transactions.transaction_depth}"

          begin
            Ralph.database.execute("SAVEPOINT #{savepoint_name}")
            yield
            Ralph.database.execute("RELEASE SAVEPOINT #{savepoint_name}")
          rescue ex : Exception
            Ralph.database.execute("ROLLBACK TO SAVEPOINT #{savepoint_name}")
            Ralph.database.execute("RELEASE SAVEPOINT #{savepoint_name}")
            raise ex
          end
        else
          # Top-level transaction - use raw SQL to avoid yield-in-proc issue
          Ralph::Transactions.transaction_committed = false

          begin
            Ralph.database.execute("BEGIN")

            begin
              yield
              Ralph.database.execute("COMMIT")
              Ralph::Transactions.transaction_committed = true

              # Transaction committed successfully
              Ralph::Transactions.run_after_commit_callbacks
            rescue ex : Exception
              # Transaction was rolled back
              begin
                Ralph.database.execute("ROLLBACK")
              rescue
                # Ignore rollback errors
              end
              Ralph::Transactions.transaction_committed = false
              Ralph::Transactions.run_after_rollback_callbacks
              raise ex
            end
          end
        end
      ensure
        Ralph::Transactions.transaction_depth -= 1 if Ralph::Transactions.transaction_depth > 0

        # If we're back to depth 0, clear callbacks
        if Ralph::Transactions.transaction_depth == 0
          Ralph::Transactions.clear_transaction_callbacks
        end
      end
    end

    # Register an after_commit callback
    #
    # The callback will be executed after the current transaction commits.
    # If not in a transaction, the callback executes immediately.
    #
    # Example:
    # ```
    # class User < Ralph::Model
    #   after_commit :send_welcome_email
    #
    #   def send_welcome_email
    #     # Send email logic
    #   end
    # end
    # ```
    macro after_commit(method_name)
      {% if @type.has_constant?("_ralph_after_commit_callbacks") %}
        @@_ralph_after_commit_callbacks << {{method_name}}
      {% else %}
        @@_ralph_after_commit_callbacks = [] of Symbol
        @@_ralph_after_commit_callbacks << {{method_name}}

        def self._ralph_run_after_commit_callbacks
          @@_ralph_after_commit_callbacks.each do |callback|
            self.new.send(callback)
          end
        end

        after_initialize -> do
          Ralph::Transactions.after_commit -> do
            self.class._ralph_run_after_commit_callbacks
          end
        end
      {% end %}
    end

    # Register an after_rollback callback
    #
    # The callback will be executed if the current transaction is rolled back.
    #
    # Example:
    # ```
    # class User < Ralph::Model
    #   after_rollback :log_rollback
    #
    #   def log_rollback
    #     # Log rollback logic
    #   end
    # end
    # ```
    macro after_rollback(method_name)
      {% if @type.has_constant?("_ralph_after_rollback_callbacks") %}
        @@_ralph_after_rollback_callbacks << {{method_name}}
      {% else %}
        @@_ralph_after_rollback_callbacks = [] of Symbol
        @@_ralph_after_rollback_callbacks << {{method_name}}

        def self._ralph_run_after_rollback_callbacks
          @@_ralph_after_rollback_callbacks.each do |callback|
            self.new.send(callback)
          end
        end

        after_initialize -> do
          Ralph::Transactions.after_rollback -> do
            self.class._ralph_run_after_rollback_callbacks
          end
        end
      {% end %}
    end
  end
end

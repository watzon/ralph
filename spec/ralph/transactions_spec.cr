require "../spec_helper"
require "../ralph/test_helper"

module Ralph
  module TransactionTests
    # Test models for transactions

    class User < Model
      table "trans_test_users"

      column id, Int64, primary: true
      column name, String
      column email, String?
    end

    class Post < Model
      table "trans_test_posts"

      column id, Int64, primary: true
      column title, String
      column user_id, Int64?
    end
  end

  describe "Transactions" do
    before_all do
      RalphTestHelper.setup_test_database

      # Create test tables
      TestSchema.create_table("trans_test_users") do |t|
        t.primary_key
        t.string("name")
        t.string("email")
      end

      TestSchema.create_table("trans_test_posts") do |t|
        t.primary_key
        t.string("title")
        t.bigint("user_id")
      end
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    before_each do
      # Clean tables before each test
      Ralph.database.execute("DELETE FROM trans_test_users")
      Ralph.database.execute("DELETE FROM trans_test_posts")
    end

    describe "Model.transaction" do
      it "commits changes when no exception is raised" do
        TransactionTests::User.transaction do
          user1 = TransactionTests::User.create(name: "Alice")
          user2 = TransactionTests::User.create(name: "Bob")
        end

        count = TransactionTests::User.count
        count.should eq(2)
      end

      it "rolls back changes when an exception is raised" do
        begin
          TransactionTests::User.transaction do
            TransactionTests::User.create(name: "Alice")
            TransactionTests::User.create(name: "Bob")
            raise "Intentional error"
          end
        rescue
          # Expected exception
        end

        count = TransactionTests::User.count
        count.should eq(0)
      end

      it "persists related records atomically" do
        user_id = nil

        TransactionTests::User.transaction do
          user = TransactionTests::User.create(name: "Alice")
          user_id = user.id
          TransactionTests::Post.create(title: "Hello", user_id: user.id)
          TransactionTests::Post.create(title: "World", user_id: user.id)
        end

        user = TransactionTests::User.find(user_id.not_nil!)
        user.should_not be_nil

        posts = TransactionTests::Post.all
        posts.size.should eq(2)
      end

      it "rolls back related records on failure" do
        begin
          TransactionTests::User.transaction do
            user = TransactionTests::User.create(name: "Alice")
            TransactionTests::Post.create(title: "Hello", user_id: user.id)
            raise "Intentional error"
          end
        rescue
          # Expected exception
        end

        TransactionTests::User.count.should eq(0)
        TransactionTests::Post.count.should eq(0)
      end

      it "works with updates" do
        user = TransactionTests::User.create(name: "Alice")

        TransactionTests::User.transaction do
          user.update(name: "Bob")
          TransactionTests::User.create(name: "Charlie")
        end

        user.reload
        user.name.should eq("Bob")
        TransactionTests::User.count.should eq(2)
      end

      it "works with deletes" do
        user1 = TransactionTests::User.create(name: "Alice")
        user2 = TransactionTests::User.create(name: "Bob")

        TransactionTests::User.transaction do
          user1.destroy
          user2.destroy
        end

        TransactionTests::User.count.should eq(0)
      end
    end

    describe "Nested Transactions" do
      it "supports nested transactions with savepoints" do
        TransactionTests::User.transaction do
          user1 = TransactionTests::User.create(name: "Alice")

          TransactionTests::User.transaction do
            user2 = TransactionTests::User.create(name: "Bob")
          end

          TransactionTests::User.count.should eq(2)
        end

        TransactionTests::User.count.should eq(2)
      end

      it "rolls back inner transaction without affecting outer" do
        TransactionTests::User.transaction do
          user1 = TransactionTests::User.create(name: "Alice")

          begin
            TransactionTests::User.transaction do
              TransactionTests::User.create(name: "Bob")
              raise "Inner error"
            end
          rescue
            # Expected inner exception
          end

          # Only Alice should exist at this point
          TransactionTests::User.count.should eq(1)
        end

        # Outer transaction should commit
        TransactionTests::User.count.should eq(1)
        TransactionTests::User.first.not_nil!.name.should eq("Alice")
      end

      it "rolls back outer transaction when it fails" do
        begin
          TransactionTests::User.transaction do
            TransactionTests::User.create(name: "Alice")

            TransactionTests::User.transaction do
              TransactionTests::User.create(name: "Bob")
            end

            raise "Outer error"
          end
        rescue
          # Expected exception
        end

        # Everything should be rolled back
        TransactionTests::User.count.should eq(0)
      end

      it "supports multiple levels of nesting" do
        TransactionTests::User.transaction do
          TransactionTests::User.create(name: "Level 1")

          TransactionTests::User.transaction do
            TransactionTests::User.create(name: "Level 2")

            TransactionTests::User.transaction do
              TransactionTests::User.create(name: "Level 3")
            end

            # After Level 3 savepoint is released, all 3 records are visible
            TransactionTests::User.count.should eq(3)
          end

          TransactionTests::User.count.should eq(3)
        end

        TransactionTests::User.count.should eq(3)
      end

      it "handles rollback at any nesting level" do
        TransactionTests::User.transaction do
          TransactionTests::User.create(name: "Alice")

          begin
            TransactionTests::User.transaction do
              TransactionTests::User.create(name: "Bob")

              begin
                TransactionTests::User.transaction do
                  TransactionTests::User.create(name: "Charlie")
                  raise "Level 3 error"
                end
              rescue
                # Level 3 error
              end

              # Charlie should be rolled back
              TransactionTests::User.count.should eq(2)
            end
          rescue
            # Should not reach here
          end

          TransactionTests::User.count.should eq(2)
        end

        # Alice and Bob should be committed
        TransactionTests::User.count.should eq(2)
      end
    end

    describe "Transaction State" do
      it "knows when in a transaction" do
        Ralph::Transactions.in_transaction?.should be_false

        TransactionTests::User.transaction do
          Ralph::Transactions.in_transaction?.should be_true
        end

        Ralph::Transactions.in_transaction?.should be_false
      end

      it "tracks transaction depth correctly" do
        Ralph::Transactions.transaction_depth.should eq(0)

        TransactionTests::User.transaction do
          Ralph::Transactions.transaction_depth.should eq(1)

          TransactionTests::User.transaction do
            Ralph::Transactions.transaction_depth.should eq(2)
          end

          Ralph::Transactions.transaction_depth.should eq(1)
        end

        Ralph::Transactions.transaction_depth.should eq(0)
      end
    end

    describe "after_commit callback" do
      it "executes callback after successful commit" do
        callback_called = false
        user_id = 0_i64

        TransactionTests::User.transaction do
          user = TransactionTests::User.create(name: "Alice")
          user_id = user.id

          Ralph::Transactions.after_commit do
            callback_called = true
          end
        end

        callback_called.should be_true
      end

      it "does not execute callback after rollback" do
        callback_called = false

        begin
          TransactionTests::User.transaction do
            TransactionTests::User.create(name: "Alice")

            Ralph::Transactions.after_commit do
              callback_called = true
            end

            raise "Intentional error"
          end
        rescue
          # Expected
        end

        callback_called.should be_false
      end

      it "executes callback immediately when not in transaction" do
        callback_called = false

        Ralph::Transactions.after_commit do
          callback_called = true
        end

        callback_called.should be_true
      end

      it "executes all registered callbacks in order" do
        results = [] of Int32

        TransactionTests::User.transaction do
          Ralph::Transactions.after_commit do
            results << 1
          end

          Ralph::Transactions.after_commit do
            results << 2
          end

          Ralph::Transactions.after_commit do
            results << 3
          end
        end

        results.should eq([1, 2, 3])
      end
    end

    describe "after_rollback callback" do
      it "executes callback after rollback" do
        callback_called = false

        begin
          TransactionTests::User.transaction do
            TransactionTests::User.create(name: "Alice")

            Ralph::Transactions.after_rollback do
              callback_called = true
            end

            raise "Intentional error"
          end
        rescue
          # Expected
        end

        callback_called.should be_true
      end

      it "does not execute callback after successful commit" do
        callback_called = false

        TransactionTests::User.transaction do
          TransactionTests::User.create(name: "Alice")

          Ralph::Transactions.after_rollback do
            callback_called = true
          end
        end

        callback_called.should be_false
      end

      it "does not execute callback when not in transaction" do
        callback_called = false

        Ralph::Transactions.after_rollback do
          callback_called = true
        end

        # Callbacks registered outside transaction are ignored
        callback_called.should be_false
      end

      it "executes all rollback callbacks in order" do
        results = [] of Int32

        begin
          TransactionTests::User.transaction do
            Ralph::Transactions.after_rollback do
              results << 1
            end

            Ralph::Transactions.after_rollback do
              results << 2
            end

            raise "Intentional error"
          end
        rescue
          # Expected
        end

        results.should eq([1, 2])
      end
    end

    describe "Complex Transaction Scenarios" do
      it "handles transfer operations atomically" do
        # Create users with balances
        user1 = TransactionTests::User.create(name: "Alice")
        user2 = TransactionTests::User.create(name: "Bob")

        # Simulate a transfer using posts as "money"
        TransactionTests::User.transaction do
          # Remove from user1
          TransactionTests::Post.create(title: "Payment1", user_id: user1.id)

          # Add to user2
          TransactionTests::Post.create(title: "Payment1", user_id: user2.id)
        end

        TransactionTests::Post.count.should eq(2)
        TransactionTests::Post.all.select { |p| p.user_id == user1.id }.size.should eq(1)
        TransactionTests::Post.all.select { |p| p.user_id == user2.id }.size.should eq(1)
      end

      it "rolls back complete transfer on error" do
        user1 = TransactionTests::User.create(name: "Alice")
        user2 = TransactionTests::User.create(name: "Bob")

        begin
          TransactionTests::User.transaction do
            TransactionTests::Post.create(title: "Payment1", user_id: user1.id)
            raise "Transfer failed"
          end
        rescue
          # Expected
        end

        TransactionTests::Post.count.should eq(0)
      end

      it "handles conditional operations within transaction" do
        user = TransactionTests::User.create(name: "Alice")

        TransactionTests::User.transaction do
          if user.name == "Alice"
            TransactionTests::Post.create(title: "Hello", user_id: user.id)
          else
            TransactionTests::Post.create(title: "Goodbye", user_id: user.id)
          end
        end

        TransactionTests::Post.count.should eq(1)
        TransactionTests::Post.first.not_nil!.title.should eq("Hello")
      end
    end
  end
end

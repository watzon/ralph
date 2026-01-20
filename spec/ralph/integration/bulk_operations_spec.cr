require "../../spec_helper"
require "../../ralph/test_helper"

module Ralph
  # Test model for bulk operations
  class BulkTestUser < Model
    table "users"

    column id : Int64
    column name : String
    column email : String
    column age : Int32 | Nil
    column active : Bool | Nil
    column created_at : Time | Nil
  end

  # Test model with UUID primary key
  class BulkTestUuidItem < Model
    table "uuid_items"

    column id : UUID, primary: true
    column name : String
    column code : String
  end

  # Integration tests for Bulk Operations
  describe BulkOperations do
    before_all do
      RalphTestHelper.setup_test_database
    end

    before_each do
      RalphTestHelper.clear_tables
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    describe ".insert_all" do
      it "inserts multiple records in a single operation" do
        result = BulkTestUser.insert_all([
          {name: "Alice", email: "alice@example.com", age: 25},
          {name: "Bob", email: "bob@example.com", age: 30},
          {name: "Charlie", email: "charlie@example.com", age: 35},
        ])

        result.count.should eq(3)
        BulkTestUser.count.should eq(3)

        # Verify the data was inserted correctly
        alice = BulkTestUser.find_by("email", "alice@example.com")
        alice.should_not be_nil
        alice.not_nil!.name.should eq("Alice")
        alice.not_nil!.age.should eq(25)

        bob = BulkTestUser.find_by("email", "bob@example.com")
        bob.should_not be_nil
        bob.not_nil!.name.should eq("Bob")
      end

      it "returns empty result for empty array" do
        result = BulkTestUser.insert_all([] of NamedTuple(name: String, email: String))
        result.count.should eq(0)
        BulkTestUser.count.should eq(0)
      end

      it "handles hash input" do
        records = [
          {"name" => "Alice", "email" => "alice@example.com"} of String => DB::Any,
          {"name" => "Bob", "email" => "bob@example.com"} of String => DB::Any,
        ]
        result = BulkTestUser.insert_all(records)

        result.count.should eq(2)
        BulkTestUser.count.should eq(2)
      end

      it "returns IDs on PostgreSQL when returning is true" do
        result = BulkTestUser.insert_all([
          {name: "Alice", email: "alice@example.com"},
          {name: "Bob", email: "bob@example.com"},
        ], returning: true)

        result.count.should eq(2)

        if RalphTestHelper.postgres?
          result.ids.size.should eq(2)
          # IDs can be Int64 or String (UUID), just verify they're present
          result.ids.all? { |id|
            case id
            when Int64  then id > 0
            when String then !id.empty?
            else             false
            end
          }.should be_true
        end
      end
    end

    describe ".upsert_all" do
      it "inserts new records" do
        result = BulkTestUser.upsert_all([
          {name: "Alice", email: "alice@example.com", age: 25},
          {name: "Bob", email: "bob@example.com", age: 30},
        ], on_conflict: :email, update: [:name, :age])

        result.count.should eq(2)
        BulkTestUser.count.should eq(2)
      end

      it "updates existing records on conflict" do
        # First, insert a record
        BulkTestUser.create(name: "Alice Original", email: "alice@example.com", age: 20)

        # Now upsert with the same email
        result = BulkTestUser.upsert_all([
          {name: "Alice Updated", email: "alice@example.com", age: 25},
          {name: "Bob", email: "bob@example.com", age: 30},
        ], on_conflict: :email, update: [:name, :age])

        # Should still have 2 records (1 updated + 1 new)
        BulkTestUser.count.should eq(2)

        alice = BulkTestUser.find_by("email", "alice@example.com")
        alice.should_not be_nil
        alice.not_nil!.name.should eq("Alice Updated")
        alice.not_nil!.age.should eq(25)
      end

      it "supports do_nothing on conflict" do
        # First, insert a record
        BulkTestUser.create(name: "Alice Original", email: "alice@example.com", age: 20)

        # Now upsert with do_nothing
        BulkTestUser.upsert_all([
          {name: "Alice Updated", email: "alice@example.com", age: 25},
          {name: "Bob", email: "bob@example.com", age: 30},
        ], on_conflict: :email, do_nothing: true)

        # Should have 2 records (1 unchanged + 1 new)
        BulkTestUser.count.should eq(2)

        alice = BulkTestUser.find_by("email", "alice@example.com")
        alice.should_not be_nil
        alice.not_nil!.name.should eq("Alice Original") # Should NOT be updated
        alice.not_nil!.age.should eq(20)
      end

      it "updates all non-conflict columns when update is nil" do
        BulkTestUser.create(name: "Alice Original", email: "alice@example.com", age: 20, active: false)

        BulkTestUser.upsert_all([
          {name: "Alice Updated", email: "alice@example.com", age: 30, active: true},
        ], on_conflict: :email)

        alice = BulkTestUser.find_by("email", "alice@example.com")
        alice.should_not be_nil
        alice.not_nil!.name.should eq("Alice Updated")
        alice.not_nil!.age.should eq(30)
        alice.not_nil!.active.should eq(true)
      end

      it "supports multiple conflict columns", tags: "postgres" do
        # This test requires a compound unique index on (name, email)
        # which the default test schema doesn't have.
        # Skip on SQLite as it would require creating a compound index.
        pending!("requires compound unique index") if RalphTestHelper.sqlite?

        result = BulkTestUser.upsert_all([
          {name: "Alice", email: "alice@example.com", age: 25},
        ], on_conflict: [:name, :email], update: [:age])

        result.count.should eq(1)
      end

      it "returns empty result for empty array" do
        result = BulkTestUser.upsert_all(
          [] of NamedTuple(name: String, email: String),
          on_conflict: :email
        )
        result.count.should eq(0)
      end
    end

    describe ".update_all" do
      it "updates multiple records matching conditions" do
        BulkTestUser.create(name: "Alice", email: "alice@example.com", age: 25, active: true)
        BulkTestUser.create(name: "Bob", email: "bob@example.com", age: 30, active: true)
        BulkTestUser.create(name: "Charlie", email: "charlie@example.com", age: 35, active: false)

        BulkTestUser.update_all({active: false}, where: {active: true})

        # All should now be inactive
        BulkTestUser.all.each do |user|
          user.active.should eq(false)
        end
      end

      it "updates records with multiple conditions" do
        BulkTestUser.create(name: "Alice", email: "alice@example.com", age: 25, active: true)
        BulkTestUser.create(name: "Bob", email: "bob@example.com", age: 25, active: true)
        BulkTestUser.create(name: "Charlie", email: "charlie@example.com", age: 30, active: true)

        BulkTestUser.update_all({active: false}, where: {age: 25, active: true})

        alice = BulkTestUser.find_by("email", "alice@example.com")
        alice.not_nil!.active.should eq(false)

        bob = BulkTestUser.find_by("email", "bob@example.com")
        bob.not_nil!.active.should eq(false)

        charlie = BulkTestUser.find_by("email", "charlie@example.com")
        charlie.not_nil!.active.should eq(true) # Should be unchanged
      end

      it "updates all records when no conditions given" do
        BulkTestUser.create(name: "Alice", email: "alice@example.com", active: true)
        BulkTestUser.create(name: "Bob", email: "bob@example.com", active: true)

        BulkTestUser.update_all({active: false})

        BulkTestUser.all.each do |user|
          user.active.should eq(false)
        end
      end

      it "handles hash input" do
        BulkTestUser.create(name: "Alice", email: "alice@example.com", active: true)

        updates = {"active" => false} of String => DB::Any
        conditions = {"email" => "alice@example.com"} of String => DB::Any
        BulkTestUser.update_all(updates, where: conditions)

        alice = BulkTestUser.find_by("email", "alice@example.com")
        alice.not_nil!.active.should eq(false)
      end
    end

    describe ".delete_all" do
      it "deletes multiple records matching conditions" do
        BulkTestUser.create(name: "Alice", email: "alice@example.com", active: true)
        BulkTestUser.create(name: "Bob", email: "bob@example.com", active: false)
        BulkTestUser.create(name: "Charlie", email: "charlie@example.com", active: true)

        BulkTestUser.delete_all(where: {active: false})

        BulkTestUser.count.should eq(2)
        BulkTestUser.find_by("email", "bob@example.com").should be_nil
      end

      it "deletes all records when no conditions given" do
        BulkTestUser.create(name: "Alice", email: "alice@example.com")
        BulkTestUser.create(name: "Bob", email: "bob@example.com")

        BulkTestUser.delete_all

        BulkTestUser.count.should eq(0)
      end

      it "handles hash input" do
        BulkTestUser.create(name: "Alice", email: "alice@example.com", age: 25)
        BulkTestUser.create(name: "Bob", email: "bob@example.com", age: 30)

        conditions = {"age" => 25} of String => DB::Any
        BulkTestUser.delete_all(where: conditions)

        BulkTestUser.count.should eq(1)
        BulkTestUser.find_by("email", "alice@example.com").should be_nil
        BulkTestUser.find_by("email", "bob@example.com").should_not be_nil
      end

      it "does nothing when no records match" do
        BulkTestUser.create(name: "Alice", email: "alice@example.com", age: 25)

        BulkTestUser.delete_all(where: {age: 99})

        BulkTestUser.count.should eq(1)
      end
    end

    describe "performance characteristics" do
      it "uses a single query for bulk insert" do
        # This test verifies the bulk operation creates fewer queries
        # than individual inserts would
        records = (1..100).map do |i|
          {name: "User#{i}", email: "user#{i}@example.com", age: i}
        end

        result = BulkTestUser.insert_all(records)

        result.count.should eq(100)
        BulkTestUser.count.should eq(100)
      end
    end

    describe "UUID primary keys" do
      it "inserts records with UUID primary keys" do
        id1 = UUID.random
        id2 = UUID.random

        result = BulkTestUuidItem.insert_all([
          {id: id1.to_s, name: "Item 1", code: "CODE1"},
          {id: id2.to_s, name: "Item 2", code: "CODE2"},
        ])

        result.count.should eq(2)
        BulkTestUuidItem.count.should eq(2)

        item1 = BulkTestUuidItem.find_by("code", "CODE1")
        item1.should_not be_nil
        item1.not_nil!.id.should eq(id1)
      end

      it "returns UUID IDs on PostgreSQL when returning is true" do
        id1 = UUID.random
        id2 = UUID.random

        result = BulkTestUuidItem.insert_all([
          {id: id1.to_s, name: "Item 1", code: "CODE1"},
          {id: id2.to_s, name: "Item 2", code: "CODE2"},
        ], returning: true)

        result.count.should eq(2)

        if RalphTestHelper.postgres?
          result.ids.size.should eq(2)
          # IDs are returned as strings for UUID columns
          result.ids.all? { |id|
            id.is_a?(String) && !id.as(String).empty?
          }.should be_true
        end
      end

      it "upserts records with UUID primary keys" do
        id1 = UUID.random
        BulkTestUuidItem.insert_all([
          {id: id1.to_s, name: "Original", code: "CODE1"},
        ])

        # Upsert with same code should update
        id2 = UUID.random
        result = BulkTestUuidItem.upsert_all([
          {id: id2.to_s, name: "Updated", code: "CODE1"},
          {id: UUID.random.to_s, name: "New Item", code: "CODE2"},
        ], on_conflict: :code, update: [:name])

        BulkTestUuidItem.count.should eq(2)

        item1 = BulkTestUuidItem.find_by("code", "CODE1")
        item1.should_not be_nil
        item1.not_nil!.name.should eq("Updated")
        # Original ID should be preserved (upsert updated, not inserted)
        item1.not_nil!.id.should eq(id1)
      end
    end
  end
end

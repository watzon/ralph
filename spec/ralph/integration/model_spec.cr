require "../../spec_helper"
require "../../ralph/test_helper"

module Ralph
  # Test model for User
  class UserTestModel < Model
    table "users"

    column id, Int64
    column name, String
    column email, String
    column age, Int32 | Nil
    column created_at, Time | Nil
  end

  # Integration tests for Model CRUD operations
  describe Model do
    before_all do
      RalphTestHelper.setup_test_database
    end

    before_each do
      RalphTestHelper.clear_tables
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    describe "CRUD Operations" do
      it "creates a new record" do
        user = UserTestModel.create(name: "Alice", email: "alice@example.com", age: 30)

        user.should_not be_nil
        user.name.should eq("Alice")
        user.email.should eq("alice@example.com")
        user.age.should eq(30)
        user.persisted?.should be_true
        user.new_record?.should be_false
      end

      it "finds a record by ID" do
        created = UserTestModel.create(name: "Bob", email: "bob@example.com", age: 25)

        found = UserTestModel.find(created.id)

        found.should_not be_nil
        if f = found
          f.id.should eq(created.id)
          f.name.should eq("Bob")
        end
      end

      it "returns nil when finding non-existent record" do
        found = UserTestModel.find(99999)
        found.should be_nil
      end

      it "finds the first record" do
        UserTestModel.create(name: "First", email: "first@example.com", age: 20)
        UserTestModel.create(name: "Second", email: "second@example.com", age: 25)

        first = UserTestModel.first

        first.should_not be_nil
        first.not_nil!.name.should eq("First")
      end

      it "returns nil when no records exist for first" do
        first = UserTestModel.first
        first.should be_nil
      end

      it "finds the last record" do
        UserTestModel.create(name: "First", email: "first@example.com", age: 20)
        UserTestModel.create(name: "Last", email: "last@example.com", age: 25)

        last = UserTestModel.last

        last.should_not be_nil
        last.not_nil!.name.should eq("Last")
      end

      it "returns nil when no records exist for last" do
        last = UserTestModel.last
        last.should be_nil
      end

      it "finds a record by column value" do
        UserTestModel.create(name: "Charlie", email: "charlie@example.com", age: 35)
        UserTestModel.create(name: "Diana", email: "diana@example.com", age: 28)

        found = UserTestModel.find_by("email", "charlie@example.com")

        found.should_not be_nil
        found.not_nil!.name.should eq("Charlie")
      end

      it "returns nil when find_by matches nothing" do
        found = UserTestModel.find_by("email", "nonexistent@example.com")
        found.should be_nil
      end

      it "finds all records matching a column value" do
        UserTestModel.create(name: "User1", email: "user1@example.com", age: 25)
        UserTestModel.create(name: "User2", email: "user2@example.com", age: 25)
        UserTestModel.create(name: "User3", email: "user3@example.com", age: 30)

        found = UserTestModel.find_all_by("age", 25)

        found.size.should eq(2)
        found.map(&.name).should eq(["User1", "User2"])
      end

      it "returns empty array when find_all_by matches nothing" do
        found = UserTestModel.find_all_by("age", 99)
        found.should be_empty
      end

      it "updates record attributes" do
        user = UserTestModel.create(name: "Eve", email: "eve@example.com", age: 30)

        updated = user.update(name: "Eve Updated", age: 35)

        updated.should be_true
        user.not_nil!.name.should eq("Eve Updated")
        user.not_nil!.age.should eq(35)

        # Verify persistence
        reloaded = UserTestModel.find(user.id)
        reloaded.not_nil!.name.should eq("Eve Updated")
        reloaded.not_nil!.age.should eq(35)
      end

      it "deletes a record" do
        user = UserTestModel.create(name: "Frank", email: "frank@example.com", age: 40)
        id = user.id

        destroyed = user.destroy

        destroyed.should be_true
        UserTestModel.find(id).should be_nil
      end

      it "returns false when destroying a new record" do
        user = UserTestModel.new(name: "Grace", email: "grace@example.com", age: 22)
        destroyed = user.destroy
        destroyed.should be_false
      end

      it "returns all records" do
        UserTestModel.create(name: "User1", email: "user1@example.com")
        UserTestModel.create(name: "User2", email: "user2@example.com")
        UserTestModel.create(name: "User3", email: "user3@example.com")

        all = UserTestModel.all

        all.size.should eq(3)
      end

      it "returns empty array when no records exist" do
        all = UserTestModel.all
        all.should be_empty
      end
    end

    describe "Count and Aggregates" do
      it "counts all records" do
        UserTestModel.create(name: "User1", email: "user1@example.com")
        UserTestModel.create(name: "User2", email: "user2@example.com")
        UserTestModel.create(name: "User3", email: "user3@example.com")

        count = UserTestModel.count
        count.should eq(3)
      end

      it "counts records matching a column value" do
        UserTestModel.create(name: "User1", email: "user1@example.com", age: 25)
        UserTestModel.create(name: "User2", email: "user2@example.com", age: 25)
        UserTestModel.create(name: "User3", email: "user3@example.com", age: 30)

        count = UserTestModel.count_by("age", 25)
        count.should eq(2)
      end

      it "calculates sum of a column" do
        UserTestModel.create(name: "User1", email: "user1@example.com", age: 20)
        UserTestModel.create(name: "User2", email: "user2@example.com", age: 30)
        UserTestModel.create(name: "User3", email: "user3@example.com", age: 40)

        sum = UserTestModel.sum("age")
        sum.should eq(90.0)
      end

      it "returns nil for sum when no records" do
        sum = UserTestModel.sum("age")
        sum.should be_nil
      end

      it "calculates average of a column" do
        UserTestModel.create(name: "User1", email: "user1@example.com", age: 20)
        UserTestModel.create(name: "User2", email: "user2@example.com", age: 30)
        UserTestModel.create(name: "User3", email: "user3@example.com", age: 40)

        avg = UserTestModel.average("age")
        avg.should eq(30.0)
      end

      it "returns nil for average when no records" do
        avg = UserTestModel.average("age")
        avg.should be_nil
      end

      it "finds minimum value of a column" do
        UserTestModel.create(name: "User1", email: "user1@example.com", age: 20)
        UserTestModel.create(name: "User2", email: "user2@example.com", age: 30)
        UserTestModel.create(name: "User3", email: "user3@example.com", age: 40)

        min = UserTestModel.minimum("age")
        min.should eq(20)
      end

      it "finds maximum value of a column" do
        UserTestModel.create(name: "User1", email: "user1@example.com", age: 20)
        UserTestModel.create(name: "User2", email: "user2@example.com", age: 30)
        UserTestModel.create(name: "User3", email: "user3@example.com", age: 40)

        max = UserTestModel.maximum("age")
        max.should eq(40)
      end
    end

    describe "Dirty Tracking" do
      it "tracks no changes for new records" do
        user = UserTestModel.new(name: "New", email: "new@example.com")
        user.changed?.should be_false
        user.changed_attributes.should be_empty
      end

      it "tracks changes after update" do
        user = UserTestModel.create(name: "Original", email: "original@example.com", age: 25)

        # Manually mark as changed (Crystal limitation: no automatic tracking)
        user.attribute_will_change!("name")
        user.name = "Updated"

        user.changed?.should be_true
        user.changed?("name").should be_true
        user.original_value("name").should eq("Original")
      end

      it "clears changes after save" do
        user = UserTestModel.create(name: "Original", email: "original@example.com", age: 25)

        user.attribute_will_change!("age")
        user.age = 30
        user.changed?.should be_true

        user.save
        user.changed?.should be_false
      end

      it "returns changes hash" do
        user = UserTestModel.create(name: "Original", email: "original@example.com", age: 25)

        user.attribute_will_change!("name")
        user.name = "Updated"

        changes = user.changes
        changes["name"]?.should_not be_nil
        changes["name"][0].should eq("Original")
        changes["name"][1].should eq("Updated")
      end
    end

    describe "State Predicates" do
      it "returns new_record? true for unsaved records" do
        user = UserTestModel.new(name: "New", email: "new@example.com")
        user.new_record?.should be_true
        user.persisted?.should be_false
      end

      it "returns new_record? false for saved records" do
        user = UserTestModel.create(name: "Saved", email: "saved@example.com")
        user.new_record?.should be_false
        user.persisted?.should be_true
      end
    end

    describe "Reload" do
      it "reloads record from database" do
        user = UserTestModel.create(name: "Original", email: "original@example.com", age: 25)

        # Direct database update
        Ralph.database.execute("UPDATE users SET name = ?, age = ? WHERE id = ?",
          args: ["Direct Update", 99, user.id] of DB::Any)

        user.reload

        user.not_nil!.name.should eq("Direct Update")
        user.not_nil!.age.should eq(99)
      end

      it "returns self when reloading new record" do
        user = UserTestModel.new(name: "New", email: "new@example.com")
        result = user.reload
        result.should be(user)
      end
    end
  end
end

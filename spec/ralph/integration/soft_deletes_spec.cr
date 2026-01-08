require "../../spec_helper"
require "../../ralph/test_helper"

module Ralph
  # Test model with soft deletes (paranoid mode)
  class SoftDeleteModel < Model
    include Ralph::Timestamps
    include Ralph::ActsAsParanoid

    table "soft_delete_records"

    column id, Int64, primary: true
    column name, String
    column email, String?
  end

  # Test model without soft deletes for comparison
  class HardDeleteModel < Model
    table "hard_delete_records"

    column id, Int64, primary: true
    column name, String
  end

  # Test model with soft deletes and callbacks
  class SoftDeleteWithCallbacks < Model
    include Ralph::ActsAsParanoid

    table "soft_delete_callback_records"

    column id, Int64, primary: true
    column name, String
    column callback_log, String?

    @[BeforeDestroy]
    def log_before_destroy
      self.callback_log = (callback_log || "") + "before_destroy;"
    end

    @[AfterDestroy]
    def log_after_destroy
      self.callback_log = (callback_log || "") + "after_destroy;"
    end
  end

  describe "Soft Deletes" do
    before_all do
      # Setup database connection
      RalphTestHelper.setup_test_database

      # Create test tables
      TestSchema.create_table("soft_delete_records") do |t|
        t.primary_key
        t.string("name")
        t.string("email")
        t.timestamps
        t.soft_deletes
      end

      TestSchema.create_table("hard_delete_records") do |t|
        t.primary_key
        t.string("name")
      end

      TestSchema.create_table("soft_delete_callback_records") do |t|
        t.primary_key
        t.string("name")
        t.string("callback_log")
        t.soft_deletes
      end
    end

    before_each do
      TestSchema.truncate_table("soft_delete_records")
      TestSchema.truncate_table("hard_delete_records")
      TestSchema.truncate_table("soft_delete_callback_records")
    end

    after_all do
      TestSchema.drop_table("soft_delete_records")
      TestSchema.drop_table("hard_delete_records")
      TestSchema.drop_table("soft_delete_callback_records")
    end

    describe "ActsAsParanoid module" do
      it "adds deleted_at column" do
        record = SoftDeleteModel.new(name: "Test")

        # Column should exist (nilable Time)
        record.deleted_at.should be_nil
      end

      it "sets paranoid? to true on class" do
        SoftDeleteModel.paranoid?.should be_true
      end

      it "sets paranoid? to false on non-paranoid models" do
        HardDeleteModel.responds_to?(:paranoid?).should be_false
      end

      it "provides deleted? instance method" do
        record = SoftDeleteModel.new(name: "Test")
        record.deleted?.should be_false
      end
    end

    describe "destroy (soft delete)" do
      it "sets deleted_at instead of deleting from database" do
        record = SoftDeleteModel.create(name: "Test", email: "test@example.com")
        id = record.id

        record.deleted?.should be_false
        record.destroy.should be_true
        record.deleted?.should be_true
        record.deleted_at.should_not be_nil

        # Record should still exist in database (with deleted_at set)
        found = SoftDeleteModel.find_with_deleted(id)
        found.should_not be_nil
        found.not_nil!.deleted_at.should_not be_nil
      end

      it "excludes soft-deleted records from default queries" do
        record1 = SoftDeleteModel.create(name: "Active", email: "active@example.com")
        record2 = SoftDeleteModel.create(name: "Deleted", email: "deleted@example.com")

        SoftDeleteModel.all.size.should eq(2)

        record2.destroy

        # Default query should exclude deleted record
        all_records = SoftDeleteModel.all
        all_records.size.should eq(1)
        all_records.first.name.should eq("Active")
      end

      it "returns false for new records" do
        record = SoftDeleteModel.new(name: "Test")
        record.destroy.should be_false
      end

      it "updates updated_at when soft-deleting" do
        record = SoftDeleteModel.create(name: "Test", email: "test@example.com")
        original_updated_at = record.updated_at

        sleep 0.01.seconds

        record.destroy

        record.updated_at.should_not eq(original_updated_at)
        record.updated_at.not_nil!.should be > original_updated_at.not_nil!
      end
    end

    describe "deleted?" do
      it "returns false for non-deleted records" do
        record = SoftDeleteModel.create(name: "Test", email: "test@example.com")
        record.deleted?.should be_false
      end

      it "returns true for deleted records" do
        record = SoftDeleteModel.create(name: "Test", email: "test@example.com")
        record.destroy
        record.deleted?.should be_true
      end

      it "returns false for new unsaved records" do
        record = SoftDeleteModel.new(name: "Test")
        record.deleted?.should be_false
      end
    end

    describe "with_deleted scope" do
      it "returns all records including soft-deleted ones" do
        record1 = SoftDeleteModel.create(name: "Active", email: "active@example.com")
        record2 = SoftDeleteModel.create(name: "Deleted", email: "deleted@example.com")

        record2.destroy

        # Default query excludes deleted
        SoftDeleteModel.all.size.should eq(1)

        # with_deleted includes all
        query = SoftDeleteModel.with_deleted
        results = Ralph.database.query_all(query.build_select, args: query.where_args)
        count = 0
        results.each { count += 1 }
        results.close
        count.should eq(2)
      end

      it "can be chained with other query methods" do
        SoftDeleteModel.create(name: "Alice", email: "alice@example.com")
        record2 = SoftDeleteModel.create(name: "Bob", email: "bob@example.com")
        record2.destroy

        query = SoftDeleteModel.with_deleted.where("name = ?", "Bob")
        results = Ralph.database.query_all(query.build_select, args: query.where_args)
        count = 0
        results.each { count += 1 }
        results.close
        count.should eq(1)
      end
    end

    describe "only_deleted scope" do
      it "returns only soft-deleted records" do
        record1 = SoftDeleteModel.create(name: "Active", email: "active@example.com")
        record2 = SoftDeleteModel.create(name: "Deleted", email: "deleted@example.com")
        record3 = SoftDeleteModel.create(name: "Also Deleted", email: "also@example.com")

        record2.destroy
        record3.destroy

        query = SoftDeleteModel.only_deleted
        results = Ralph.database.query_all(query.build_select, args: query.where_args)
        count = 0
        results.each { count += 1 }
        results.close
        count.should eq(2)
      end

      it "returns empty array when no deleted records" do
        SoftDeleteModel.create(name: "Active", email: "active@example.com")

        query = SoftDeleteModel.only_deleted
        results = Ralph.database.query_all(query.build_select, args: query.where_args)
        count = 0
        results.each { count += 1 }
        results.close
        count.should eq(0)
      end
    end

    describe "find_with_deleted" do
      it "finds soft-deleted records" do
        record = SoftDeleteModel.create(name: "Test", email: "test@example.com")
        id = record.id

        record.destroy

        # Regular find should return nil
        SoftDeleteModel.find(id).should be_nil

        # find_with_deleted should find it
        found = SoftDeleteModel.find_with_deleted(id)
        found.should_not be_nil
        found.not_nil!.name.should eq("Test")
        found.not_nil!.deleted?.should be_true
      end

      it "finds non-deleted records" do
        record = SoftDeleteModel.create(name: "Test", email: "test@example.com")
        id = record.id

        found = SoftDeleteModel.find_with_deleted(id)
        found.should_not be_nil
        found.not_nil!.deleted?.should be_false
      end

      it "returns nil for non-existent records" do
        SoftDeleteModel.find_with_deleted(999999).should be_nil
      end
    end

    describe "restore" do
      it "clears deleted_at on soft-deleted records" do
        record = SoftDeleteModel.create(name: "Test", email: "test@example.com")
        id = record.id

        record.destroy
        record.deleted?.should be_true

        record.restore.should be_true
        record.deleted?.should be_false
        record.deleted_at.should be_nil

        # Should be findable again via default query
        found = SoftDeleteModel.find(id)
        found.should_not be_nil
        found.not_nil!.deleted?.should be_false
      end

      it "returns true for non-deleted records (no-op)" do
        record = SoftDeleteModel.create(name: "Test", email: "test@example.com")
        record.restore.should be_true
        record.deleted?.should be_false
      end

      it "persists the restore to database" do
        record = SoftDeleteModel.create(name: "Test", email: "test@example.com")
        id = record.id

        record.destroy
        record.restore

        # Reload from database
        found = SoftDeleteModel.find(id)
        found.should_not be_nil
        found.not_nil!.deleted_at.should be_nil
      end
    end

    describe "really_destroy!" do
      it "permanently deletes the record from database" do
        record = SoftDeleteModel.create(name: "Test", email: "test@example.com")
        id = record.id

        record.really_destroy!.should be_true

        # Should not be findable at all
        SoftDeleteModel.find(id).should be_nil
        SoftDeleteModel.find_with_deleted(id).should be_nil
      end

      it "works on already soft-deleted records" do
        record = SoftDeleteModel.create(name: "Test", email: "test@example.com")
        id = record.id

        record.destroy # Soft delete first
        record.deleted?.should be_true

        record.really_destroy!.should be_true

        # Should be completely gone
        SoftDeleteModel.find_with_deleted(id).should be_nil
      end

      it "returns false for new records" do
        record = SoftDeleteModel.new(name: "Test")
        record.really_destroy!.should be_false
      end
    end

    describe "callbacks" do
      it "runs before_destroy callbacks on soft delete" do
        record = SoftDeleteWithCallbacks.create(name: "Test")
        record.callback_log.should be_nil

        record.destroy

        record.callback_log.should_not be_nil
        record.callback_log.not_nil!.should contain("before_destroy")
      end

      it "runs after_destroy callbacks on soft delete" do
        record = SoftDeleteWithCallbacks.create(name: "Test")

        record.destroy

        record.callback_log.should_not be_nil
        record.callback_log.not_nil!.should contain("after_destroy")
      end

      it "runs callbacks in correct order" do
        record = SoftDeleteWithCallbacks.create(name: "Test")

        record.destroy

        record.callback_log.should eq("before_destroy;after_destroy;")
      end

      it "runs callbacks on really_destroy! too" do
        record = SoftDeleteWithCallbacks.create(name: "Test")

        record.really_destroy!

        record.callback_log.should eq("before_destroy;after_destroy;")
      end
    end

    describe "non-paranoid model comparison" do
      it "actually deletes records (hard delete)" do
        record = HardDeleteModel.create(name: "Test")
        id = record.id

        record.destroy.should be_true

        # Should be completely gone
        HardDeleteModel.find(id).should be_nil
      end

      it "does not have deleted? method" do
        record = HardDeleteModel.new(name: "Test")
        # Non-paranoid models don't have deleted_at column, so deleted? won't exist
        record.responds_to?(:deleted?).should be_false
      end
    end

    describe "integration with find methods" do
      it "find excludes soft-deleted records" do
        record = SoftDeleteModel.create(name: "Test", email: "test@example.com")
        id = record.id

        record.destroy

        SoftDeleteModel.find(id).should be_nil
      end

      it "find_by excludes soft-deleted records" do
        record = SoftDeleteModel.create(name: "Test", email: "unique@example.com")

        record.destroy

        SoftDeleteModel.find_by("email", "unique@example.com").should be_nil
      end

      it "first excludes soft-deleted records" do
        record1 = SoftDeleteModel.create(name: "First", email: "first@example.com")
        record1.destroy

        record2 = SoftDeleteModel.create(name: "Second", email: "second@example.com")

        first = SoftDeleteModel.first
        first.should_not be_nil
        first.not_nil!.name.should eq("Second")
      end

      it "last excludes soft-deleted records" do
        record1 = SoftDeleteModel.create(name: "First", email: "first@example.com")
        record2 = SoftDeleteModel.create(name: "Second", email: "second@example.com")
        record2.destroy

        last = SoftDeleteModel.last
        last.should_not be_nil
        last.not_nil!.name.should eq("First")
      end

      it "count excludes soft-deleted records" do
        SoftDeleteModel.create(name: "Active1", email: "a1@example.com")
        SoftDeleteModel.create(name: "Active2", email: "a2@example.com")
        record3 = SoftDeleteModel.create(name: "Deleted", email: "deleted@example.com")
        record3.destroy

        SoftDeleteModel.count.should eq(2)
      end
    end

    describe "multiple soft deletes" do
      it "handles multiple records correctly" do
        10.times do |i|
          SoftDeleteModel.create(name: "Record #{i}", email: "r#{i}@example.com")
        end

        SoftDeleteModel.all.size.should eq(10)

        # Delete every other record
        SoftDeleteModel.all.each_with_index do |record, i|
          record.destroy if i % 2 == 0
        end

        SoftDeleteModel.all.size.should eq(5)

        query = SoftDeleteModel.with_deleted
        results = Ralph.database.query_all(query.build_select, args: query.where_args)
        count = 0
        results.each { count += 1 }
        results.close
        count.should eq(10)

        query2 = SoftDeleteModel.only_deleted
        results2 = Ralph.database.query_all(query2.build_select, args: query2.where_args)
        deleted_count = 0
        results2.each { deleted_count += 1 }
        results2.close
        deleted_count.should eq(5)
      end
    end

    describe "edge cases" do
      it "handles destroying same record multiple times" do
        record = SoftDeleteModel.create(name: "Test", email: "test@example.com")

        record.destroy.should be_true
        original_deleted_at = record.deleted_at

        sleep 0.01.seconds

        # Second destroy should update deleted_at again
        record.destroy.should be_true
        record.deleted_at.should_not eq(original_deleted_at)
      end

      it "can update other fields on soft-deleted record" do
        record = SoftDeleteModel.create(name: "Original", email: "test@example.com")
        id = record.id

        record.destroy

        # Update the deleted record
        record.name = "Updated"
        record.save

        # Verify change persisted
        found = SoftDeleteModel.find_with_deleted(id)
        found.should_not be_nil
        found.not_nil!.name.should eq("Updated")
        found.not_nil!.deleted?.should be_true
      end
    end
  end
end

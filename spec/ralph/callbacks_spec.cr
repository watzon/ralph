require "../spec_helper"
require "../ralph/test_helper"

module Ralph
  # Test models with callbacks - defined outside describe block
  class CallbackTestModel < Model
    table "users"

    column id, Int64
    column name, String
    column email, String

    # Callback tracking (using underscore prefix to avoid being treated as a column)
    @_callback_log : Array(String) = [] of String

    def callback_log : Array(String)
      @_callback_log
    end

    @[BeforeSave]
    def before_save_callback
      @_callback_log << "before_save"
    end

    @[AfterSave]
    def after_save_callback
      @_callback_log << "after_save"
    end

    @[BeforeCreate]
    def before_create_callback
      @_callback_log << "before_create"
    end

    @[AfterCreate]
    def after_create_callback
      @_callback_log << "after_create"
    end

    @[BeforeUpdate]
    def before_update_callback
      @_callback_log << "before_update"
    end

    @[AfterUpdate]
    def after_update_callback
      @_callback_log << "after_update"
    end

    @[BeforeDestroy]
    def before_destroy_callback
      @_callback_log << "before_destroy"
    end

    @[AfterDestroy]
    def after_destroy_callback
      @_callback_log << "after_destroy"
    end
  end

  describe Callbacks do
    before_all do
      RalphTestHelper.setup_test_database
    end

    before_each do
      RalphTestHelper.clear_tables
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    describe "save callbacks" do
      it "runs before_save and after_save on create" do
        model = CallbackTestModel.new(name: "Alice", email: "alice@example.com")
        model.save

        model.callback_log.should contain("before_save")
        model.callback_log.should contain("after_save")
      end

      it "runs before_create and after_create on create" do
        model = CallbackTestModel.new(name: "Bob", email: "bob@example.com")
        model.save

        model.callback_log.should contain("before_create")
        model.callback_log.should contain("after_create")
      end

      it "runs before_update and after_update on update" do
        model = CallbackTestModel.new(name: "Charlie", email: "charlie@example.com")
        model.save
        model.callback_log.clear

        model.name = "Charles"
        model.save

        model.callback_log.should contain("before_update")
        model.callback_log.should contain("after_update")
      end

      it "does not run create callbacks on update" do
        model = CallbackTestModel.new(name: "Dave", email: "dave@example.com")
        model.save
        model.callback_log.clear

        model.name = "David"
        model.save

        model.callback_log.should_not contain("before_create")
        model.callback_log.should_not contain("after_create")
      end

      it "does not run update callbacks on create" do
        model = CallbackTestModel.new(name: "Eve", email: "eve@example.com")
        model.save

        model.callback_log.should_not contain("before_update")
        model.callback_log.should_not contain("after_update")
      end

      it "runs callbacks in correct order on create" do
        model = CallbackTestModel.new(name: "Frank", email: "frank@example.com")
        model.save

        # Order should be: before_save -> before_create -> [create] -> after_create -> after_save
        callback_log = model.callback_log
        callback_log.index("before_save").not_nil!.should be < callback_log.index("before_create").not_nil!
        callback_log.index("before_create").not_nil!.should be < callback_log.index("after_create").not_nil!
        callback_log.index("after_create").not_nil!.should be < callback_log.index("after_save").not_nil!
      end

      it "runs callbacks in correct order on update" do
        model = CallbackTestModel.new(name: "Grace", email: "grace@example.com")
        model.save
        model.callback_log.clear

        model.name = "Gracie"
        model.save

        # Order should be: before_save -> before_update -> [update] -> after_update -> after_save
        callback_log = model.callback_log
        callback_log.index("before_save").not_nil!.should be < callback_log.index("before_update").not_nil!
        callback_log.index("before_update").not_nil!.should be < callback_log.index("after_update").not_nil!
        callback_log.index("after_update").not_nil!.should be < callback_log.index("after_save").not_nil!
      end
    end

    describe "destroy callbacks" do
      it "runs before_destroy and after_destroy" do
        model = CallbackTestModel.new(name: "Henry", email: "henry@example.com")
        model.save
        model.callback_log.clear

        model.destroy

        model.callback_log.should contain("before_destroy")
        model.callback_log.should contain("after_destroy")
      end

      it "runs before_destroy before record is deleted" do
        model = CallbackTestModel.new(name: "Iris", email: "iris@example.com")
        model.save

        # The record should exist before destroy
        found = CallbackTestModel.find(model.id)
        found.should_not be_nil

        model.destroy

        # The record should not exist after destroy
        found = CallbackTestModel.find(model.id)
        found.should be_nil
      end

      it "runs callbacks in correct order on destroy" do
        model = CallbackTestModel.new(name: "Jack", email: "jack@example.com")
        model.save
        model.callback_log.clear

        model.destroy

        # Order should be: before_destroy -> [destroy] -> after_destroy
        callback_log = model.callback_log
        callback_log.index("before_destroy").not_nil!.should be < callback_log.index("after_destroy").not_nil!
      end
    end
  end
end

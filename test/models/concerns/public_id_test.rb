# typed: false
# frozen_string_literal: true

require "test_helper"

class PublicIdTest < ActiveSupport::TestCase
  # Define a dummy model for testing
  class DummyModel < ApplicationRecord
    include PublicId
    # This model is not backed by a real table, so we fake whatever ActiveRecord needs.
    # The dummy_models table does not exist in the test database, but we can temporarily
    # create it via ActiveRecord::Base.connection.create_table or reuse an existing table
    # by pointing table_name = :some_existing_table. We keep things simple since we only
    # verify the callback behavior. To call save! we do need a table, so we mimic the
    # pattern from ordinary fixtures by creating a temporary table here.
    # Alternatively, a migration could build this table during setup/teardown.

    # The temporary dummy_models table is created for each test run.
    # This configuration belongs in Minitest setup/teardown hooks.
  end

  setup do
    # Create a temporary dummy_models table that has a public_id column
    ActiveRecord::Base.connection.create_table(:dummy_models, temporary: true) do |t|
      t.string(:public_id)
      t.timestamps
    end
    # Mock Nanoid so that it always returns the same ID for stability
    @original_nanoid_generate = Nanoid.method(:generate)
    Nanoid.define_singleton_method(:generate) { |**_args| "testpublicid123456789" }
  end

  teardown do
    # Remove the temporary table
    ActiveRecord::Base.connection.drop_table(:dummy_models, if_exists: true)
    # Restore the original Nanoid mock
    Nanoid.define_singleton_method(:generate, @original_nanoid_generate)
  end

  test "public_id is generated before creation" do
    dummy_instance = DummyModel.new

    assert_nil dummy_instance.public_id
    dummy_instance.save!

    assert_not_nil dummy_instance.public_id
    assert_equal "testpublicid123456789", dummy_instance.public_id
  end

  test "generated public_id has correct length" do
    dummy_instance = DummyModel.new
    dummy_instance.save!

    assert_equal 21, dummy_instance.public_id.length
  end

  test "public_id is not nil after creation" do
    dummy_instance = DummyModel.new
    dummy_instance.save!

    assert_not_nil dummy_instance.public_id
  end

  test "existing public_id is not overridden" do
    dummy_instance = DummyModel.new
    dummy_instance.public_id = "existingid123456789"
    dummy_instance.save!

    assert_equal "existingid123456789", dummy_instance.public_id
  end

  test "persisted public_id cannot be changed through the record update boundary" do
    dummy_instance = DummyModel.create!
    dummy_instance.public_id = "replacementid123456"

    error = assert_raises(ActiveRecord::RecordInvalid) { dummy_instance.save! }

    assert_equal "cannot be changed after creation", error.record.errors[:public_id].first
    assert_equal "testpublicid123456789", dummy_instance.reload.public_id
  end
end

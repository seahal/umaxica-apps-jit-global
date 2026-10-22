# typed: false
# frozen_string_literal: true

require "test_helper"

class ReferenceRecordTest < ActiveSupport::TestCase
  class DummyReference < ApplicationRecord
    # We create a simple class mimicking a reference table.
    # Usually they have just an id, but for tests we don't have a table.
    # Let's use an existing reference model for the test since ReferenceRecord requires a table.

    # We will test ClientStatus as a real reference model.
  end

  test "record_timestamps is false" do
    assert_not ClientStatus.record_timestamps
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal ClientStatus::NOTHING, ClientStatus.nothing_id
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class OccurrenceStatusTest < ActiveSupport::TestCase
  class DummyOccurrenceStatus < OccurrenceRecord
    self.table_name = "client_occurrence_statuses"
    include OccurrenceStatus
  end

  test "retains no lifecycle helper methods" do
    record = DummyOccurrenceStatus.new

    assert_not record.respond_to?(:set_default_lifecycle_timestamps)
    assert_not record.respond_to?(:ensure_lifecycle_timestamps)
  end

  test "does not add lifecycle attributes on status rows" do
    record = ClientOccurrenceStatus.new

    assert_not record.has_attribute?(:discard_at)
    assert_not record.has_attribute?(:purge_eligible_at)
  end
end

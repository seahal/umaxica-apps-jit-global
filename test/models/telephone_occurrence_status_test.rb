# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: telephone_occurrence_statuses
# Database name: occurrence
#
#  id :bigint           not null, primary key
#

require "test_helper"

class TelephoneOccurrenceStatusTest < ActiveSupport::TestCase
  test "can load nothing status from db" do
    nothing = TelephoneOccurrenceStatus.find(TelephoneOccurrenceStatus::NOTHING)

    assert_not_nil nothing
    assert_equal 0, nothing.id
  end

  test "constants are defined" do
    assert_equal 1, TelephoneOccurrenceStatus::ACTIVE
    assert_equal 0, TelephoneOccurrenceStatus::NOTHING
  end

  test "has occurrences association" do
    assert_status_association(TelephoneOccurrenceStatus, :telephone_occurrences)
  end

  test "ensure_defaults! creates default records" do
    TelephoneOccurrenceStatus.ensure_defaults!

    TelephoneOccurrenceStatus::DEFAULTS.each do |id|
      assert TelephoneOccurrenceStatus.exists?(id), "missing default telephone occurrence status #{id}"
    end
  end

  #   test "expires_at default" do
  #     record = TelephoneOccurrenceStatus.new(id: "EXPIRES_AT_TEST")
  #
  #     assert_expires_at_default(record)
  #   end
  private

  def assert_status_association(status_class, association_name)
    reflection = status_class.reflect_on_association(association_name)

    assert_not_nil reflection
  end
end

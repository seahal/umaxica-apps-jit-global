# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: area_occurrence_statuses
# Database name: occurrence
#
#  id :bigint           not null, primary key
#

require "test_helper"

class AreaOccurrenceStatusTest < ActiveSupport::TestCase
  test "can load nothing status from db" do
    nothing = AreaOccurrenceStatus.find(AreaOccurrenceStatus::NOTHING)

    assert_not_nil nothing
    assert_equal 0, nothing.id
  end

  test "constants are defined" do
    assert_equal 1, AreaOccurrenceStatus::ACTIVE
    assert_equal 0, AreaOccurrenceStatus::NOTHING
  end

  test "has occurrences association" do
    assert_status_association(AreaOccurrenceStatus, :area_occurrences)
  end

  test "ensure_defaults! creates default records" do
    AreaOccurrenceStatus.ensure_defaults!

    AreaOccurrenceStatus::DEFAULTS.each do |id|
      assert AreaOccurrenceStatus.exists?(id), "missing default area occurrence status #{id}"
    end
  end

  # expires_at column does not exist on area_occurrence_statuses table
  # test "expires_at default" do
  #   record = AreaOccurrenceStatus.new(id: "EXPIRES_AT_TEST")
  #
  #   assert_expires_at_default(record)
  # end
  private

  def assert_status_association(status_class, association_name)
    reflection = status_class.reflect_on_association(association_name)

    assert_not_nil reflection
  end
end

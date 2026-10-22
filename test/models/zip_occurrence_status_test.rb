# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: zip_occurrence_statuses
# Database name: occurrence
#
#  id :bigint           not null, primary key
#

require "test_helper"

class ZipOccurrenceStatusTest < ActiveSupport::TestCase
  test "can load nothing status from db" do
    nothing = ZipOccurrenceStatus.find(ZipOccurrenceStatus::NOTHING)

    assert_not_nil nothing
    assert_equal 0, nothing.id
  end

  test "has occurrences association" do
    assert_status_association(ZipOccurrenceStatus, :zip_occurrences)
  end

  test "ensure_defaults! creates default records" do
    ZipOccurrenceStatus.ensure_defaults!

    ZipOccurrenceStatus::DEFAULTS.each do |id|
      assert ZipOccurrenceStatus.exists?(id), "missing default zip occurrence status #{id}"
    end
  end

  #   test "expires_at default" do
  #     record = ZipOccurrenceStatus.new(id: "EXPIRES_AT_TEST")
  #
  #     assert_expires_at_default(record)
  #   end
  private

  def assert_status_association(status_class, association_name)
    reflection = status_class.reflect_on_association(association_name)

    assert_not_nil reflection
  end
end

# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: ip_occurrence_statuses
# Database name: occurrence
#
#  id :bigint           not null, primary key
#

require "test_helper"

class IpOccurrenceStatusTest < ActiveSupport::TestCase
  test "can load nothing status from db" do
    nothing = IpOccurrenceStatus.find(IpOccurrenceStatus::NOTHING)

    assert_not_nil nothing
    assert_equal 0, nothing.id
  end

  test "constants are defined" do
    assert_equal 1, IpOccurrenceStatus::ACTIVE
    assert_equal 0, IpOccurrenceStatus::NOTHING
  end

  test "has occurrences association" do
    assert_status_association(IpOccurrenceStatus, :ip_occurrences)
  end

  test "ensure_defaults! restores a missing default record" do
    IpOccurrenceStatus.find(IpOccurrenceStatus::ACTIVE).destroy!

    IpOccurrenceStatus.ensure_defaults!

    IpOccurrenceStatus::DEFAULTS.each do |id|
      assert IpOccurrenceStatus.exists?(id), "missing default ip occurrence status #{id}"
    end
  end

  #   test "expires_at default" do
  #     record = IpOccurrenceStatus.new(id: "EXPIRES_AT_TEST")
  #
  #     assert_expires_at_default(record)
  #   end
  private

  def assert_status_association(status_class, association_name)
    reflection = status_class.reflect_on_association(association_name)

    assert_not_nil reflection
  end
end

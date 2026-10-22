# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: domain_occurrence_statuses
# Database name: occurrence
#
#  id :bigint           not null, primary key
#

require "test_helper"

class DomainOccurrenceStatusTest < ActiveSupport::TestCase
  test "can load nothing status from db" do
    nothing = DomainOccurrenceStatus.find(DomainOccurrenceStatus::NOTHING)

    assert_not_nil nothing
    assert_equal 0, nothing.id
  end

  test "constants are defined" do
    assert_equal 1, DomainOccurrenceStatus::ACTIVE
    assert_equal 2, DomainOccurrenceStatus::DELETED
    assert_equal 3, DomainOccurrenceStatus::INACTIVE
    assert_equal 0, DomainOccurrenceStatus::NOTHING
    assert_equal 5, DomainOccurrenceStatus::PENDING
  end

  test "has occurrences association" do
    assert_status_association(DomainOccurrenceStatus, :domain_occurrences)
  end

  test "ensure_defaults! creates default records" do
    DomainOccurrenceStatus.ensure_defaults!

    DomainOccurrenceStatus::DEFAULTS.each do |id|
      assert DomainOccurrenceStatus.exists?(id), "missing default domain occurrence status #{id}"
    end
  end

  #   test "expires_at default" do
  #     record = DomainOccurrenceStatus.new(id: "EXPIRES_AT_TEST")
  #
  #     assert_expires_at_default(record)
  #   end
  private

  def assert_status_association(status_class, association_name)
    reflection = status_class.reflect_on_association(association_name)

    assert_not_nil reflection
  end
end

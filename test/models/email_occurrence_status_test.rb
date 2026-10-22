# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: email_occurrence_statuses
# Database name: occurrence
#
#  id :bigint           not null, primary key
#

require "test_helper"

class EmailOccurrenceStatusTest < ActiveSupport::TestCase
  test "can load nothing status from db" do
    nothing = EmailOccurrenceStatus.find(EmailOccurrenceStatus::NOTHING)

    assert_not_nil nothing
    assert_equal 0, nothing.id
  end

  test "constants are defined" do
    assert_equal 1, EmailOccurrenceStatus::ACTIVE
    assert_equal 0, EmailOccurrenceStatus::NOTHING
  end

  test "has occurrences association" do
    assert_status_association(EmailOccurrenceStatus, :email_occurrences)
  end

  test "ensure_defaults! creates default records" do
    EmailOccurrenceStatus.ensure_defaults!

    EmailOccurrenceStatus::DEFAULTS.each do |id|
      assert EmailOccurrenceStatus.exists?(id), "missing default email occurrence status #{id}"
    end
  end

  #   test "expires_at default" do
  #     record = EmailOccurrenceStatus.new(id: "EXPIRES_AT_TEST")
  #
  #     assert_expires_at_default(record)
  #   end
  private

  def assert_status_association(status_class, association_name)
    reflection = status_class.reflect_on_association(association_name)

    assert_not_nil reflection
  end
end

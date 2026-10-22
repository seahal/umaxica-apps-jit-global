# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: jwt_occurrence_statuses
# Database name: occurrence
#
#  id   :bigint           not null, primary key
#  name :string           default(""), not null
#

require "test_helper"

class JwtOccurrenceStatusTest < ActiveSupport::TestCase
  test "can load nothing status from db" do
    nothing = JwtOccurrenceStatus.find(JwtOccurrenceStatus::NOTHING)

    assert_not_nil nothing
    assert_equal 0, nothing.id
  end

  test "constants are defined" do
    assert_equal 0, JwtOccurrenceStatus::NOTHING
    assert_equal 2, JwtOccurrenceStatus::ACTIVE
    assert_equal 3, JwtOccurrenceStatus::INACTIVE
    assert_equal 4, JwtOccurrenceStatus::DELETED
  end

  test "ensure_defaults! creates default records" do
    JwtOccurrenceStatus.ensure_defaults!

    JwtOccurrenceStatus::DEFAULTS.each do |id|
      assert JwtOccurrenceStatus.exists?(id), "missing default jwt occurrence status #{id}"
    end
  end
end

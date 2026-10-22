# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_statuses
# Database name: com_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ComPreferenceStatusTest < ActiveSupport::TestCase
  fixtures :com_preference_statuses

  test "has correct constants" do
    assert_equal 1, ComPreferenceStatus::DELETED
    assert_equal 2, ComPreferenceStatus::NOTHING
  end

  test "defaults includes DELETED and NOTHING" do
    assert_includes ComPreferenceStatus::DEFAULTS, ComPreferenceStatus::DELETED
    assert_includes ComPreferenceStatus::DEFAULTS, ComPreferenceStatus::NOTHING
  end

  test "returns all statuses" do
    ids = ComPreferenceStatus.pluck(:id)

    assert_equal [ComPreferenceStatus::DELETED, ComPreferenceStatus::NOTHING], ids.sort
  end

  test "ensure_defaults! does nothing when defaults exist" do
    assert_no_difference "ComPreferenceStatus.count" do
      ComPreferenceStatus.ensure_defaults!
    end
  end
end

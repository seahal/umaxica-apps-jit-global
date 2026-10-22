# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_preference_statuses
# Database name: org_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OrgPreferenceStatusTest < ActiveSupport::TestCase
  fixtures :org_preference_statuses

  test "has correct constants" do
    assert_equal 1, OrgPreferenceStatus::DELETED
    assert_equal 2, OrgPreferenceStatus::NOTHING
  end

  test "defaults includes DELETED and NOTHING" do
    assert_includes OrgPreferenceStatus::DEFAULTS, OrgPreferenceStatus::DELETED
    assert_includes OrgPreferenceStatus::DEFAULTS, OrgPreferenceStatus::NOTHING
  end

  test "returns all statuses" do
    ids = OrgPreferenceStatus.pluck(:id)

    assert_equal [1, 2], ids.sort
  end

  test "ensure_defaults! does nothing when defaults exist" do
    assert_no_difference "OrgPreferenceStatus.count" do
      OrgPreferenceStatus.ensure_defaults!
    end
  end

  test "ensure_defaults! creates missing default records" do
    Prosopite.pause do
      OrgPreferenceStatus.where(id: OrgPreferenceStatus::DEFAULTS).destroy_all
    end

    assert_difference("OrgPreferenceStatus.count") do
      OrgPreferenceStatus.ensure_defaults!
    end
  end
end

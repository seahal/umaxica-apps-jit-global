# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_statuses
# Database name: app_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class AppPreferenceStatusTest < ActiveSupport::TestCase
  test "has correct constants" do
    assert_equal 0, AppPreferenceStatus::ACTIVE
    assert_equal 1, AppPreferenceStatus::RETIRED
  end

  test "defaults includes all fixed ids" do
    assert_includes AppPreferenceStatus::DEFAULTS, AppPreferenceStatus::ACTIVE
    assert_includes AppPreferenceStatus::DEFAULTS, AppPreferenceStatus::RETIRED
  end

  test "can load active status from db" do
    status = AppPreferenceStatus.find(AppPreferenceStatus::ACTIVE)

    assert_equal 0, status.id
  end

  test "ensure_defaults! creates missing default records" do
    called = false

    AppPreferenceStatus.stub(
      :insert_missing_fixed_ids!, ->(ids) do
                                    called = true

                                    assert_equal AppPreferenceStatus::DEFAULTS, ids
                                  end,
    ) do
      AppPreferenceStatus.ensure_defaults!
    end

    assert called
  end

  test "ensure_defaults! skips when all defaults exist" do
    AppPreferenceStatus.ensure_defaults!

    assert_no_difference("AppPreferenceStatus.count") do
      AppPreferenceStatus.ensure_defaults!
    end
  end
end

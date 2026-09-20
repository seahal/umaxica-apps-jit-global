# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceOptionTamperingTest < ActionDispatch::IntegrationTest
  test "theme update ignores invalid option id without changing canonical preference" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_preference_path(ri: "jp")

    assert_response :success

    preference = AppPreference.order(:created_at).last
    original_option_id = preference.app_preference_theme.option_id

    patch base_app_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: 99_999 } }

    assert_response :redirect
    assert_equal original_option_id, preference.reload.app_preference_theme.option_id
  end

  test "timezone update ignores invalid timezone without changing canonical preference" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_preference_path(ri: "jp")

    assert_response :success

    preference = AppPreference.order(:created_at).last
    original_option_id = preference.app_preference_timezone.option_id

    patch base_app_preference_timezone_path(ri: "jp"),
          params: { preference_timezone: { option_id: "Mars/Olympus" } }

    assert_response :redirect
    assert_equal original_option_id, preference.reload.app_preference_timezone.option_id
  end

  test "timezone update resolves each spelling of an option name to the same option" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_preference_path(ri: "jp")

    assert_response :success

    preference = AppPreference.order(:created_at).last

    %w(Asia/Tokyo ASIA_TOKYO asia_tokyo asia-tokyo).each do |spelling|
      patch base_app_preference_timezone_path(ri: "jp"),
            params: { preference_timezone: { option_id: AppPreferenceTimezoneOption::ETC_UTC } }

      assert_equal AppPreferenceTimezoneOption::ETC_UTC, preference.reload.app_preference_timezone.option_id

      patch base_app_preference_timezone_path(ri: "jp"),
            params: { preference_timezone: { option_id: spelling } }

      assert_response :redirect
      assert_equal AppPreferenceTimezoneOption::ASIA_TOKYO, preference.reload.app_preference_timezone.option_id,
                   "expected #{spelling.inspect} to resolve to Asia/Tokyo"
    end
  end

  test "timezone update accepts a numeric option id given as a string" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_preference_path(ri: "jp")

    assert_response :success

    preference = AppPreference.order(:created_at).last

    patch base_app_preference_timezone_path(ri: "jp"),
          params: { preference_timezone: { option_id: AppPreferenceTimezoneOption::AMERICA_NEW_YORK.to_s } }

    assert_response :redirect
    assert_equal AppPreferenceTimezoneOption::AMERICA_NEW_YORK, preference.reload.app_preference_timezone.option_id
  end

  test "timezone update treats constant and environment names as unknown options" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_preference_path(ri: "jp")

    assert_response :success

    preference = AppPreference.order(:created_at).last
    original_option_id = preference.app_preference_timezone.option_id

    %w(INVALID_CONST RAILS_ENV SECRET_KEY_BASE ApplicationController Object Kernel).each do |input|
      patch base_app_preference_timezone_path(ri: "jp"),
            params: { preference_timezone: { option_id: input } }

      assert_response :redirect
      assert_equal original_option_id, preference.reload.app_preference_timezone.option_id,
                   "expected #{input.inspect} to leave the timezone unchanged"
    end
  end
end

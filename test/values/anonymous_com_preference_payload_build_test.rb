# typed: false
# frozen_string_literal: true

require "test_helper"
require "jwt"

# WU-7 section 4.2: the anonymous com writer's stored `preferences` payload, the object the JWT
# carries when the com write entry issues a token.
class AnonymousComPreferencePayloadBuildTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  fixtures :com_preferences, :com_preference_statuses, :com_preference_theme_options,
           :com_preference_language_options, :com_preference_timezone_options,
           :com_preference_currencies, :com_preference_date_formats,
           :com_preference_time_formats, :com_preference_motions,
           :com_preference_densities, :com_preference_page_sizes

  include PreferenceBase

  test "the com payload uses the closed long-name keys and skips consent and region" do
    ComPreferenceLanguageOption.ensure_defaults!
    ComPreferenceThemeOption.ensure_defaults!
    [ComPreferenceCurrencyOption, ComPreferenceDateFormatOption, ComPreferenceTimeFormatOption,
     ComPreferenceMotionOption, ComPreferenceDensityOption, ComPreferencePageSizeOption,].each(&:ensure_defaults!)
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )
    ComPreferenceLanguage.create!(preference: preference, option_id: ComPreferenceLanguageOption::JA)
    ComPreferenceTheme.create!(preference: preference, option_id: ComPreferenceThemeOption::SYSTEM)
    payload = build_preferences_payload(preference)

    assert_equal(
      { "theme" => "system",
        "language" => "ja",
        "timezone" => "Asia/Tokyo",
        "currency" => "jpy",
        "date_format" => "iso",
        "time_format" => "24",
        "motion" => "standard",
        "density" => "standard",
        "page_size" => "infinity", }, payload,
    )
    assert_not_includes payload.keys, "consented"
    assert_not_includes payload.keys, "ri"
    assert_not_includes payload.keys, "lx"
  end
end

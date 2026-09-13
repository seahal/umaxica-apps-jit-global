# typed: false
# frozen_string_literal: true

require "test_helper"

class SessionTimestampHelperTest < ActiveSupport::TestCase
  setup do
    @helper = Object.new.extend(SessionTimestampHelper)
    @original_preference = Actor.preferences
  end

  teardown do
    Actor.preferences = @original_preference
  end

  test "uses the preference timezone, ISO date format, and 24-hour clock" do
    Actor.preferences = Actor::Preference.from_jwt(
      {
        "lx" => "en",
        "tz" => "america/new_york",
        "df" => "iso",
        "tf" => "24",
      },
    )

    timestamp = Time.utc(2026, 9, 13, 1, 8)

    assert_equal "2026-09-12 21:08", @helper.localized_session_timestamp(timestamp)
  end

  test "uses the preference date order and localized 12-hour clock" do
    Actor.preferences = Actor::Preference.from_jwt(
      {
        "lx" => "ja",
        "tz" => "Asia/Tokyo",
        "df" => "us",
        "tf" => "12",
      },
    )

    timestamp = Time.utc(2026, 9, 13, 1, 8)

    I18n.with_locale(:ja) do
      assert_equal "09/13/2026 10:08 午前", @helper.localized_session_timestamp(timestamp)
    end
  end

  test "accepts legacy date and time aliases from preference JWTs" do
    Actor.preferences = Actor::Preference.from_jwt(
      {
        "lx" => "en",
        "tz" => "Etc/UTC",
        "df" => "dmy",
        "tf" => "hour_12",
      },
    )

    timestamp = Time.utc(2026, 9, 13, 13, 8)

    I18n.with_locale(:en) do
      assert_equal "13/09/2026 01:08 pm", @helper.localized_session_timestamp(timestamp)
    end
  end

  test "formats the UK date order from the preference JWT" do
    Actor.preferences = Actor::Preference.from_jwt(
      {
        "lx" => "en",
        "tz" => "Etc/UTC",
        "df" => "uk",
        "tf" => "24",
      },
    )

    timestamp = Time.utc(2026, 9, 13, 13, 8)

    assert_equal "13/09/2026 13:08", @helper.localized_session_timestamp(timestamp)
  end

  test "returns nil for a missing timestamp" do
    assert_nil @helper.localized_session_timestamp(nil)
  end
end

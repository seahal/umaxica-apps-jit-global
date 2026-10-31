# typed: false
# frozen_string_literal: true

require "test_helper"

class AnonymousComRetiredConsentTest < ActionDispatch::IntegrationTest
  DISPLAY_SNAPSHOT = {
    "theme" => "system",
    "language" => "ja",
    "timezone" => "Asia/Tokyo",
    "currency" => "jpy",
    "date_format" => "iso",
    "time_format" => "24",
    "motion" => "standard",
    "density" => "standard",
    "page_size" => "infinity",
  }.freeze

  self.fixture_table_names = []

  setup do
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! @host
    https!
    [ComPreferenceStatus].each(&:ensure_defaults!)
    [ComPreferenceCurrencyOption, ComPreferenceDateFormatOption, ComPreferenceTimeFormatOption,
     ComPreferenceMotionOption, ComPreferenceDensityOption, ComPreferencePageSizeOption,].each(&:ensure_defaults!)
  end

  test "only an active com preference provides consent with a matching binding" do
    { ComPreferenceStatus::ACTIVE => false, ComPreferenceStatus::RETIRED => true }.each do |status, show_banner|
      raw = PreferenceBrowserBinding.mint_value
      preference = ComPreference.create!(
        last_issued_at: Time.current,
        last_issued_expires_at: 400.days.from_now,
        status_id: status,
        jti: JitSecurityJwtJtiGenerator.generate,
      )
      cookie = ComPreferenceCookie.create!(
        preference: preference, consented: true,
      )
      ComPreferenceConsentReceipt.create!(preference: preference, version: SecureRandom.uuid, recorded_at: Time.current)
      ComPreferenceBrowserBinding.create!(preference: preference, digest: PreferenceBrowserBinding.digest_for(raw))
      cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
        DISPLAY_SNAPSHOT.merge({ "theme" => "system" }), host: @host, preference_type: "ComPreference",
                                                         issued_at: Time.current,
                                                         public_id: preference.public_id, jti: preference.jti,
      )
      cookies[PreferenceBrowserBinding::COOKIE_NAME] = raw

      assert_no_difference -> { ComPreference.count } do
        get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }
      end

      assert_response :ok
      assert_equal show_banner, response.parsed_body.fetch("show_banner")
      assert cookie.reload.consented
    end
  end

  test "a retired com preference cannot populate consent on the settings screen" do
    raw = PreferenceBrowserBinding.mint_value
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      status_id: ComPreferenceStatus::RETIRED,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    cookie = ComPreferenceCookie.create!(
      preference: preference, consented: true, functional: true,
    )
    ComPreferenceBrowserBinding.create!(preference: preference, digest: PreferenceBrowserBinding.digest_for(raw))
    cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: @host, preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: preference.public_id, jti: preference.jti,
    )
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = raw

    rendered_preferences = []
    capture = ->(*) { rendered_preferences << Actor.preferences }
    ActiveSupport::Notifications.subscribed(capture, "render_template.action_view") do
      get edit_base_com_preference_cookie_path(ri: "jp")
    end

    assert_response :ok
    page = JSON.parse(response.parsed_body.at_css("script[data-page]").text)
    categories = page.fetch("props").fetch("form").fetch("categories")

    assert categories.none? { |category| category.fetch("value") }
    assert_not_empty rendered_preferences
    assert rendered_preferences.all? { |value| !value.cookie.consented? && !value.cookie.functional? }
    assert cookie.reload.consented
    assert cookie.functional
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceBrowserBinding::COOKIE_NAME}="
  end

  test "an active com preference supplies consent to its matching browser on the settings screen" do
    raw = PreferenceBrowserBinding.mint_value
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      status_id: ComPreferenceStatus::ACTIVE,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    ComPreferenceCookie.create!(
      preference: preference, consented: true, functional: true,
    )
    ComPreferenceConsentReceipt.create!(preference: preference, version: SecureRandom.uuid, recorded_at: Time.current)
    ComPreferenceBrowserBinding.create!(preference: preference, digest: PreferenceBrowserBinding.digest_for(raw))
    cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: @host, preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: preference.public_id, jti: preference.jti,
    )
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = raw
    cookies[PreferenceCookieName.anonymous_experience] = '{"theme":"dark"}'

    rendered_preferences = []
    capture = ->(*) { rendered_preferences << Actor.preferences }
    ActiveSupport::Notifications.subscribed(capture, "render_template.action_view") do
      get edit_base_com_preference_cookie_path(ri: "jp")
    end

    assert_response :ok
    page = JSON.parse(response.parsed_body.at_css("script[data-page]").text)
    categories = page.fetch("props").fetch("form").fetch("categories")

    assert categories.find { |category| category.fetch("key") == "consented" }.fetch("value")
    assert categories.find { |category| category.fetch("key") == "functional" }.fetch("value")
    assert rendered_preferences.any? { |value| value.cookie.consented? && value.cookie.functional? }
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceBrowserBinding::COOKIE_NAME}="

    token = cookies[PreferenceCookieName.anonymous_jwt]
    reset!
    host! @host
    https!
    cookies[PreferenceCookieName.anonymous_jwt] = token
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = PreferenceBrowserBinding.mint_value
    rendered_preferences.clear
    ActiveSupport::Notifications.subscribed(capture, "render_template.action_view") do
      get edit_base_com_preference_cookie_path(ri: "jp")
    end

    assert_response :ok
    assert_not_empty rendered_preferences
    assert rendered_preferences.all? { |value| !value.cookie.consented? && !value.cookie.functional? }
  end

  test "the consent screen rechecks expiry after the initial preference lookup" do
    now = ComPreference.database_now
    raw = PreferenceBrowserBinding.mint_value
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: now + 10.minutes,
      status_id: ComPreferenceStatus::ACTIVE,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    ComPreferenceCookie.create!(
      preference: preference, consented: true,
    )
    ComPreferenceBrowserBinding.create!(preference: preference, digest: PreferenceBrowserBinding.digest_for(raw))
    cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: @host, preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: preference.public_id, jti: preference.jti,
    )
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = raw
    cookies[PreferenceCookieName.anonymous_experience] = '{"theme":"dark"}'
    expiry = preference.reload.last_issued_expires_at
    calls = 0
    clock =
      lambda do
        calls += 1
        (calls == 1) ? expiry - Rational(1, 1_000_000) : expiry
      end

    ComPreference.stub(:database_now, clock) do
      get edit_base_com_preference_cookie_path(ri: "jp")
    end

    assert_response :ok
    assert_operator calls, :>=, 2
    page = JSON.parse(response.parsed_body.at_css("script[data-page]").text)
    categories = page.fetch("props").fetch("form").fetch("categories")

    assert categories.none? { |category| category.fetch("value") }
  end
end

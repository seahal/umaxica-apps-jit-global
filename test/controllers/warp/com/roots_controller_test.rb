# typed: false
# frozen_string_literal: true

require "test_helper"

class Warp::Com::RootsControllerTest < ActionDispatch::IntegrationTest
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
    @host = ENV.fetch("PUBLIC_WARP_CORPORATE_URL")
  end

  test "renders the anonymous public landing" do
    host! @host

    get warp_com_root_path(ri: "jp")

    assert_response :success
    assert_equal "warp/com/roots/index", inertia_component
    assert_equal "Warp Com", inertia_props.fetch("heading")
    assert_equal I18n.t("base.com.roots.message"), inertia_props.fetch("description")
    assert_nil inertia_props["sign_up"]
    assert_nil inertia_props.fetch("chrome").fetch("account_navigation"), "the anonymous com surface has no sign-in"
    assert_equal(
      [[I18n.t("ui_presentation.navigation.preferences"),
        base_com_preference_url(ri: "jp", host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), protocol: "http"),]],
      inertia_props.fetch("links").map { |link| [link.fetch("label"), link.fetch("href")] },
    )
  end

  test "the retired com settings page is not routed" do
    host! @host

    get "/settings", params: { ri: "jp" }

    assert_response :not_found
  end

  test "a signed com preference renders on warp without accessing the setting database" do
    host! @host
    https!
    token = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark", "language" => "en", "currency" => "usd" }),
      host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
      preference_type: "ComPreference",
      issued_at: Time.current,
      public_id: "independent-row",
      jti: SecureRandom.uuid,
    )
    cookies[PreferenceCookieName.anonymous_jwt] = token
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = PreferenceBrowserBinding.mint_value
    cookies[PreferenceCookieName.anonymous_experience] = {
      consented: true, functional: true, performant: true, targetable: true, web_push: "enabled",
    }.to_json
    queries = []
    rendered_preferences = []
    listener =
      lambda do |_name, _start, _finish, _id, payload|
        queries << payload[:sql] if payload[:sql].to_s.match?(/com_preference/i)
      end

    capture = ->(*) { rendered_preferences << Actor.preferences }
    ActiveSupport::Notifications.subscribed(listener, "sql.active_record") do
      ActiveSupport::Notifications.subscribed(capture, "render_template.action_view") do
        get warp_com_root_path(ri: "jp")
      end
    end

    assert_response :success
    assert_select "html[lang=ja][data-theme=dark]"
    assert rendered_preferences.any? { |preference|
      preference.language == "ja" && preference.theme == "dr" && preference.currency == "usd" &&
        preference.web_push == "disabled" && !preference.cookie.consented? && !preference.cookie.functional? &&
        !preference.cookie.performant? && !preference.cookie.targetable?
    }
    assert_empty queries
    [PreferenceCookieName.anonymous_jwt, PreferenceCookieName.anonymous_experience,
     PreferenceBrowserBinding::COOKIE_NAME, PreferenceIoKeys::Cookies::LANGUAGE,].each do |name|
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{name}="
    end
  end

  test "the settings shell reads signed com preferences without querying the setting database" do
    host! @host
    https!
    cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge("theme" => "dark", "language" => "en"),
      host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), preference_type: "ComPreference",
      issued_at: Time.current, public_id: "settings-reader-row", jti: SecureRandom.uuid,
    )
    queries = []
    databases = []
    listener =
      lambda do |_name, _start, _finish, _id, payload|
        queries << payload[:sql] if payload[:sql].to_s.match?(/com_preference/i)
        connection = payload[:connection]
        databases << connection.pool.db_config.name if connection
      end

    ActiveSupport::Notifications.subscribed(listener, "sql.active_record") do
      get warp_com_root_path(ri: "jp")
    end

    assert_response :success
    assert_select "html[lang=ja][data-theme=dark]"
    assert_empty queries
    assert_not_includes databases, "com_setting"
    assert_not_includes databases, "com_setting_replica"
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "duplicate warp com preference cookies are rejected without issuing a replacement" do
    host! @host
    name = PreferenceCookieName.anonymous_jwt
    get warp_com_root_path(ri: "jp"), headers: { "Cookie" => "#{name}=first; #{name}=second" }

    assert_response :bad_request
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{name}="
  end

  test "an invalid warp com preference JWT renders defaults without changing its cookie" do
    host! @host
    cookies[PreferenceCookieName.anonymous_jwt] = "invalid"
    rendered_preferences = []
    capture = ->(*) { rendered_preferences << Actor.preferences }
    ActiveSupport::Notifications.subscribed(capture, "render_template.action_view") do
      get warp_com_root_path(ri: "jp")
    end

    assert_response :success
    assert_select "html[data-theme=system]"
    assert rendered_preferences.any? { |preference| preference.language == "ja" && preference.theme == "sy" }
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "warp logs missing or invalid display cookies without repairing them or exposing their values" do
    preferences = DISPLAY_SNAPSHOT.merge({ "theme" => "dark" })
    token = PreferenceToken.encode(
      preferences, host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), preference_type: "ComPreference",
                   issued_at: Time.current, public_id: "independent-row", jti: SecureRandom.uuid,
    )
    malformed = '{"theme":"private-sentinel","theme":"duplicate"}'
    cases = [
      [nil, nil, true],
      ["ja", malformed, true],
      ["ja", "private-sentinel" * 300, true],
      ["en", preferences.except("language").to_json, true],
      ["ja", preferences.except("language").to_json, false],
    ]

    cases.each do |language, experience, expected_error|
      browser = open_session
      browser.host!(@host)
      browser.https!
      browser.cookies[PreferenceCookieName.anonymous_jwt] = token
      browser.cookies[PreferenceIoKeys::Cookies::LANGUAGE] = language if language
      browser.cookies[PreferenceCookieName.anonymous_experience] = experience if experience
      errors = []

      Rails.logger.stub(:error, ->(message) { errors << message.to_s }) do
        browser.get(warp_com_root_path(ri: "jp"))
      end

      assert_equal 200, browser.response.status
      assert_equal expected_error, errors.any? { |message| message.include?("preference.display_cookie.unavailable") }
      assert_not_includes errors.join, token
      assert_not_includes errors.join, "private-sentinel"
      [PreferenceCookieName.anonymous_jwt, PreferenceCookieName.anonymous_experience,
       PreferenceIoKeys::Cookies::LANGUAGE,].each do |name|
        assert_not_includes browser.response.headers["Set-Cookie"].to_s, "#{name}="
      end
    end
  end

  test "a request overlay changes the actor display without changing the signed token" do
    host! @host
    token = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge("language" => "en", "theme" => "dark"),
      host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), preference_type: "ComPreference",
      issued_at: Time.current,
      public_id: "independent-row", jti: SecureRandom.uuid,
    )
    cookies[PreferenceCookieName.anonymous_jwt] = token
    rendered_preferences = []
    capture = ->(*) { rendered_preferences << Actor.preferences }
    ActiveSupport::Notifications.subscribed(capture, "render_template.action_view") do
      get warp_com_root_path(ri: "jp", lx: "ja", ct: "li")
    end

    assert_response :success
    assert rendered_preferences.any? { |preference| preference.language == "ja" && preference.theme == "li" }
    assert_equal token, cookies[PreferenceCookieName.anonymous_jwt]
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "root is private and carries no signed-in content" do
    host! @host

    get warp_com_root_url(ri: "jp")

    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_not inertia_props.key?("sections")
  end

  test "an injected relying-party credential cookie does not change the anonymous result" do
    host! @host

    get warp_com_root_url(ri: "jp"), headers: {
      "Cookie" => [
        "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=injected-access-token",
        "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=injected-refresh-token",
      ].join("; "),
    }

    assert_response :success
    assert_equal "warp/com/roots/index", inertia_component
    assert_equal "Warp Com", inertia_props.fetch("heading")
  end

  test "a malformed bearer renders the anonymous landing" do
    host! @host

    get warp_com_root_url(ri: "jp"), headers: { "Authorization" => "Bearer not-a-jwt" }

    assert_response :success
    assert_equal "warp/com/roots/index", inertia_component
  end

  test "unrelated query parameters do not select a signed-in representation" do
    host! @host

    get warp_com_root_url(ri: "jp", signed_in: "1", dashboard: "1")

    assert_response :success
    assert_equal "warp/com/roots/index", inertia_component
  end

  test "the removed signed-in, preference API, and OIDC routes are not routable" do
    %w(/dashboard /sign /sign_out /api/v0/preferences/theme /.well-known/jwks.json).each do |path|
      assert_raises(ActionController::RoutingError, "#{path} should not be routable") do
        Rails.application.routes.recognize_path(path, method: :get, host: @host)
      end
    end
  end
end

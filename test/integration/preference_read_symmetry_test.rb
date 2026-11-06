# typed: false
# frozen_string_literal: true

require "test_helper"

# The rendered theme/language value must come from the expected authority for
# the caller's state: the anonymous token snapshot for a visitor, and the
# option-backed actor preference after an authenticated write.
class PreferenceReadSymmetryTest < ActionDispatch::IntegrationTest
  setup do
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
  end

  test "anonymous theme read reflects the value just written on the same anonymous session" do
    get edit_base_app_preference_theme_url(ri: "jp")

    assert_response :success

    patch base_app_preference_theme_url(ri: "jp"),
          params: { preference_theme: { option_id: AppPreferenceThemeOption::DARK.to_s } }

    assert_response :redirect

    get base_app_api_v0_preferences_theme_url(ri: "jp")

    assert_response :success
    assert_equal "dr", response.parsed_body["theme"]
  end

  test "Base HTML projection keeps browser defaults when receipt storage is unavailable" do
    AppPreferenceStatus.ensure_defaults!
    AppPreferenceRegionOption.ensure_defaults!
    AppPreferenceWebPushOption.ensure_defaults!

    preference = AppPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    AppPreferenceRegion.create!(preference:, option_id: AppPreferenceRegionOption::US)
    AppPreferenceCookie.create!(
      preference:, consented: true, functional: true, performant: false, targetable: false,
    )
    AppPreferenceConsentReceipt.create!(
      preference:, version: SecureRandom.uuid, recorded_at: Time.current,
    )
    raw_binding = PreferenceBrowserBinding.mint_value
    AppPreferenceBrowserBinding.create!(
      preference:, digest: PreferenceBrowserBinding.digest_for(raw_binding),
    )
    AppPreferenceWebPush.create!(preference:, option_id: AppPreferenceWebPushOption::ENABLED)

    cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
      {
        "theme" => "dark",
        "language" => "en",
        "timezone" => "Asia/Tokyo",
        "currency" => "jpy",
        "date_format" => "iso",
        "time_format" => "24",
        "motion" => "standard",
        "density" => "standard",
        "page_size" => "infinity",
      },
      host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), preference_type: "AppPreference", issued_at: Time.current,
      public_id: preference.public_id, jti: preference.jti,
    )
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = raw_binding

    snapshots = []
    capture = ->(*) { snapshots << Actor.preferences }
    unavailable_receipts = ->(*) { raise ActiveRecord::ConnectionNotEstablished, "receipt store unavailable" }

    ActiveSupport::Notifications.subscribed(capture, "render_template.action_view") do
      AppPreferenceConsentReceipt.stub(:find_by, unavailable_receipts) do
        get edit_base_app_preference_theme_url(ri: "us")
      end
    end

    assert_response :success
    assert_not_empty snapshots
    assert snapshots.all? { |snapshot| snapshot.theme == "dr" }
    assert snapshots.all? { |snapshot| !snapshot.cookie.consented? }
    assert snapshots.all? { |snapshot| snapshot.web_push == "disabled" }
  end

  test "Base app and org HTML requests project their bound browser state and saved region into Actor preferences" do
    realms = [
      {
        host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
        preference_class: AppPreference,
        status_class: AppPreferenceStatus,
        region_option_class: AppPreferenceRegionOption,
        region_us_id: AppPreferenceRegionOption::US,
        region_class: AppPreferenceRegion,
        cookie_class: AppPreferenceCookie,
        receipt_class: AppPreferenceConsentReceipt,
        binding_class: AppPreferenceBrowserBinding,
        web_push_class: AppPreferenceWebPush,
        web_push_option_class: AppPreferenceWebPushOption,
        web_push_enabled_id: AppPreferenceWebPushOption::ENABLED,
        path_helper: :edit_base_app_preference_cookie_path,
        jwt_type: "AppPreference",
      },
      {
        host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
        preference_class: OrgPreference,
        status_class: OrgPreferenceStatus,
        region_option_class: OrgPreferenceRegionOption,
        region_us_id: OrgPreferenceRegionOption::US,
        region_class: OrgPreferenceRegion,
        cookie_class: OrgPreferenceCookie,
        receipt_class: OrgPreferenceConsentReceipt,
        binding_class: OrgPreferenceBrowserBinding,
        web_push_class: OrgPreferenceWebPush,
        web_push_option_class: OrgPreferenceWebPushOption,
        web_push_enabled_id: OrgPreferenceWebPushOption::ENABLED,
        path_helper: :edit_base_org_preference_cookie_path,
        jwt_type: "OrgPreference",
      },
    ]

    realms.each do |realm|
      reset!
      host! realm.fetch(:host)
      https!
      [realm.fetch(:status_class), realm.fetch(:region_option_class), realm.fetch(:web_push_option_class)]
        .each do |klass|
        klass.ensure_defaults!
      end

      preference = realm.fetch(:preference_class).create!(
        last_issued_at: Time.current,
        last_issued_expires_at: 400.days.from_now,
        jti: JitSecurityJwtJtiGenerator.generate,
      )
      realm.fetch(:region_class).create!(
        preference: preference, option_id: realm.fetch(:region_us_id),
      )
      realm.fetch(:cookie_class).create!(
        preference: preference, consented: true, functional: true, performant: false, targetable: false,
      )
      receipt = realm.fetch(:receipt_class).create!(
        preference: preference, version: SecureRandom.uuid, recorded_at: Time.current,
      )
      raw_binding = PreferenceBrowserBinding.mint_value
      realm.fetch(:binding_class).create!(
        preference: preference, digest: PreferenceBrowserBinding.digest_for(raw_binding),
      )
      realm.fetch(:web_push_class).create!(
        preference: preference, option_id: realm.fetch(:web_push_enabled_id),
      )
      cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
        {
          "theme" => "dark",
          "language" => "en",
          "timezone" => "Asia/Tokyo",
          "currency" => "jpy",
          "date_format" => "iso",
          "time_format" => "24",
          "motion" => "standard",
          "density" => "standard",
          "page_size" => "infinity",
        },
        host: realm.fetch(:host), preference_type: realm.fetch(:jwt_type), issued_at: Time.current,
        public_id: preference.public_id, jti: preference.jti,
      )
      cookies[PreferenceBrowserBinding::COOKIE_NAME] = raw_binding
      cookies[PreferenceIoKeys::Cookies::LANGUAGE] = "en"
      cookies[PreferenceCookieName.anonymous_experience] = {
        "theme" => "dark",
        "timezone" => "Asia/Tokyo",
        "currency" => "jpy",
        "date_format" => "iso",
        "time_format" => "24",
        "motion" => "standard",
        "density" => "standard",
        "page_size" => "infinity",
      }.to_json

      snapshots = []
      capture = ->(*) { snapshots << Actor.preferences }
      ActiveSupport::Notifications.subscribed(capture, "render_template.action_view") do
        get public_send(realm.fetch(:path_helper))

        assert_response :redirect
        assert_includes response.location, "ri=us"
        follow_redirect!
      end

      assert_response :success
      assert_not_empty snapshots
      assert snapshots.all? { |snapshot| snapshot.region == "us" }
      assert snapshots.all? { |snapshot| snapshot.web_push == "enabled" }
      assert snapshots.all? { |snapshot| snapshot.cookie.consented? && snapshot.cookie.functional? }
      assert snapshots.all? { |snapshot| snapshot.cookie.consent_version == receipt.version }
      assert snapshots.all? { |snapshot| snapshot.cookie.consented_at == receipt.recorded_at }

      cookies[PreferenceBrowserBinding::COOKIE_NAME] = PreferenceBrowserBinding.mint_value
      snapshots.clear
      ActiveSupport::Notifications.subscribed(capture, "render_template.action_view") do
        get public_send(realm.fetch(:path_helper), ri: "us")
      end

      assert_response :success
      assert_not_empty snapshots
      assert snapshots.all? { |snapshot| snapshot.region == "us" }
      assert snapshots.all? { |snapshot| snapshot.web_push == "disabled" }
      assert snapshots.all? { |snapshot| !snapshot.cookie.consented? && !snapshot.cookie.functional? }
    end
  end

  # The JS-readable `language` cookie is a write-only mirror for the browser. Rails resolves the
  # locale from the preference JWT (via Actor.preferences) and the `?lx` overlay only; a stale or
  # forged `language` cookie must not become a second source of truth that overrides it. The
  # resolution code is shared by the base, auth, and Warp application controllers.
  test "a conflicting language cookie does not override the region-seeded locale" do
    cookies[PreferenceIoKeys::Cookies::LANGUAGE] = "en"

    get edit_base_app_preference_theme_url(ri: "jp")

    assert_response :success
    assert_select "html[lang=?]", "ja"
  end

  test "a regional request overlay wins over the saved language for that request" do
    # An anonymous session that explicitly chose English on the language screen.
    get edit_base_app_preference_language_url(ri: "jp")
    patch base_app_preference_language_url(ri: "jp"),
          params: { preference_language: { option_id: AppPreferenceLanguageOption::EN.to_s } }

    assert_response :redirect

    cookies[PreferenceIoKeys::Cookies::LANGUAGE] = "ja"

    get edit_base_app_preference_theme_url(ri: "jp")

    assert_response :success
    assert_select "html[lang=?]", "ja"
  end

  test "signed-in theme read reflects the explicitly saved actor value" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    rp_cookie =
      begin
        fixture_root = token
        fixture_actor = user
        fixture_host = host
        fixture_root.rotate_refresh_token! unless fixture_root.device_session.current_refresh_token_id
        fixture_client = OidcClientRegistry.find!("base-app-ww")
        @base_rp_fixture_credentials ||= {}
        fixture_key = [fixture_client.client_id, fixture_root.public_id]
        unless @base_rp_fixture_credentials[fixture_key]
          fixture_now = OpAppGrant.database_now
          fixture_rp = OpAppGrant.create!(
            authentication_epoch: 0,
            client_token: fixture_root, oidc_client_id: fixture_client.client_id,
            oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
            oidc_nonce: SecureRandom.hex(16), oidc_auth_time: fixture_now,
            refresh_token_expires_at: fixture_now + 1.hour,
          )
          fixture_access = AuthenticationTokenService.encode(
            fixture_actor, host: fixture_host, resource_type: "client",
                           session_public_id: fixture_root.public_id, base_session_public_id: fixture_root.public_id,
                           oidc_sid: fixture_rp.public_id, oidc_jti: fixture_rp.oidc_jti,
                           expires_at: fixture_now + 1.hour, scopes: %w(openid profile),
                           issuer: OidcIssuer.for_client(fixture_client), audiences: [fixture_client.aud],
                           jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fixture_client),
                           subject: OidcSubject.for(
                             fixture_actor,
                             resource_type: "client",
                           ), client_id: fixture_client.client_id,
          )
          fixture_refresh = fixture_rp.issue_refresh_token!
          @base_rp_fixture_credentials[fixture_key] =
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(fixture_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(fixture_refresh)}",
            ].join("; ")
        end
        @base_rp_fixture_credentials.fetch(fixture_key)
      end
    headers = { "Cookie" => rp_cookie }

    patch base_app_preference_theme_url(ri: "jp"), headers: headers, as: :json,
                                                   params: { preference_theme: { option_id: AppPreferenceThemeOption::DARK.to_s } }

    assert_response :ok
    assert_equal "dr", response.parsed_body.dig("preference", "ct"),
                 "signed-in write's own response must reflect the value it just wrote"

    headers["Cookie"] = ([rp_cookie] + cookies.to_hash.map { |name, value|
      "#{name}=#{Rack::Utils.escape(value)}"
    }).join("; ")
    get base_app_api_v0_preferences_theme_url(ri: "jp"), headers: headers

    assert_response :success
    assert_equal "dr", response.parsed_body["theme"],
                 "signed-in read must reflect the value written through the same session"

    actor_preference = ClientPreference.includes(:client_preference_theme).find_by!(client_id: user.id)

    assert_equal ClientPreferenceThemeOption::DARK, actor_preference.client_preference_theme.option_id
  end
end

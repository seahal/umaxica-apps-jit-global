# typed: false
# frozen_string_literal: true

require "test_helper"

# The rendered theme/language value must come from the expected authority for
# the caller's state: the token-side preference for an anonymous visitor, and
# the same token-side preference (now adopted/synced with the resource mirror)
# once signed in. Both reads should agree on the value the user actually set.
class PreferenceReadSymmetryTest < ActionDispatch::IntegrationTest
  setup do
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
  end

  test "anonymous theme read reflects the value just written on the same anonymous session" do
    get edit_base_app_preference_theme_url(ri: "jp")

    assert_response :success

    patch base_app_preference_theme_url(ri: "jp"),
          params: { preference_theme: { option_id: "dr" } }

    assert_response :redirect

    get base_app_api_v0_preferences_theme_url(ri: "jp")

    assert_response :success
    assert_equal "dr", response.parsed_body["theme"]
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

  test "a conflicting language cookie does not override an explicit saved language" do
    # An anonymous session that explicitly chose English on the language screen.
    get edit_base_app_preference_language_url(ri: "jp")
    patch base_app_preference_language_url(ri: "jp"),
          params: { preference_language: { option_id: AppPreferenceLanguageOption::EN.to_s } }

    assert_response :redirect

    cookies[PreferenceIoKeys::Cookies::LANGUAGE] = "ja"

    get edit_base_app_preference_theme_url(ri: "jp")

    assert_response :success
    assert_select "html[lang=?]", "en"
  end

  test "signed-in theme read reflects the same token-side value after adoption" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
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
                                                   params: { preference_theme: { option_id: "dr" } }

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

    assert_equal "dr", user.reload.user_preference.theme,
                 "resource mirror (DB canonical for the signed-in user) must match the token-side write"
  end
end

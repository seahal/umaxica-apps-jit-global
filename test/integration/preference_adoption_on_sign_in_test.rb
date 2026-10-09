# typed: false
# frozen_string_literal: true

require "test_helper"

# A signed-in request that arrives without a browser preference record creates
# one, and that creation reconciles it with the principal's own preference
# (PreferenceTransport#restore_preference_from_resource! -> PreferenceAdoption).
# These pin what the reconciliation does to the stored records on a new browser
# session, and that an anonymous session keeps serving its own value.
class PreferenceAdoptionOnSignInTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds, :client_token_statuses,
           :client_token_binding_methods, :client_token_dbsc_statuses,
           :app_preference_chronicle_events, :app_preference_chronicle_levels

  setup do
    https!
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @user = clients(:one)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    rp_cookie =
      begin
        fixture_root = @token
        fixture_actor = @user
        fixture_host = @host
        fixture_root.rotate_refresh_token! unless fixture_root.device_session.current_refresh_token_id
        fixture_client = OidcClientRegistry.find!("base-app-ww")
        @base_rp_fixture_credentials ||= {}
        fixture_key = [fixture_client.client_id, fixture_root.public_id]
        unless @base_rp_fixture_credentials[fixture_key]
          fixture_now = ClientRpSession.database_now
          fixture_rp = ClientRpSession.create!(
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
    @headers = { "Cookie" => rp_cookie, "Accept" => "application/json" }.freeze
  end

  test "a signed-in theme write reaches the principal's own preference record" do
    patch base_app_preference_theme_url(ri: "jp"), headers: @headers, as: :json,
                                                   params: { preference_theme: { option_id: "dr" } }

    assert_response :ok
    assert_equal "dr", @user.reload.user_preference.theme
  end

  test "a signed-in language write reaches the principal's own preference record" do
    patch base_app_preference_language_url(ri: "jp"), headers: @headers, as: :json,
                                                      params: { preference_language: { option_id: "en" } }

    assert_response :redirect
    assert_equal "en", @user.reload.user_preference.language
  end

  test "a fresh browser session reconciles against the principal record without losing it" do
    patch base_app_preference_theme_url(ri: "jp"), headers: @headers, as: :json,
                                                   params: { preference_theme: { option_id: "dr" } }

    assert_response :ok

    reset!
    https!
    host! @host

    get base_app_api_v0_preferences_theme_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_predicate response.parsed_body["theme"], :present?
    assert_equal "dr", @user.reload.user_preference.theme
  end

  test "a fresh browser session for a signed-in principal answers a theme and keeps the principal record" do
    reset!
    https!
    host! @host

    get base_app_api_v0_preferences_theme_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_predicate response.parsed_body["theme"], :present?
    assert_predicate @user.reload.user_preference, :present?
  end

  test "an anonymous browser session serves the value it just wrote" do
    patch base_app_preference_theme_url(ri: "jp"), params: { preference_theme: { option_id: "dr" } }

    assert_response :redirect

    get base_app_api_v0_preferences_theme_url(ri: "jp")

    assert_response :success
    assert_equal "dr", response.parsed_body["theme"]
  end

  test "a signed-in cookie consent write reaches the principal's own preference record" do
    patch base_app_preference_cookie_url(ri: "jp"), headers: @headers, as: :json,
                                                    params: {
                                                      preference_cookie: {
                                                        consented: "1",
                                                        functional: "1",
                                                        performant: "1",
                                                        targetable: "0",
                                                      },
                                                    }

    assert_response :ok
    preference = @user.reload.user_preference

    assert preference.consented
    assert preference.functional
    assert_not preference.targetable
  end
  test "a fresh browser session takes over the principal's explicit language and recorded consent" do
    patch base_app_preference_language_url(ri: "jp"), headers: @headers, as: :json,
                                                      params: { preference_language: { option_id: "en" } }
    patch base_app_preference_cookie_url(ri: "jp"), headers: @headers, as: :json,
                                                    params: {
                                                      preference_cookie: {
                                                        consented: "1",
                                                        functional: "1",
                                                        performant: "1",
                                                        targetable: "0",
                                                      },
                                                    }

    assert_predicate @user.reload.user_preference, :present?

    reset!
    https!
    host! @host

    get base_app_api_v0_preferences_theme_url(ri: "jp"), headers: @headers

    assert_response :success
    browser = AppPreference.order(:created_at).last

    assert_equal AppPreferenceLanguageOption::EN, browser.app_preference_language.option_id
    cookie = browser.app_preference_cookie

    assert_predicate cookie, :consented?
    assert_predicate cookie, :functional?
    assert_predicate cookie, :performant?
    assert_not_predicate cookie, :targetable?
  end
end

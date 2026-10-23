# typed: false
# frozen_string_literal: true

require "test_helper"

# Logout keeps guest-safe display preferences (language/timezone/theme) as
# designed: they are written from the token-side preference regardless of
# sign-in state, so there is no separate "signed-in" copy to purge. Auth
# transport cookies (the session/refresh credentials) are the only things a
# logout must clear.
class PreferenceLogoutDowngradeTest < ActionDispatch::IntegrationTest
  setup do
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
  end

  test "logout keeps guest-safe display cookies and clears the session cookie" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    headers = as_user_headers(user, host: host, session_public_id: token.public_id)
    rp_client = OidcClientRegistry.find!("base-app-ww")
    token.rotate_refresh_token! unless token.device_session.current_refresh_token_id
    rp_session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: token, oidc_client_id: rp_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.current, refresh_token_expires_at: 10.minutes.from_now,
    )
    rp_access = AuthenticationTokenService.encode(
      user, host: host, resource_type: "client", session_public_id: token.public_id,
            base_session_public_id: token.public_id, oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
            expires_at: 10.minutes.from_now, scopes: %w(openid profile), issuer: OidcIssuer.for_client(rp_client),
            audiences: [rp_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
            subject: OidcSubject.for(user, resource_type: "client"), client_id: rp_client.client_id,
    )
    rp_cookie = [headers.fetch("Cookie"),
                 "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
                 "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(
                   rp_session
                                      .issue_refresh_token!,
                 )}",].join("; ")
    headers = headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
    headers.fetch("Cookie").split("; ").each do |pair|
      name, value = pair.split("=", 2)
      cookies[name] = Rack::Utils.unescape(value)
    end
    csrf_token = fetch_csrf_token(edit_base_app_preference_theme_url(ri: "jp"), headers: headers)

    assert_response :success

    patch base_app_preference_theme_url(ri: "jp"),
          headers: csrf_request_headers(csrf_token),
          params: { preference_theme: { option_id: "dr" }, authenticity_token: csrf_token }

    assert_response :redirect

    theme_cookie_before = cookies[PreferenceBase::THEME_COOKIE_KEY]

    assert_equal "dr", theme_cookie_before

    post base_app_sign_out_url,
         headers: csrf_request_headers(csrf_token)

    assert_response :see_other
    assert_not_predicate token.reload, :revoked?
    2.times do
      follow_redirect!

      assert_response :success
      form = response.parsed_body.at_css("form")
      if form
        fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        action = form["action"]
      else
        receiver = inertia_props.fetch("form")
        fields = {
          logout_challenge: receiver.fetch("logout_challenge"),
          logout_intent_proof: receiver.fetch("logout_intent_proof"),
          ri: "jp",
        }
        action = receiver.fetch("action")
      end
      fields = fields.transform_keys(&:to_s)
      fields["authenticity_token"] ||= csrf_token
      post action, params: fields, headers: {
        "Origin" => "https://#{request.host}",
        "Sec-Fetch-Site" => "same-origin",
        "X-CSRF-Token" => csrf_token,
      }

      assert_response :see_other
    end
    assert_equal "/sign/out/completion", URI.parse(response.location).path
    assert_equal "dr", cookies[PreferenceBase::THEME_COOKIE_KEY],
                 "guest-safe display preference must survive logout (contract: keep-values)"
  end

  test "logout does not delete or reset the preference record's stored values" do
    csrf_token = fetch_csrf_token(base_app_root_path)

    assert_response :success

    patch base_app_preference_theme_url(ri: "jp"),
          headers: csrf_request_headers(csrf_token),
          params: { preference_theme: { option_id: "dr" }, authenticity_token: csrf_token }

    assert_response :redirect

    preference = AppPreference.order(:created_at).last
    theme_option_id_before = AppPreferenceTheme.find_by!(preference_id: preference.id).option_id

    post base_app_sign_out_url, headers: csrf_request_headers(csrf_token)

    assert_response :unauthorized
    assert_nil response.headers["Location"]

    preference.reload

    assert_equal theme_option_id_before, AppPreferenceTheme.find_by!(preference_id: preference.id).option_id
    assert_not_equal AppPreferenceStatus::DELETED, preference.status_id
  end

  private

  def fetch_csrf_token(path, headers: {})
    ActionController::Base.allow_forgery_protection = true
    get(path, headers: headers)
    csrf_token = response.body[/<meta name="csrf-token" content="([^"]+)"/, 1] ||
      response.body[/name="authenticity_token" value="([^"]+)"/, 1]

    assert_predicate csrf_token, :present?,
                     "expected a CSRF token in the response (status #{response.status}, #{response.media_type})"
    csrf_token
  ensure
    ActionController::Base.allow_forgery_protection = Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_request_headers(token)
    {
      "Origin" => "https://#{request.host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => token,
    }
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::App::IdentityAuthoritySlice1ATest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    @user = clients(:one)
    host! @host
    https!
  end

  # Base is the session authority: it revokes directly and keeps the ceremony surface-local.
  # See adr/logout-ceremony-boundary.md.
  test "base_sign_out_create_is_session_mutation_and_completes_on_the_base_surface" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!
    headers = session_headers(token)
    headers.fetch("Cookie").split("; ").each do |pair|
      name, value = pair.split("=", 2)
      cookies[name] = Rack::Utils.unescape(value)
    end
    csrf_token = fetch_csrf_token(edit_base_app_sign_out_url(ri: "jp"), headers: headers)

    post base_app_sign_out_url(ri: "jp"), headers: {
      "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf_token,
    }

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
        fields = { logout_challenge: receiver.fetch("logout_challenge"), ri: "jp" }
        fields["logout_intent_proof"] = receiver["logout_intent_proof"] if
          receiver["logout_intent_proof"].present?
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
    assert_predicate token.reload, :revoked?
    location = URI.parse(response.location)

    assert_equal @host, location.host
    assert_equal base_app_sign_out_completion_path(ri: "jp"), location.request_uri
    assert_nil Rack::Utils.parse_nested_query(location.query.to_s)["logout_token"]
  end

  private

  def fetch_csrf_token(path, headers: {})
    ActionController::Base.allow_forgery_protection = true
    get(path, headers: headers)
    csrf_token = response.body[/<meta name="csrf-token" content="([^"]+)"/, 1] ||
      response.body[/name="authenticity_token" value="([^"]+)"/, 1]

    assert_predicate csrf_token, :present?, "expected a CSRF token in the response"
    csrf_token
  ensure
    ActionController::Base.allow_forgery_protection = Rails.configuration.action_controller.allow_forgery_protection
  end

  def session_headers(token, user: @user, host: @host)
    headers = as_user_headers(user, host: host, session_public_id: token.public_id)
    rp_client = OidcClientRegistry.find!("base-app-ww")
    token.rotate_refresh_token! unless token.device_session.current_refresh_token_id
    rp_session = ClientRpSession.create!(
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
    headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)

  end

  def host_headers(host = nil)
    host.present? ? { "Host" => host } : {}
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  # Base shares its production origin with Acme (both `https://www.umaxica.<tld>`), so the
  # issuer namespace cannot be inferred from a host substring like "base". Match against the
  # actual configured Base hosts first; fall back to substring heuristics for surfaces whose
  # hosts are texually distinct (acme/core/sign).
  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    base_hosts = {
      "APP" => ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
      "ORG" => ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
      "COM" => ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
    }
    return "surface:BASE_#{base_hosts.key(normalized)}" if base_hosts.value?(normalized)

    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end
end

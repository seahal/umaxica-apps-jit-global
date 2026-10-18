# frozen_string_literal: true

# Drives the real Browser RP sign-out ceremony across the Core origin and the Base authority with
# real session writes and token issuance. Callers set @core_host, @base_host, @user and @root_token
# and create their RP sessions with create_rp_session.
module BrowserRpLogoutFlowHelper
  private

  def create_rp_session(client_id, root_token: @root_token)
    client = OidcClientRegistry.find!(client_id)
    OpAppGrant.create!(
      client_token: root_token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
  end

  def sign_in_core_rp(rp_session, root_token: @root_token, user: @user)
    client = OidcClientRegistry.find!("core-app-jp")
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      user,
      host: @core_host,
      resource_type: "client",
      session_public_id: root_token.public_id,
      base_session_public_id: root_token.public_id,
      oidc_sid: rp_session.public_id,
      oidc_jti: rp_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(user, resource_type: "client"),
      client_id: client.client_id,
    )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_session.issue_refresh_token!
  end

  def start_sign_out(rp_session = @core_session, root_token: @root_token)
    host!(@core_host)
    sign_in_core_rp(rp_session, root_token: root_token)
    post(core_app_sign_out_url(ri: "jp"))

    assert_response :see_other
    query = Rack::Utils.parse_nested_query(URI.parse(response.location).query.to_s)
    [query.fetch("logout_challenge"), session_cookie_pair]
  end

  def base_authority_headers(root_token: @root_token, user: @user)
    access_token = AuthenticationToken.encode(
      user,
      host: @base_host,
      session_public_id: root_token.device_session_record.public_id,
      oidc_sid: root_token.device_session_record.public_id,
      oidc_jti: root_token.oidc_jti,
      resource_type: "client",
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      authentication_context: root_token.authentication_context_value.to_s,
    )
    cookie = "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(access_token)}"
    { "Host" => @base_host, "Cookie" => cookie, "HTTP_COOKIE" => cookie }
  end

  def confirm_at_authority(challenge, origin_session_cookie, headers: base_authority_headers, params: {})
    host!(@base_host)
    post(
      base_app_oidc_logout_path(logout_challenge: challenge, ri: "jp"),
      params: params,
      headers: with_session_cookie(origin_headers("same-site").merge(headers), session_cookie: origin_session_cookie),
    )
  end

  def origin_headers(fetch_site)
    { "Origin" => "https://#{@core_host}", "Sec-Fetch-Site" => fetch_site }
  end

  def session_cookie_pair
    key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
    value = cookies.to_hash[key]
    return if value.blank?

    "#{key}=#{Rack::Utils.escape(value)}"
  end

  def with_session_cookie(headers, session_cookie:)
    return headers if session_cookie.blank?

    cookie = headers["Cookie"].presence || headers["HTTP_COOKIE"].to_s
    cookie = cookie.split(/;\s*/).reject { |entry| entry.start_with?("#{session_cookie.split("=", 2).first}=") }
    cookie << session_cookie
    value = cookie.join("; ")
    headers.merge("Cookie" => value, "HTTP_COOKIE" => value)
  end

  def response_form_params
    form = response.parsed_body.at_css('form[method="post"]')
    if form
      return form.css("input[name]").each_with_object({}) { |input, values| values[input["name"]] = input["value"] }
    end

    page = response.parsed_body.at_css('script[type="application/json"][data-page]')
    JSON.parse(page.text).fetch("props").fetch("form").slice("logout_challenge", "ri", "logout_intent_proof").compact
  end

  def assert_idp_session_error_response
    assert_response :bad_request
    assert_equal I18n.t("sign.shared.sign_out.idp_session_error"), response.body
    assert_nil response.location
  end
end

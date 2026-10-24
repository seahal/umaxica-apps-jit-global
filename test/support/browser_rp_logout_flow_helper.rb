# frozen_string_literal: true

require "base64"
require "digest"
require_relative "oidc_rp_logout_hint_helper"

# Drives the real Browser RP sign-out ceremony across the Core origin and the Base authority with
# real session writes and token issuance. Callers set @core_host, @base_host, @user and @root_token
# and create their RP sessions with create_rp_session.
module BrowserRpLogoutFlowHelper
  include OidcRpLogoutHintHelper

  private

  def create_rp_session(client_id, root_token: @root_token)
    client = OidcClientRegistry.find!(client_id)
    grant = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: root_token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    store_oidc_rp_logout_hint!(grant, grant.client_token.actor_record, client)
    grant
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
    browser_cookie_before = session_cookie_pair
    get(edit_core_app_sign_out_url(ri: "jp"))
    assert_response :success

    browser_cookie_key = browser_cookie_before.presence || session_cookie_pair
    existing = internal_logout_transaction_for(rp_session, browser_cookie_key)
    transaction, proof =
      if existing
        [existing, nil]
      else
        raw_proof = SecureRandom.random_bytes(32)
        binding = AcmeLogoutTransactionCoordinator.browser_rp_binding_for(
          session_record: rp_session,
          resource_type: "client",
          origin_intent_digest: Digest::SHA256.digest(raw_proof),
        )
        result = AcmeLogoutTransactionCoordinator.issue!(
          workflow: AcmeLogoutTransaction::BROWSER_RP_WORKFLOW,
          origin_surface: "core",
          initiating_client_id: "core-app-jp",
          completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
            origin_surface: "core", ri: "jp", surface: "app",
          ),
          actor_ref: @user.public_id,
          session_ref: rp_session.public_id,
          callback_state: nil,
          surface: "app",
          ri: "jp",
          **binding,
        )
        raise result.error_description unless result.success?

        [result.transaction, raw_proof]
      end

    install_internal_logout_intent_proof!(transaction, proof) if proof
    browser_cookie_key = session_cookie_pair if browser_cookie_key.blank?
    @internal_logout_transactions ||= {}
    @internal_logout_transactions[[rp_session.public_id, browser_cookie_key]] = transaction
    response.headers["Location"] = internal_authority_url(transaction)
    [transaction.logout_challenge, session_cookie_pair]
  end

  def internal_logout_transaction_for(rp_session, browser_cookie_key)
    transaction = @internal_logout_transactions&.fetch([rp_session.public_id, browser_cookie_key], nil)
    return unless transaction&.persisted?
    return unless transaction.browser_rp_workflow?
    return unless transaction.expected_step.in?(
      [
        AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED,
        AcmeLogoutTransaction::STEP_AUTHORITY_CLEANUP_ISSUED,
        *OidcRpLogoutLauncher::BROWSER_RP_ORIGIN_STEPS,
      ],
    )
    return if transaction.expired? && !transaction.finalized?

    transaction
  end

  def install_internal_logout_intent_proof!(transaction, raw_proof)
    session_key = Rails.application.config.session_options.fetch(:key)
    cookie_jar = ActionDispatch::Cookies::CookieJar.build(request, request.cookies)
    session_state = { "session_id" => SecureRandom.hex(16) }.merge(request.session.to_hash.stringify_keys)
    session_state[AcmeLogoutTransactionable::BROWSER_RP_LOGOUT_PROOFS_SESSION_KEY.to_s] = {
      transaction.logout_challenge => {
        "proof" => Base64.strict_encode64(raw_proof),
        "client_id" => transaction.initiating_client_id,
        "session_ref" => transaction.session_ref,
        "parent_session_ref" => transaction.parent_session_ref,
        "expires_at" => transaction.expires_at.iso8601(6),
      },
    }
    cookie_jar.encrypted[session_key] = { value: session_state }
    encoded_session = cookie_jar[session_key]
    cookies.delete(session_key)
    store_raw_cookies(
      cookies,
      "#{session_key}=#{Rack::Utils.escape(encoded_session)}",
      URI.parse("https://#{request.host}/"),
    )
  end

  def internal_authority_url(transaction)
    uri = URI.parse(OidcIssuer.end_session_endpoint("client"))
    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    query["logout_challenge"] = transaction.logout_challenge
    query["ri"] = "jp"
    uri.query = query.to_query
    uri.to_s
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
      visa_app_oidc_logout_path(logout_challenge: challenge, ri: "jp"),
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

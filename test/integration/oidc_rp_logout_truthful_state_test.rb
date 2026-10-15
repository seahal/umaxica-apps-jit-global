# frozen_string_literal: true

require "test_helper"

# REQ-008 / REQ-009: every sign-out display is derived from the parent state. A failure after the
# parent COMMIT is never shown as a sign-out failure, an unknown COMMIT outcome is shown as
# indeterminate, and no output states an end time.
class OidcRpLogoutTruthfulStateTest < ActionDispatch::IntegrationTest
  setup do
    @core_host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    @base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    https!
    host! @core_host
    @user = clients(:one)
    @root_token = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    @core_session = create_rp_session("core-app")
    @sibling_session = create_rp_session("warp-app")
  end

  test "a failed progress write after the parent COMMIT shows the global result with cleanup incomplete" do
    challenge, origin_session_cookie = start_sign_out
    failed_advance = AcmeLogoutTransactionCoordinator::Result.new(
      transaction: nil, status: :rejected, error: "invalid_request", error_description: "progress write failed",
    )

    AcmeLogoutTransactionCoordinator.stub(:advance!, ->(**) { failed_advance }) do
      confirm_at_authority(challenge, origin_session_cookie)
    end

    assert_response :ok
    assert_nil response.location
    assert_includes response.headers.fetch("Cache-Control").downcase, "no-store"
    assert_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
    assert_includes response.body, I18n.t("sign.shared.sign_out.cleanup_incomplete_description")
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.unavailable_title")
    assert_not_predicate @root_token.reload, :currently_usable?
    assert_predicate @core_session.reload, :revoked?
    assert_predicate @sibling_session.reload, :revoked?
  end

  test "a database error on the progress write after the parent COMMIT still shows the global result" do
    challenge, origin_session_cookie = start_sign_out
    unreadable = ->(**) { raise ActiveRecord::ConnectionNotEstablished, "app ticket writer unavailable" }

    AcmeLogoutTransactionCoordinator.stub(:advance!, unreadable) do
      confirm_at_authority(challenge, origin_session_cookie)
    end

    assert_response :ok
    assert_includes response.body, I18n.t("sign.shared.sign_out.cleanup_incomplete_description")
    assert_not_predicate @root_token.reload, :currently_usable?
  end

  test "an authority that no longer holds under the parent lock stops with the IdP session error" do
    challenge, origin_session_cookie = start_sign_out
    changed = ->(**) { raise AuthenticationLogoutCurrentSession::PreconditionFailed }

    AuthenticationLogoutCurrentSession.stub(:call, changed) do
      confirm_at_authority(challenge, origin_session_cookie)
    end

    assert_response :bad_request
    assert_equal I18n.t("sign.shared.sign_out.idp_session_error"), response.body
    assert_nil response.location
    assert_predicate @root_token.reload, :currently_usable?
    assert_predicate @core_session.reload, :active?
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED,
                 AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge).expected_step
  end

  test "the authority confirmation re-checks the binding inside the revoking transaction" do
    challenge, origin_session_cookie = start_sign_out
    received = nil
    original_call = AuthenticationLogoutCurrentSession.method(:call)
    spy =
      lambda do |**options|
        received = options[:precondition]
        original_call.call(**options)
      end

    AuthenticationLogoutCurrentSession.stub(:call, spy) do
      confirm_at_authority(challenge, origin_session_cookie)
    end

    assert_response :see_other
    assert_respond_to received, :call
    assert_not_predicate @root_token.reload, :currently_usable?
  end

  test "an unknown COMMIT outcome is shown as indeterminate, never as success or failure" do
    challenge, origin_session_cookie = start_sign_out
    raise_unknown = ->(**) { raise AuthenticationLogoutCurrentSession::CommitOutcomeUnknown }

    AuthenticationLogoutCurrentSession.stub(:call, raise_unknown) do
      confirm_at_authority(challenge, origin_session_cookie)
    end

    assert_response :service_unavailable
    assert_includes response.headers.fetch("Cache-Control").downcase, "no-store"
    assert_includes response.body, I18n.t("sign.shared.sign_out.indeterminate_title")
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.unavailable_title")
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
  end

  test "a failed origin cleanup after the parent COMMIT shows the global result with cleanup incomplete" do
    challenge, origin_session_cookie = start_sign_out
    confirm_at_authority(challenge, origin_session_cookie)

    assert_response :see_other
    host! @core_host
    get core_app_sign_out_completion_path(logout_challenge: challenge, ri: "jp")
    form_params = response_form_params
    failed_revoke = RpSessionRevoker::Result.new(success: false, revoked_count: 0)

    RpSessionRevoker.stub(:call, ->(**) { failed_revoke }) do
      post core_app_sign_out_completion_path(logout_challenge: challenge, ri: "jp"),
           params: form_params,
           headers: with_session_cookie(origin_headers("same-origin"), session_cookie: origin_session_cookie)
    end

    assert_response :ok
    assert_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
    assert_includes response.body, I18n.t("sign.shared.sign_out.cleanup_incomplete_description")
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.unavailable_title")
    assert_not_predicate @root_token.reload, :currently_usable?
  end

  test "the completed origin page states the global result and no end time" do
    challenge, origin_session_cookie = start_sign_out
    confirm_at_authority(challenge, origin_session_cookie)
    host! @core_host
    get core_app_sign_out_completion_path(logout_challenge: challenge, ri: "jp")
    post core_app_sign_out_completion_path(logout_challenge: challenge, ri: "jp"),
         params: response_form_params,
         headers: with_session_cookie(origin_headers("same-origin"), session_cookie: origin_session_cookie)

    assert_response :see_other
    get URI.parse(response.location).request_uri

    assert_response :ok
    assert_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
    assert_includes response.body, I18n.t("sign.shared.sign_out.completed_description")
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.cleanup_incomplete_description")
    assert_no_match(/\d{1,2}:\d{2}/, response.parsed_body.at_css("main, body").text)
  end

  private

  def create_rp_session(client_id)
    client = OidcClientRegistry.find!(client_id)
    ClientRpSession.create!(
      client_token: @root_token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
  end

  def start_sign_out
    client = OidcClientRegistry.find!("core-app")
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      @user,
      host: @core_host,
      resource_type: "client",
      session_public_id: @root_token.public_id,
      base_session_public_id: @root_token.public_id,
      oidc_sid: @core_session.public_id,
      oidc_jti: @core_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(@user, resource_type: "client"),
      client_id: client.client_id,
    )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @core_session.issue_refresh_token!

    post(core_app_sign_out_url(ri: "jp"))

    assert_response :see_other
    query = Rack::Utils.parse_nested_query(URI.parse(response.location).query.to_s)
    [query.fetch("logout_challenge"), session_cookie_pair]
  end

  def confirm_at_authority(challenge, origin_session_cookie)
    host!(@base_host)
    access_token = AuthenticationToken.encode(
      @user,
      host: @base_host,
      session_public_id: @root_token.device_session_record.public_id,
      oidc_sid: @root_token.device_session_record.public_id,
      oidc_jti: @root_token.oidc_jti,
      resource_type: "client",
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      authentication_context: @root_token.authentication_context_value.to_s,
    )
    cookie = "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(access_token)}"
    headers = origin_headers("same-site").merge("Host" => @base_host, "Cookie" => cookie, "HTTP_COOKIE" => cookie)
    post(
      base_app_oidc_logout_path(logout_challenge: challenge, ri: "jp"),
      headers: with_session_cookie(headers, session_cookie: origin_session_cookie),
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
    return form.css("input[name]").each_with_object({}) { |input, values|
      values[input["name"]] = input["value"]
    } if form

    page = response.parsed_body.at_css('script[type="application/json"][data-page]')
    JSON.parse(page.text).fetch("props").fetch("form").slice("logout_challenge", "ri", "logout_intent_proof").compact
  end
end

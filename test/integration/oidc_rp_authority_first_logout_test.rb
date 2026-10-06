# frozen_string_literal: true

require "test_helper"

class OidcRpAuthorityFirstLogoutTest < ActionDispatch::IntegrationTest
  setup do
    @core_host = ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost")
    @base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    https!
    host! @core_host
  end

  test "authority-first logout revokes the parent before origin cleanup" do
    user = clients(:one)
    root_token = ClientToken.create!(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    core_session, core_refresh = issue_rp_session!(root_token, client_id: "core-app")
    sibling_session, sibling_refresh = issue_rp_session!(root_token, client_id: "warp-app")
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = issue_access_token!(
      user,
      root_token: root_token,
      rp_session: core_session,
      client_id: "core-app",
    )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = core_refresh

    post core_app_sign_out_url(ri: "jp")

    assert_response :see_other, response.body
    authority_uri = URI.parse(response.location)
    authority_query = Rack::Utils.parse_nested_query(authority_uri.query.to_s)
    challenge = authority_query.fetch("logout_challenge")
    transaction = AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge)

    assert_equal @base_host, authority_uri.host
    assert_equal "/oidc/logout", authority_uri.path
    assert_equal AcmeLogoutTransaction::BROWSER_RP_WORKFLOW, transaction.workflow
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED, transaction.expected_step
    assert_predicate root_token.reload, :currently_usable?
    assert_predicate core_session.reload, :active?
    assert_predicate sibling_session.reload, :active?

    host! @base_host
    get base_app_oidc_logout_path(logout_challenge: challenge, ri: "jp")

    assert_response :ok
    assert_select "form[action=?][method=?]", base_app_oidc_logout_path, "post"
    assert_predicate root_token.reload, :currently_usable?

    post base_app_oidc_logout_path(
      logout_challenge: challenge,
      ri: "jp",
    ), headers: {
      "Origin" => "https://#{@core_host}",
      "Sec-Fetch-Site" => "same-site",
    }

    assert_response :see_other, response.body
    origin_uri = URI.parse(response.location)

    assert_equal @core_host, origin_uri.host
    assert_equal "/sign/out", origin_uri.path
    assert_equal challenge, Rack::Utils.parse_nested_query(origin_uri.query.to_s).fetch("logout_challenge")

    transaction.reload

    assert_equal AcmeLogoutTransaction::STEP_ORIGIN_CLEANUP_ISSUED, transaction.expected_step
    assert_equal [
      AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED,
      AcmeLogoutTransaction::STEP_AUTHORITY_CLEANUP_ISSUED,
    ], transaction.completed_steps
    assert_not_predicate root_token.reload, :currently_usable?
    assert_not core_session.reload.active?
    assert_not sibling_session.reload.active?
    assert_not core_session.authenticate_refresh_token(core_refresh)
    assert_not sibling_session.authenticate_refresh_token(sibling_refresh)
    assert_nil sibling_session.reload.revoked_at

    # The initiating RP can arrive with a row that was revoked independently after the parent
    # phase. Phase 4 is idempotent and must still finalize the durable transaction.
    core_session.revoke!(status: "success")

    host! @core_host
    get core_app_sign_out_path(logout_challenge: challenge, ri: "jp")

    assert_response :ok
    assert_includes response.body, "logout_challenge", response.body

    post core_app_sign_out_path(
      logout_challenge: challenge,
      ri: "jp",
    ), headers: {
      "Origin" => "https://#{@core_host}",
      "Sec-Fetch-Site" => "same-origin",
    }

    assert_response :see_other, response.body
    completion_uri = URI.parse(response.location)

    assert_equal @core_host, completion_uri.host
    assert_equal "/sign/out", completion_uri.path
    assert_predicate transaction.reload, :finalized?
    assert_predicate core_session.reload, :revoked?
    assert_nil sibling_session.reload.revoked_at

    get completion_uri.request_uri

    assert_response :success
    assert_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
  end

  test "an untrusted origin cannot commit authority-first logout" do
    user = clients(:one)
    root_token = ClientToken.create!(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    core_session, = issue_rp_session!(root_token, client_id: "core-app")
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = issue_access_token!(
      user,
      root_token: root_token,
      rp_session: core_session,
      client_id: "core-app",
    )

    post core_app_sign_out_path(ri: "jp")

    authority_query = Rack::Utils.parse_nested_query(URI.parse(response.location).query.to_s)
    challenge = authority_query.fetch("logout_challenge")

    host! @base_host
    post base_app_oidc_logout_path(logout_challenge: challenge, ri: "jp"), headers: {
      "Origin" => "https://attacker.example",
      "Sec-Fetch-Site" => "cross-site",
    }

    assert_response :forbidden
    assert_predicate root_token.reload, :currently_usable?
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED,
                 AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge).expected_step
  end

  test "Base self-RP logout returns to Base without an Auth hop" do
    user = clients(:one)
    root_token = ClientToken.create!(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    rp_session, refresh_token = issue_rp_session!(root_token, client_id: "base-app-ww")
    host! @base_host
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = issue_access_token!(
      user,
      root_token: root_token,
      rp_session: rp_session,
      client_id: "base-app-ww",
      host: @base_host,
    )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh_token

    post base_app_sign_out_path(ri: "jp")

    assert_response :see_other
    authority_uri = URI.parse(response.location)
    challenge = Rack::Utils.parse_nested_query(authority_uri.query.to_s).fetch("logout_challenge")

    assert_equal @base_host, authority_uri.host
    assert_equal "/oidc/logout", authority_uri.path

    get base_app_oidc_logout_path(logout_challenge: challenge, ri: "jp")

    assert_response :ok

    post base_app_oidc_logout_path(logout_challenge: challenge, ri: "jp"), headers: {
      "Origin" => "https://#{@base_host}",
      "Sec-Fetch-Site" => "same-origin",
    }

    assert_response :see_other
    origin_uri = URI.parse(response.location)

    assert_equal @base_host, origin_uri.host
    assert_equal "/sign/out", origin_uri.path

    get base_app_sign_out_path(logout_challenge: challenge, ri: "jp")

    assert_response :ok

    post base_app_sign_out_path(logout_challenge: challenge, ri: "jp"), headers: {
      "Origin" => "https://#{@base_host}",
      "Sec-Fetch-Site" => "same-origin",
    }

    assert_response :see_other
    assert_predicate AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge), :finalized?
    assert_predicate root_token.reload, :revoked?
    assert_predicate rp_session.reload, :revoked?
    assert_not_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), response.location.to_s
  end

  test "Edit RP logout returns through the staff Base authority" do
    operator = operators(:one)
    root_token = OperatorToken.create!(
      staff: operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
    )
    rp_session, refresh_token = issue_operator_rp_session!(root_token)
    edit_host = ENV.fetch("PUBLIC_EDIT_STAFF_URL", "edit.org.localhost")
    base_staff_host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    host! edit_host
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = issue_operator_access_token!(
      operator,
      root_token: root_token,
      rp_session: rp_session,
      host: edit_host,
    )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh_token

    post edit_org_sign_out_path(ri: "jp")

    assert_response :see_other
    authority_uri = URI.parse(response.location)
    challenge = Rack::Utils.parse_nested_query(authority_uri.query.to_s).fetch("logout_challenge")

    assert_equal base_staff_host, authority_uri.host
    assert_equal "/oidc/logout", authority_uri.path

    host! base_staff_host
    get base_org_oidc_logout_path(logout_challenge: challenge, ri: "jp")

    assert_response :ok

    post base_org_oidc_logout_path(logout_challenge: challenge, ri: "jp"), headers: {
      "Origin" => "https://#{edit_host}",
      "Sec-Fetch-Site" => "same-site",
    }

    assert_response :see_other
    origin_uri = URI.parse(response.location)

    assert_equal edit_host, origin_uri.host
    assert_equal "/sign/out", origin_uri.path

    host! edit_host
    get edit_org_sign_out_path(logout_challenge: challenge, ri: "jp")

    assert_response :ok

    post edit_org_sign_out_path(logout_challenge: challenge, ri: "jp"), headers: {
      "Origin" => "https://#{edit_host}",
      "Sec-Fetch-Site" => "same-origin",
    }

    assert_response :see_other
    assert_predicate AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge), :finalized?
    assert_predicate root_token.reload, :revoked?
    assert_predicate rp_session.reload, :revoked?
  end

  private

  def issue_rp_session!(root_token, client_id:)
    client = OidcClientRegistry.find!(client_id)
    session = ClientRpSession.create!(
      client_token: root_token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    [session, session.issue_refresh_token!]
  end

  def issue_operator_rp_session!(root_token)
    client = OidcClientRegistry.find!("edit-org")
    session = OperatorRpSession.create!(
      operator_token: root_token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    [session, session.issue_refresh_token!]
  end

  def issue_access_token!(user, root_token:, rp_session:, client_id:, host: @core_host)
    client = OidcClientRegistry.find!(client_id)
    AuthenticationTokenService.encode(
      user,
      host: host,
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
  end

  def issue_operator_access_token!(operator, root_token:, rp_session:, host:)
    client = OidcClientRegistry.find!("edit-org")
    AuthenticationTokenService.encode(
      operator,
      host: host,
      resource_type: "operator",
      session_public_id: root_token.public_id,
      base_session_public_id: root_token.public_id,
      oidc_sid: rp_session.public_id,
      oidc_jti: rp_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(operator, resource_type: "operator"),
      client_id: client.client_id,
    )
  end
end

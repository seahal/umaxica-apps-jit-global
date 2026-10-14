# typed: false
# frozen_string_literal: true

require "test_helper"

class Tech::Org::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("PUBLIC_TECH_STAFF_URL")
    host! @host
    https!
    @operator = operators(:one)
  end

  test "an operator can start sign-out after tech access is revoked" do
    previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    grant = OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: operators(:two),
      origin: "grant",
      capability: OperatorCapabilityGrant::TECH_ACCESS,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )
    client = OidcClientRegistry.find!("tech-org")
    root_token = OperatorToken.create!(staff: @operator)
    rp_session = OperatorRpSession.create!(
      operator_token: root_token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      @operator,
      host: @host,
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
      subject: OidcSubject.for(@operator, resource_type: "operator"),
      client_id: client.client_id,
    )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_session.issue_refresh_token!
    grant.update!(
      revoked_at: Time.current,
      revoked_by_operator: operators(:two),
      revoke_reason_code: "duty_ended",
    )

    get(tech_org_dashboard_path(ri: "jp"))

    assert_response :forbidden
    assert_select "h1", I18n.t("tech.org.access_denial.heading")
    assert_not_includes response.body, I18n.t("tech.org.dashboard.empty_state")
    authenticity_token = css_select('input[name="authenticity_token"]').first["value"]
    cookies.delete(OidcRpBrowserCredentialContract::ACCESS_COOKIE)

    post(
      tech_org_sign_out_path(ri: "jp"),
      params: { authenticity_token: authenticity_token },
      headers: {
        "Origin" => "https://#{@host}",
        "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_response :see_other
    authority_uri = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_BASE_STAFF_URL"), authority_uri.host
    assert_equal "/oidc/logout", authority_uri.path
    logout_transaction = AcmeLogoutTransaction.find_by!(
      public_id: Rack::Utils.parse_nested_query(
        authority_uri.query,
      ).fetch("logout_challenge"),
    )

    assert_equal "tech", logout_transaction.origin_surface
    assert_equal client.client_id, logout_transaction.initiating_client_id
    assert_equal rp_session.public_id, logout_transaction.session_ref
    assert_predicate root_token.reload, :currently_usable?
    assert_predicate rp_session.reload, :active?
    assert_equal "no-store", response.headers["Cache-Control"]
  ensure
    ActionController::Base.allow_forgery_protection = previous_forgery_protection
  end

  test "sign-out without a valid authenticity token is refused before transaction creation" do
    previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    transactions_before = AcmeLogoutTransaction.count

    post(
      tech_org_sign_out_path(ri: "jp"), headers: {
        "Origin" => "https://#{@host}",
        "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_response :unprocessable_content
    assert_equal transactions_before, AcmeLogoutTransaction.count
  ensure
    ActionController::Base.allow_forgery_protection = previous_forgery_protection
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class Tech::Org::DashboardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("PUBLIC_TECH_STAFF_URL")
    host! @host
    @operator = operators(:one)
  end

  test "an operator with current tech access sees the empty protected dashboard" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: operators(:two),
      origin: "grant",
      capability: OperatorCapabilityGrant::TECH_ACCESS,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )
    client = OidcClientRegistry.find!("tech-org-ww")
    root_token = OperatorToken.create!(authentication_epoch: 0, staff: @operator)
    rp_session = OpOrgGrant.create!(
      authentication_epoch: 0,
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

    get tech_org_dashboard_path(ri: "jp")

    assert_response :success
    assert_select "h1", I18n.t("tech.org.dashboard.heading")
    assert_select "h2", I18n.t("tech.org.dashboard.tools_heading")
    assert_select "p", I18n.t("tech.org.dashboard.empty_state")
    assert_select "form[action^=?][method=post]", tech_org_sign_out_path
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "an authenticated operator without tech access sees a no-store 403 and no tools" do
    client = OidcClientRegistry.find!("tech-org-ww")
    root_token = OperatorToken.create!(authentication_epoch: 0, staff: @operator)
    rp_session = OpOrgGrant.create!(
      authentication_epoch: 0,
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

    get tech_org_dashboard_path(ri: "jp")

    assert_response :forbidden
    assert_select "h1", I18n.t("tech.org.access_denial.heading")
    assert_select "form[action^=?][method=post]", tech_org_sign_out_path
    assert_not_includes response.body, I18n.t("tech.org.dashboard.empty_state")
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_no_set_cookie OidcRpBrowserCredentialContract::ACCESS_COOKIE
    assert_no_set_cookie OidcRpBrowserCredentialContract::REFRESH_COOKIE
  end

  test "an expired tech grant does not authorize the dashboard" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: operators(:two),
      origin: "grant",
      capability: OperatorCapabilityGrant::TECH_ACCESS,
      reason_code: "duty_assignment",
      starts_at: 2.days.ago,
      expires_at: 1.day.ago,
    )
    client = OidcClientRegistry.find!("tech-org-ww")
    root_token = OperatorToken.create!(authentication_epoch: 0, staff: @operator)
    rp_session = OpOrgGrant.create!(
      authentication_epoch: 0,
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

    get tech_org_dashboard_path(ri: "jp")

    assert_response :forbidden
    assert_not_includes response.body, I18n.t("tech.org.dashboard.empty_state")
  end

  test "Edit and Tech browser credentials are rejected by the other RP" do
    edit_host = ENV.fetch("PUBLIC_EDIT_STAFF_URL")
    edit_client = OidcClientRegistry.find!("edit-org-ww")
    tech_client = OidcClientRegistry.find!("tech-org-ww")
    root_token = OperatorToken.create!(authentication_epoch: 0, staff: @operator)
    edit_session = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: root_token,
      oidc_client_id: edit_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    tech_session = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: root_token,
      oidc_client_id: tech_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    edit_access_token = AuthenticationTokenService.encode(
      @operator,
      host: @host,
      resource_type: "operator",
      session_public_id: root_token.public_id,
      base_session_public_id: root_token.public_id,
      oidc_sid: edit_session.public_id,
      oidc_jti: edit_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(edit_client),
      audiences: [edit_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(edit_client),
      subject: OidcSubject.for(@operator, resource_type: "operator"),
      client_id: edit_client.client_id,
    )
    tech_access_token = AuthenticationTokenService.encode(
      @operator,
      host: edit_host,
      resource_type: "operator",
      session_public_id: root_token.public_id,
      base_session_public_id: root_token.public_id,
      oidc_sid: tech_session.public_id,
      oidc_jti: tech_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(tech_client),
      audiences: [tech_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(tech_client),
      subject: OidcSubject.for(@operator, resource_type: "operator"),
      client_id: tech_client.client_id,
    )

    get tech_org_dashboard_path(ri: "jp"), headers: {
      "Cookie" => "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(edit_access_token)}",
    }

    assert_response :redirect
    assert_equal "/sign", URI.parse(response.location).path
    assert_not_includes response.body, I18n.t("tech.org.dashboard.empty_state")

    host! edit_host
    get edit_org_dashboard_path(ri: "jp"), headers: {
      "Cookie" => "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(tech_access_token)}",
    }

    assert_response :redirect
    assert_equal "/sign", URI.parse(response.location).path
    assert_not_includes response.body, "Publishing management"
  end
end

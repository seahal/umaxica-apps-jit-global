# frozen_string_literal: true

require "test_helper"

# AT-050 / AT-052: the Tech `tech.access` grant interval and committed revocation decide the next
# request, including a request that must first refresh its credentials. Tech has no protected
# unsafe action (its only POST routes are sign-in, sign-out, completion and the CSP sink), so the
# unsafe refresh path has no Tech subject; the safe refresh path is exercised here.
class TechOrgAccessRevocationTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("PUBLIC_TECH_STAFF_URL")
    host! @host
    https!
    @operator = operators(:one)
    @client = OidcClientRegistry.find!("tech-org-ww")
    @root_token = OperatorToken.create!(
      authentication_epoch: 0, staff: @operator,
      authentication_event_at: 1.minute.ago,
    )
    @rp_session = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: @root_token,
      oidc_client_id: @client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 1.hour.from_now,
    )
  end

  test "a grant is refused before its start, honoured at its start and just before its expiry, refused at expiry" do
    starts_at = 1.hour.from_now.change(usec: 0)
    expires_at = starts_at + 1.day
    grant_tech_access(starts_at:, expires_at:)

    travel_to(starts_at - 1.second) { assert_dashboard_refused }
    travel_to(starts_at) { assert_dashboard_allowed }
    travel_to(expires_at - 1.second) { assert_dashboard_allowed }
    travel_to(expires_at) { assert_dashboard_refused }
  end

  test "a committed grant revocation refuses the next protected request" do
    grant = grant_tech_access

    assert_dashboard_allowed

    grant.revoke!(by: operators(:two), reason_code: "duty_ended")

    assert_dashboard_refused
  end

  test "positive control: an expired access credential is refreshed while the grant is in force" do
    grant_tech_access
    sign_in_tech(access_expires_at: 1.minute.ago)

    get tech_org_dashboard_path(ri: "jp")

    assert_response :success
    assert_select "p", I18n.t("tech.org.dashboard.empty_state")
  end

  test "a request that must refresh its credentials after a grant revocation is refused and loses its cookies" do
    grant = grant_tech_access
    grant.revoke!(by: operators(:two), reason_code: "duty_ended")
    sign_in_tech(access_expires_at: 1.minute.ago)

    get tech_org_dashboard_path(ri: "jp")

    assert_not_equal 200, response.status
    assert_not_includes response.body, I18n.t("tech.org.dashboard.empty_state")
    assert_cookie_cleared OidcRpBrowserCredentialContract::REFRESH_COOKIE
  end

  test "a revoked parent refuses both the current access credential and the refresh path" do
    grant_tech_access
    sign_in_tech
    access_cookie = cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
    refresh_cookie = cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
    AuthenticationLogoutCurrentSession.call(
      cause: "browser_logout", resource: @operator, token: @root_token,
      reason: "user_logout",
    )

    get tech_org_dashboard_path(ri: "jp")

    assert_not_equal 200, response.status
    assert_not_includes response.body, I18n.t("tech.org.dashboard.empty_state")

    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_cookie
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh_cookie
    travel 15.minutes
    get tech_org_dashboard_path(ri: "jp")

    assert_not_equal 200, response.status
    assert_not_includes response.body, I18n.t("tech.org.dashboard.empty_state")
    assert_predicate @rp_session.reload, :revoked?
  end

  test "an unreadable capability store returns no protected content and reuses no earlier result" do
    grant_tech_access

    assert_dashboard_allowed
    failing = ->(*) { raise ActiveRecord::ConnectionNotEstablished, "org zenith unavailable" }

    Operator.stub(:find_by, failing) do
      sign_in_tech
      get tech_org_dashboard_path(ri: "jp")
    end

    assert_not_equal 200, response.status
    assert_not_includes response.body, I18n.t("tech.org.dashboard.empty_state")
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end

  private

  def assert_cookie_cleared(name)
    lines = Array(response.headers["Set-Cookie"]).flat_map { |value| value.to_s.split("\n") }
    cleared = lines.find { |line| line.start_with?("#{name}=") }

    assert cleared, "expected #{name} to be cleared"
    assert_match(/max-age=0|expires=Thu, 01 Jan 1970/i, cleared)
  end

  def grant_tech_access(starts_at: 1.minute.ago, expires_at: 1.day.from_now)
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: operators(:two),
      origin: "grant",
      capability: OperatorCapabilityGrant::TECH_ACCESS,
      reason_code: "duty_assignment",
      starts_at:,
      expires_at:,
    )
  end

  def sign_in_tech(access_expires_at: 10.minutes.from_now)
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      @operator,
      host: @host,
      resource_type: "operator",
      session_public_id: @root_token.public_id,
      base_session_public_id: @root_token.public_id,
      oidc_sid: @rp_session.public_id,
      oidc_jti: @rp_session.oidc_jti,
      expires_at: access_expires_at,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(@client),
      audiences: [@client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(@client),
      subject: OidcSubject.for(@operator, resource_type: "operator"),
      client_id: @client.client_id,
    )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @rp_session.reload.issue_refresh_token!
  end

  def assert_dashboard_allowed
    sign_in_tech
    get(tech_org_dashboard_path(ri: "jp"))

    assert_response :success
    assert_select "p", I18n.t("tech.org.dashboard.empty_state")
  end

  def assert_dashboard_refused
    sign_in_tech
    get(tech_org_dashboard_path(ri: "jp"))

    assert_response :forbidden
    assert_not_includes response.body, I18n.t("tech.org.dashboard.empty_state")
  end
end

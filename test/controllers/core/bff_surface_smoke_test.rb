# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CoreBffSurfaceSmokeTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds, :com_preference_binding_methods, :com_preferences,
           :operators, :operator_token_kinds

  SURFACES = [
    {
      host: ENV.fetch("PUBLIC_CORE_SERVICE_URL", Rails.configuration.x.boot_config.fetch(:hosts).core_service.host),
      acme_host: Rails.configuration.x.boot_config.fetch(:hosts).acme_service.host,
      backchannel_logout_path: "/oidc/backchannel/logout",
      token_refresh_path: "/api/v0/token/refresh",
      jwt_issuer_id: "surface:CORE_APP",
      resource_type: "client",
      client_id: "core-app",
    },
    {
      host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL", Rails.configuration.x.boot_config.fetch(:hosts).core_corporate.host),
      acme_host: Rails.configuration.x.boot_config.fetch(:hosts).acme_corporate.host,
      backchannel_logout_path: "/oidc/backchannel/logout",
      token_refresh_path: "/api/v0/token/refresh",
      jwt_issuer_id: "surface:CORE_COM",
      resource_type: "visitor",
      client_id: "core-com",
    },
    {
      host: ENV.fetch("PUBLIC_CORE_STAFF_URL", Rails.configuration.x.boot_config.fetch(:hosts).core_staff.host),
      acme_host: Rails.configuration.x.boot_config.fetch(:hosts).acme_staff.host,
      backchannel_logout_path: "/oidc/backchannel/logout",
      token_refresh_path: "/api/v0/token/refresh",
      jwt_issuer_id: "surface:CORE_ORG",
      resource_type: "operator",
      client_id: "core-org",
    },
  ].freeze

  test "core BFF and logout routes are executable on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      browser = open_session
      browser.host!(host)
      browser.https!

      browser.get("/oidc/callback")

      assert_equal 422, browser.response.status

      resource_type = surface.fetch(:resource_type)
      user, token = actor_and_token_for(resource_type)
      authenticate_rp!(browser, surface, user, token, host)

      browser.post("/sign/out", params: { ri: "jp" })

      response = browser.response
      handoff_rendered = response.status.between?(200, 299)

      assert response.redirect? || handoff_rendered, "expected redirect or handoff success, got #{response.status}"
      assert_includes response.body, 'id="sign-out-handoff-form"' if handoff_rendered

      browser.post(surface.fetch(:backchannel_logout_path), params: { logout_token: "invalid" })

      assert_equal 400, browser.response.status
      assert_equal "invalid_logout_token", browser.response.body

      browser.post(surface.fetch(:token_refresh_path), headers: { "Accept" => "application/json" }, as: :json)

      assert_equal 503, browser.response.status
      assert_equal "urn:umaxica:problem:service-unavailable", browser.response.parsed_body.fetch("type")
    end
  end

  private

  def authenticate_rp!(browser, surface, resource, token, host)
    client = OidcClientRegistry.find!(surface.fetch(:client_id))
    session_class, association =
      case surface.fetch(:resource_type)
      when "operator" then [OperatorRpSession, :operator_token]
      when "visitor" then [VisitorRpSession, :visitor_token]
      else [ClientRpSession, :client_token]
      end
    rp_session = session_class.create!(
      association => token,
      :oidc_client_id => client.client_id,
      :oidc_scope => "openid profile",
      :oidc_jti => SecureRandom.uuid,
      :oidc_auth_time => 1.minute.ago,
      :refresh_token_expires_at => 10.minutes.from_now,
    )
    access_token = AuthenticationTokenService.encode(
      resource,
      host: host,
      resource_type: surface.fetch(:resource_type),
      session_public_id: token.public_id,
      oidc_sid: rp_session.public_id,
      oidc_jti: rp_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(resource, resource_type: surface.fetch(:resource_type)),
      client_id: client.client_id,
    )
    browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
    browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_session.issue_refresh_token!
    rp_session
  end

  def actor_and_token_for(resource_type)
    case resource_type
    when "operator"
      staff = operators(:one)
      token = OperatorToken.where(staff: staff).where(
        "discard_at > ?",
        Time.current,
      ).order(created_at: :desc).first ||
        OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
      [staff, token]
    when "visitor"
      VisitorStatus.ensure_defaults!
      VisitorVisibility.ensure_defaults!
      visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
      token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
      [visitor, token]
    else
      user = clients(:one)
      token = ClientToken.where(user: user).where("discard_at > ?", Time.current).order(created_at: :desc).first ||
        ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      [user, token]
    end
  end
end

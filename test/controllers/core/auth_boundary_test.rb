# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CoreAuthBoundaryTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds, :operators, :operator_token_kinds

  BOOT_HOSTS = Rails.configuration.x.boot_config.fetch(:hosts)
  SURFACES = [
    {
      host: ENV.fetch("PUBLIC_CORE_SERVICE_URL", BOOT_HOSTS.core_service.host),
      controller: "core/app/oidc/callbacks",
      sign_out_controller: "core/app/sign/outs",
      acme_host: BOOT_HOSTS.acme_service.host,
      jwt_issuer_id: "surface:CORE_APP",
      resource_type: "client",
      client_id: "core-app",
    },
    {
      host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL", BOOT_HOSTS.core_corporate.host),
      controller: "core/com/oidc/callbacks",
      sign_out_controller: "core/com/sign/outs",
      acme_host: BOOT_HOSTS.acme_corporate.host,
      jwt_issuer_id: "surface:CORE_COM",
      resource_type: "visitor",
      client_id: "core-com",
    },
    {
      host: ENV.fetch("PUBLIC_CORE_STAFF_URL", BOOT_HOSTS.core_staff.host),
      controller: "core/org/oidc/callbacks",
      sign_out_controller: "core/org/sign/outs",
      acme_host: BOOT_HOSTS.acme_staff.host,
      jwt_issuer_id: "surface:CORE_ORG",
      resource_type: "operator",
      client_id: "core-org",
    },
  ].freeze

  test "callback, logout, and back-channel routes remain executable on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      assert_routing(
        { method: :get, path: "http://#{host}/oidc/callback" },
        { controller: surface.fetch(:controller), action: "show" },
      )

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/sign/callback", method: :get)
      end
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/oidc/authorization", method: :get)
      end

      assert_routing(
        { method: :post, path: "http://#{host}/sign/out" },
        { controller: surface.fetch(:sign_out_controller), action: "create" },
      )

      assert_routing(
        { method: :post, path: "http://#{host}/oidc/backchannel/logout" },
        { controller: "core/#{surface.fetch(:controller).split("/")[1]}/oidc/backchannel/logouts", action: "create" },
      )
    end
  end

  test "callback rejects missing oauth state with an explicit failure" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      get "https://#{host}/oidc/callback"

      assert_response :unprocessable_content
    end
  end

  test "logout redirects to the base oidc logout flow on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      browser = open_session
      browser.host!(host)
      browser.https!
      rp_session = nil

      resource_type = surface.fetch(:resource_type)
      user, token, = actor_and_token_for(resource_type)
      rp_session = authenticate_rp!(browser, surface, user, token, host)

      browser.post("/sign/out", params: { ri: "jp" })

      response = browser.response
      handoff_rendered = response.status.between?(200, 299)

      assert response.redirect? || handoff_rendered, "expected redirect or handoff success, got #{response.status}"
      assert_includes response.body, 'id="sign-out-handoff-form"' if handoff_rendered
    ensure
      RpSessionRevoker.call(scope: :rp_session, record: rp_session) if rp_session
    end
  end

  test "back-channel logout rejects invalid tokens without mutating session state" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      post "https://#{host}/oidc/backchannel/logout", params: { logout_token: "invalid" }

      assert_response :bad_request
      assert_equal "invalid_logout_token", response.body
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
    browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
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
    browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_session.issue_refresh_token!
    rp_session
  end

  def actor_and_token_for(resource_type)
    case resource_type
    when "operator"
      staff = operators(:one)
      token = OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
      [staff, token, OperatorToken]
    when "visitor"
      VisitorStatus.ensure_defaults!
      VisitorVisibility.ensure_defaults!
      visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
      token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
      [visitor, token, VisitorToken]
    else
      user = clients(:one)
      token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      [user, token, ClientToken]
    end
  end
end

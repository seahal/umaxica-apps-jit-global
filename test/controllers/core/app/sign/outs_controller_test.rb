# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Core::App::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost")
    host! @host
  end

  test "RP cookie sign out renders confirmation without mutation" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    authenticate_rp!(user, token)

    get edit_core_app_sign_out_url(ri: "jp")

    assert_response :success
    assert_select "form[action*=?][method=?]", core_app_sign_out_path, "post"
    assert_predicate token.reload, :currently_usable?
  end

  test "sign-out launch does not clear site data before the authority phase" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    authenticate_rp!(user, token)

    post core_app_sign_out_url(ri: "jp"), headers: app_session_headers(user, token)

    assert_response :see_other
    assert_nil response.headers["Clear-Site-Data"]
    assert_predicate token.reload, :currently_usable?
    assert_predicate @rp_session.reload, :active?
  end

  test "the sign-out confirmation page does not clear site data" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get edit_core_app_sign_out_url(ri: "jp"), headers: app_session_headers(user, token)

    assert_response :success
    assert_nil response.headers["Clear-Site-Data"]
  end

  test "post sign out redirects to the registered base authority" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    authenticate_rp!(user, token)

    post core_app_sign_out_url(ri: "jp"), headers: app_session_headers(user, token)

    assert_response :see_other
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL", "www.app.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate query["logout_challenge"], :present?
    assert_equal "jp", query["ri"]
    assert_predicate @rp_session.reload, :active?
  end

  test "post sign out leaves parent and RP rows unchanged until authority confirmation" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    oidc_client = OidcClientRegistry.find!("core-app")
    rp_session = ClientRpSession.create!(
      client_token: token,
      oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    refresh_token = rp_session.issue_refresh_token!
    access_token = AuthenticationTokenService.encode(
      user,
      host: @host,
      resource_type: "client",
      session_public_id: token.public_id,
      base_session_public_id: token.public_id,
      oidc_sid: rp_session.public_id,
      oidc_jti: rp_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(oidc_client),
      audiences: [oidc_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(oidc_client),
      subject: OidcSubject.for(user, resource_type: "client"),
      client_id: oidc_client.client_id,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh_token

    post core_app_sign_out_url(ri: "jp")

    assert_response :see_other
    assert_predicate rp_session.reload, :active?
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out rejects a sibling RP credential without revoking either session" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    oidc_client = OidcClientRegistry.find!("warp-app")
    sibling_session = ClientRpSession.create!(
      client_token: token,
      oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      user,
      host: @host,
      resource_type: "client",
      session_public_id: token.public_id,
      base_session_public_id: token.public_id,
      oidc_sid: sibling_session.public_id,
      oidc_jti: sibling_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(oidc_client),
      audiences: [oidc_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(oidc_client),
      subject: OidcSubject.for(user, resource_type: "client"),
      client_id: oidc_client.client_id,
    )

    post core_app_sign_out_url(ri: "jp")

    assert_response :unauthorized
    assert_predicate sibling_session.reload, :active?
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out does not fall back to root Browser Session or Bearer credentials" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post core_app_sign_out_url(ri: "jp"), headers: app_session_headers(user, token)

    assert_response :unauthorized
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out accepts us region" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    authenticate_rp!(user, token)

    post core_app_sign_out_url(ri: "us"), headers: app_session_headers(user, token)

    assert_response :see_other
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL", "www.app.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_equal "us", query["ri"]
    assert_predicate query["logout_challenge"], :present?
    assert_predicate @rp_session.reload, :active?
  end

  test "post sign out canonicalizes unsupported region to default" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    authenticate_rp!(user, token)

    post core_app_sign_out_url(ri: "xx"), headers: app_session_headers(user, token)

    assert_response :see_other
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal "/oidc/logout", location.path
    assert_equal RequestContextContract.default_region, query["ri"]
    assert_predicate query["logout_challenge"], :present?
    assert_predicate @rp_session.reload, :active?
  end

  test "transaction issuance failure does not render success completion" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    authenticate_rp!(user, token)
    rejected = AcmeLogoutTransactionCoordinator::Result.new(
      transaction: nil,
      status: :rejected,
      error: "invalid_request",
      error_description: "completion destination is not allowlisted",
    )

    AcmeLogoutTransactionCoordinator.stub(:issue!, rejected) do
      post core_app_sign_out_url(ri: "us"), headers: app_session_headers(user, token)
    end

    assert_response :unprocessable_content
    assert_predicate token.reload, :currently_usable?
    assert_predicate @rp_session.reload, :active?
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
    assert_includes response.body, I18n.t("sign.shared.sign_out.unavailable_title")
    assert_select "form[action*=?][method=?]", core_app_sign_out_path, "post"
  end

  test "post sign out without region uses the default completion region" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    authenticate_rp!(user, token)

    post core_app_sign_out_url, headers: app_session_headers(user, token)

    assert_response :see_other
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL", "www.app.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate query["logout_challenge"], :present?
    assert_equal RequestContextContract.default_region, query["ri"]
  end

  test "post sign out does not route through Auth" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    authenticate_rp!(user, token)

    post core_app_sign_out_url(ri: "jp"), headers: app_session_headers(user, token)

    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL", "www.app.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_not_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), location.host
  end

  private

  def authenticate_rp!(user, token)
    oidc_client = OidcClientRegistry.find!("core-app")
    @rp_session = ClientRpSession.create!(
      client_token: token,
      oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      user,
      host: @host,
      resource_type: "client",
      session_public_id: token.public_id,
      base_session_public_id: token.public_id,
      oidc_sid: @rp_session.public_id,
      oidc_jti: @rp_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(oidc_client),
      audiences: [oidc_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(oidc_client),
      subject: OidcSubject.for(user, resource_type: "client"),
      client_id: oidc_client.client_id,
    )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @rp_session.issue_refresh_token!
  end

  def app_session_headers(user, token)
    bearer_headers(
      jwt_access_token_for(user, session_public_id: token.public_id, resource_type: "client"),
    )
  end

  def bearer_headers(token, headers: {})
    headers.merge("Authorization" => "Bearer #{token}")
  end

  def jwt_access_token_for(resource, session_public_id: nil, resource_type: nil)
    host = ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost")
    AuthenticationToken.encode(
      resource, host: host, session_public_id: session_public_id, resource_type: resource_type,
                jwt_issuer_id: jwt_issuer_id_for_test_host(host, resource_type),
    )
  end

  # Core, like Base, does not necessarily resolve to a host containing its own
  # surface name (e.g. Core's real origin is jpx.umaxica.<tld>), so the issuer
  # namespace cannot be inferred from a host substring. Match against the
  # actual configured Core hosts explicitly.
  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    configured_hosts = {
      "CORE_APP" => ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"),
      "CORE_ORG" => ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost"),
      "CORE_COM" => ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost"),
    }
    return "surface:#{configured_hosts.key(normalized)}" if configured_hosts.value?(normalized)

    surface =
      case resource_type
      when "operator" then "ORG"
      when "visitor" then "COM"
      else "APP"
      end
    "surface:AUTH_#{surface}"
  end
end

# DAMP local route helper aliases for former shared test support.
class Core::App::Sign::OutsControllerTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end

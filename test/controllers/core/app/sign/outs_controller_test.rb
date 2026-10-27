# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../../../support/oidc_rp_logout_hint_helper"
# require "helpers/global_test_support"

class Core::App::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  include OidcRpLogoutHintHelper

  fixtures :clients, :client_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost")
    host! @host
  end

  test "RP cookie sign out renders confirmation without mutation" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    authenticate_rp!(user, token)

    get edit_core_app_sign_out_url(ri: "jp")

    assert_response :success
    assert_select "form[action*=?][method=?]", core_app_sign_out_path, "post"
    assert_select "form[action='#{core_app_sign_out_path}'] input[name=_method][value=delete]", count: 0
    assert_predicate token.reload, :currently_usable?
  end

  test "sign-out launch leaves the RP grant active before the Visa authority phase" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    authenticate_rp!(user, token)

    post core_app_sign_out_url(ri: "jp"), headers: app_session_headers(user, token)

    assert_response :see_other
    assert_nil response.headers["Clear-Site-Data"]
    assert_predicate token.reload, :currently_usable?
    assert_predicate @rp_session.reload, :active?
  end

  test "the sign-out confirmation page does not clear site data" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get edit_core_app_sign_out_url(ri: "jp"), headers: app_session_headers(user, token)

    assert_response :success
    assert_nil response.headers["Clear-Site-Data"]
  end

  test "post sign out redirects to the registered Visa end-session endpoint" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    authenticate_rp!(user, token)

    post core_app_sign_out_url(ri: "jp"), headers: app_session_headers(user, token)

    assert_response :see_other
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_visa_end_session_redirect(query, location, client_id: "core-app-jp", region: "jp")
    assert_predicate @rp_session.reload, :active?
  end

  test "sign-out launch uses the server-side hint without issuing an OP transaction" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    authenticate_rp!(user, token)

    post core_app_sign_out_url(ri: "jp")

    assert_response :see_other
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_visa_end_session_redirect(query, location, client_id: "core-app-jp", region: "jp")
  end

  test "post sign out keeps the initiating grant active before authority confirmation" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    oidc_client = OidcClientRegistry.find!("core-app-jp")
    rp_session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: token,
      oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    store_oidc_rp_logout_hint!(rp_session, user, oidc_client)
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
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    oidc_client = OidcClientRegistry.find!("warp-app-jp")
    sibling_session = OpAppGrant.create!(
      authentication_epoch: 0,
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
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post core_app_sign_out_url(ri: "jp"), headers: app_session_headers(user, token)

    assert_response :unauthorized
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out accepts us region" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    authenticate_rp!(user, token)

    post core_app_sign_out_url(ri: "us"), headers: app_session_headers(user, token)

    assert_response :see_other
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_visa_end_session_redirect(query, location, client_id: "core-app-jp", region: "us")
    assert_predicate @rp_session.reload, :active?
  end

  test "post sign out canonicalizes unsupported region to default" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    authenticate_rp!(user, token)

    post core_app_sign_out_url(ri: "xx"), headers: app_session_headers(user, token)

    assert_response :see_other
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal "/oidc/logout", location.path
    redirect_uri = query.fetch("post_logout_redirect_uri")

    assert_equal RequestContextContract.default_region,
                 Rack::Utils.parse_nested_query(URI.parse(redirect_uri).query).fetch("ri")
    assert_visa_end_session_redirect(query, location, client_id: "core-app-jp", region: "jp")
  end

  test "sign-out without a stored ID Token hint fails closed" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    authenticate_rp!(user, token)
    @rp_session.logout_hint.destroy!

    post core_app_sign_out_url(ri: "us"), headers: app_session_headers(user, token)

    assert_response :unprocessable_content
    assert_predicate token.reload, :currently_usable?
    assert_predicate @rp_session.reload, :active?
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
    assert_includes response.body, I18n.t("sign.shared.sign_out.unavailable_title")
    assert_select "form[action*=?][method=?]", core_app_sign_out_path, "post"
  end

  test "post sign out without region uses the default completion region" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    authenticate_rp!(user, token)

    post core_app_sign_out_url, headers: app_session_headers(user, token)

    assert_response :see_other
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_visa_end_session_redirect(
      query, location, client_id: "core-app-jp", region: RequestContextContract.default_region,
    )
  end

  test "post sign out does not route through Auth" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    authenticate_rp!(user, token)

    post core_app_sign_out_url(ri: "jp"), headers: app_session_headers(user, token)

    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_VISA_SERVICE_URL", "visa.app.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_not_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), location.host
  end

  private

  def assert_visa_end_session_redirect(query, location, client_id:, region:)
    client = OidcClientRegistry.find!(client_id)

    assert_equal ENV.fetch("PUBLIC_VISA_SERVICE_URL", "visa.app.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_equal client_id, query.fetch("client_id")
    assert_predicate query["id_token_hint"], :present?
    assert_predicate query["state"], :present?
    assert_equal client.post_logout_redirect_uris.find { |uri| uri.include?("ri=#{region}") },
                 query.fetch("post_logout_redirect_uri")
    assert_nil query["logout_challenge"]
  end

  def authenticate_rp!(user, token)
    oidc_client = OidcClientRegistry.find!("core-app-jp")
    @rp_session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: token,
      oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    store_oidc_rp_logout_hint!(@rp_session, user, oidc_client)
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

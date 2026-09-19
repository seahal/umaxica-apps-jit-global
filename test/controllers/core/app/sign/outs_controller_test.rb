# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Core::App::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds

  setup do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"))
  end

  test "get sign out renders confirmation without mutation" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get edit_core_app_sign_out_url(ri: "jp"), headers: app_session_headers(user, token)

    assert_response :success
    assert_select "form[action*=?][method=?]", core_app_sign_out_path, "post"
    assert_predicate token.reload, :currently_usable?
  end

  # Core keeps its sign-out pages in ERB, which cannot carry Inertia's clearHistory. The completion
  # response instead tells the browser to drop this origin's cache and storage; storage includes
  # the sessionStorage key that decrypts Core's Inertia history.
  test "sign-out completion clears this origin's cache and storage" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post core_app_sign_out_url(ri: "jp"), headers: app_session_headers(user, token)
    state = Rack::Utils.parse_nested_query(URI.parse(handoff_form["action"]).query.to_s).fetch("state")

    get core_app_sign_out_url(ri: "jp", state: state)

    assert_response :success
    assert_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
    assert_equal '"cache", "storage"', response.headers["Clear-Site-Data"]
  end

  test "the sign-out confirmation page does not clear site data" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get edit_core_app_sign_out_url(ri: "jp"), headers: app_session_headers(user, token)

    assert_response :success
    assert_nil response.headers["Clear-Site-Data"]
  end

  test "post sign out redirects to base oidc logout with completion state" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post core_app_sign_out_url(ri: "jp"), headers: app_session_headers(user, token)

    assert_response :success
    location = URI.parse(handoff_form["action"])
    Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL", "www.app.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate handoff_input_value("logout_challenge"), :present?
    assert_equal "jp", handoff_input_value("ri")
    assert_predicate token.reload, :revoked?
  end

  test "post sign out accepts us region" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post core_app_sign_out_url(ri: "us"), headers: app_session_headers(user, token)

    assert_response :success
    location = URI.parse(handoff_form["action"])
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL", "www.app.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_equal "us", handoff_input_value("ri")
    assert_includes query.fetch("post_logout_redirect_uri"), "ri=us"
    assert_predicate handoff_input_value("logout_challenge"), :present?
    assert_predicate token.reload, :revoked?
  end

  test "post sign out canonicalizes unsupported region to default" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post core_app_sign_out_url(ri: "xx"), headers: app_session_headers(user, token)

    assert_response :success
    location = URI.parse(handoff_form["action"])
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal "/oidc/logout", location.path
    assert_equal RequestContextContract.default_region, handoff_input_value("ri")
    assert_includes query.fetch("post_logout_redirect_uri"), "ri=#{RequestContextContract.default_region}"
    assert_predicate token.reload, :revoked?
  end

  test "transaction issuance failure does not render success completion" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!
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
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
    assert_includes response.body, I18n.t("sign.shared.sign_out.unavailable_title")
    assert_select "form[action*=?][method=?]", core_app_sign_out_path, "post"
  end

  test "post sign out without region uses the default completion region" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post core_app_sign_out_url, headers: app_session_headers(user, token)

    assert_response :success
    location = URI.parse(handoff_form["action"])
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL", "www.app.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate handoff_input_value("logout_challenge"), :present?
    assert_equal RequestContextContract.default_region, handoff_input_value("ri")
    assert_includes query.fetch("post_logout_redirect_uri"), "ri=#{RequestContextContract.default_region}"
  end

  test "post sign out relay advances to sign coordination hop" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post core_app_sign_out_url(ri: "jp"), headers: app_session_headers(user, token)

    challenge = handoff_input_value("logout_challenge")

    post acme_app_oidc_logout_url(
      host: ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost"), ri: "jp",
      logout_challenge: challenge,
    ), headers: {
      "Host" => ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost"),
      "Origin" => "https://#{ENV.fetch(
        "PUBLIC_CORE_SERVICE_URL",
        ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"),
      )}",
      "Sec-Fetch-Site" => "same-site",
    }

    assert_response :success
    location = URI.parse(handoff_form["action"])

    assert_equal Rails.configuration.x.boot_config.fetch(:hosts).sign_service.host, location.host
    assert_equal "/sign/out", location.path
    assert_equal challenge, handoff_input_value("logout_challenge")
    assert_equal "jp", handoff_input_value("ri")
  end

  private

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
    "surface:SIGN_#{surface}"
  end

  def handoff_form
    assert_select "form#sign-out-handoff-form[method=post][data-turbo=false]", 1
    css_select("form#sign-out-handoff-form").first
  end

  def handoff_input_value(name)
    css_select(%(form#sign-out-handoff-form input[name="#{name}"])).first&.[]("value")
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

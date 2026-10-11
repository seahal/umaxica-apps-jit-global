# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcSsoInitiatorTestController < ApplicationController
  include OidcSsoInitiator

  def index
    authenticate!
    head :ok unless performed?
  end

  def fresh
    redirect_to_oidc_authorization_url(initiate_oidc_session!(pt: "/fresh", prompt: "login", max_age: 60))
  end

  def logged_in?
    request.headers["X-Logged-In"] == "1"
  end

  def current_resource
    Struct.new(:id).new(42)
  end

  def oidc_client_id
    "base-rails-rp"
  end

  def oidc_sign_host
    Rails.configuration.x.boot_config.fetch(:hosts).sign_service.host
  end

  # Base::App::ApplicationController resolves this to PUBLIC_BASE_SERVICE_URL, which is
  # same-site with the Auth host. Pointing the stand-in at a different family would make
  # the hop cross-site and exercise the jump gateway instead of the direct authorize path.
  def oidc_base_authority_host
    Rails.configuration.x.boot_config.fetch(:hosts).base_service.host
  end

  def oidc_callback_url
    "https://#{Rails.configuration.x.boot_config.fetch(:hosts).acme_service.host}/oidc/callback"
  end

  def jump_rt_issuer_namespace
    "ACME_APP"
  end
end

class OidcSsoInitiatorRegistryCallbackTestController < ApplicationController
  include OidcSsoInitiator

  def oidc_client_id
    "base-rails-rp"
  end
end

class OidcSsoInitiatorTest < ActionDispatch::IntegrationTest
  setup do
    load_jump_rt_env!
    Rails.application.routes.draw do
      get "/oidc/sso" => "oidc_sso_initiator_test#index"
      get "/oidc/sso/fresh" => "oidc_sso_initiator_test#fresh"
    end
  end

  teardown do
    Rails.application.reload_routes!
    # Several tests below redefine these on the controller class to drive a specific
    # redirect decision. define_method is permanent, so without this the next test in the
    # process inherits the override and the file's results depend on the run order.
    OidcSsoInitiatorTestController.define_method(:oidc_base_authority_host) do
      Rails.configuration.x.boot_config.fetch(:hosts).base_service.host
    end
    OidcSsoInitiatorTestController.define_method(:oidc_callback_url) do
      "https://#{Rails.configuration.x.boot_config.fetch(:hosts).acme_service.host}/oidc/callback"
    end
  end

  test "authenticate! redirects unauthenticated html requests to oidc authorize url" do
    io = StringIO.new
    logger = Logger.new(io)

    Rails.stub(:logger, logger) do
      get "/oidc/sso", headers: { "Host" => configured_host(:sign_service), "HTTPS" => "on" }
    end

    assert_response :redirect
    location = response.location
    uri = URI.parse(location)

    assert_equal configured_host(:base_service), uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_not_equal "jump.umaxica.net", uri.host

    authorize_params = Rack::Utils.parse_nested_query(uri.query)

    assert_equal "base-rails-rp", authorize_params.fetch("client_id")
    assert_equal "https://#{configured_host(:acme_service)}/oidc/callback", authorize_params.fetch("redirect_uri")
    session_cookie =
      response.headers["Set-Cookie"].to_s.split("\n").find { |line| line.start_with?("session=") }

    assert_predicate session_cookie, :present?
    assert_operator session_cookie.bytesize, :<, 3500
    assert_nil session[:oidc_code_verifier]
    assert_nil session[:oidc_state]
    assert_nil session[:oidc_nonce]
    assert_nil session[:oidc_pt]
    pending_flow = session.fetch("oidc_pending_flows").fetch(authorize_params.fetch("state"))

    assert_predicate pending_flow.fetch("code_verifier"), :present?
    assert_equal authorize_params.fetch("nonce"), pending_flow.fetch("nonce")
    assert_equal "/oidc/sso", pending_flow.fetch("pt")
    assert_includes io.string, "oidc.sso.redirect_policy.direct"
    assert_includes io.string, "reason_code"
    assert_includes io.string, "target_host"
    assert_not_includes io.string, authorize_params.fetch("state")
    assert_not_includes io.string, authorize_params.fetch("nonce")
    assert_not_includes io.string, pending_flow.fetch("code_verifier")
    assert_not_includes io.string, response.location
    assert_not_includes io.string, "oauth/authorize?"
  end

  test "authenticate! preserves the protected request query in oidc return path" do
    # https, as a browser would: an http request to a public host is a scheme mismatch and
    # takes the jump gateway instead of the direct authorize hop.
    get "/oidc/sso", params: { ri: "jp" },
                     headers: { "Host" => configured_host(:sign_service), "HTTPS" => "on" }

    assert_response :redirect
    assert_nil session[:oidc_pt]

    query = Rack::Utils.parse_nested_query(URI.parse(response.location).query)
    pending_flow = session.fetch("oidc_pending_flows").fetch(query.fetch("state"))

    assert_equal "/oidc/sso?ri=jp", pending_flow.fetch("pt")
  end

  test "authorization URL carries prompt and max_age into the pending flow" do
    get "/oidc/sso/fresh", headers: { "Host" => configured_host(:sign_service), "HTTPS" => "on" }

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(uri.query)

    assert_equal "login", query.fetch("prompt")
    assert_equal "60", query.fetch("max_age")
    assert_equal 60, session.fetch("oidc_pending_flows").fetch(query.fetch("state")).fetch("max_age")
  end

  test "token endpoint uses local rails port for local public Acme hosts" do
    # This test is about the .localhost rewrite, so it states a local authority host
    # instead of inheriting the configured public one. The teardown restores it.
    OidcSsoInitiatorTestController.define_method(:oidc_base_authority_host) do
      Rails.configuration.x.boot_config.fetch(:hosts).acme_service.host
    end
    controller = OidcSsoInitiatorTestController.new
    controller.request = ActionDispatch::TestRequest.create(
      "HTTP_HOST" => configured_host(:sign_service),
      "HTTPS" => "on",
    )

    with_env("PORT" => "3000") do
      assert_equal "http://#{configured_host(:acme_service)}:3000/oauth/token", controller.send(:oidc_token_url)
    end
  end

  test "token endpoint keeps public https origin outside local environments" do
    controller = OidcSsoInitiatorTestController.new
    controller.request = ActionDispatch::TestRequest.create(
      "HTTP_HOST" => configured_host(:sign_service),
      "HTTPS" => "on",
    )

    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      assert_equal "https://#{configured_host(:base_service)}/oauth/token", controller.send(:oidc_token_url)
    end
  end

  test "token endpoint local rewrite is limited to configured Acme hosts" do
    unconfigured_acme_host = "acme-unconfigured.example.test"
    OidcSsoInitiatorTestController.define_method(:oidc_base_authority_host) { unconfigured_acme_host }
    controller = OidcSsoInitiatorTestController.new
    controller.request = ActionDispatch::TestRequest.create(
      "HTTP_HOST" => configured_host(:sign_service),
      "HTTPS" => "on",
    )

    with_env("PORT" => "3000") do
      assert_equal "https://#{unconfigured_acme_host}/oauth/token", controller.send(:oidc_token_url)
    end
  ensure
    OidcSsoInitiatorTestController.define_method(:oidc_base_authority_host) do
      Rails.configuration.x.boot_config.fetch(:hosts).acme_service.host
    end
  end

  test "oidc callback url fails closed when request host is not registered for the client" do
    controller = OidcSsoInitiatorRegistryCallbackTestController.new
    controller.request = ActionDispatch::TestRequest.create(
      "HTTP_HOST" => "attacker.example.test",
      "HTTPS" => "on",
    )

    assert_raises(ActionController::BadRequest) do
      controller.send(:oidc_callback_url)
    end
  end

  test "authenticate! keeps using jump for cross-site oidc authorize urls" do
    cross_site_acme_host = configured_host(:acme_corporate)
    OidcSsoInitiatorTestController.define_method(:oidc_base_authority_host) { cross_site_acme_host }
    OidcSsoInitiatorTestController.define_method(:oidc_callback_url) do
      "https://#{cross_site_acme_host}/oidc/callback"
    end

    io = StringIO.new
    logger = Logger.new(io)

    Rails.stub(:logger, logger) do
      https!
      get("/oidc/sso", headers: { "Host" => configured_host(:sign_service) })
    end

    assert_response :redirect
    assert_equal "jump.umaxica.net", URI.parse(response.location).host
    location = jump_rt_url_from_location(response.location)

    uri = URI.parse(location)

    assert_equal "https", uri.scheme
    assert_equal cross_site_acme_host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_includes io.string, "oidc.sso.redirect_policy.jump"
    assert_includes io.string, "reason_code"
    assert_includes io.string, "site_mismatch"
    assert_not_includes io.string, "state"
    assert_not_includes io.string, "nonce"
    assert_not_includes io.string, "code_challenge"
  ensure
    OidcSsoInitiatorTestController.define_method(:oidc_base_authority_host) do
      Rails.configuration.x.boot_config.fetch(:hosts).acme_service.host
    end
    OidcSsoInitiatorTestController.define_method(:oidc_callback_url) do
      "https://#{Rails.configuration.x.boot_config.fetch(:hosts).acme_service.host}/oidc/callback"
    end
  end

  test "safe_oidc_pt strips foreign hosts" do
    controller = OidcSsoInitiatorTestController.new
    controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "www.example.com")

    assert_equal "/", controller.send(:safe_oidc_pt, "http://attacker.example/evil")
    assert_equal "/", controller.send(:safe_oidc_pt, "https://attacker.example/evil")
    assert_equal "/",
                 controller.send(
                   :safe_oidc_pt,
                   "https://#{configured_host(:acme_service)}/oauth/authorize?client_id=base-rails-rp",
                 )
  end

  test "safe_oidc_pt rejects scheme based payloads" do
    controller = OidcSsoInitiatorTestController.new
    controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "www.example.com")

    assert_equal "/", controller.send(:safe_oidc_pt, "javascript:alert(1)")
    assert_equal "/", controller.send(:safe_oidc_pt, "data:text/html,<script>")
    assert_equal "/", controller.send(:safe_oidc_pt, "//attacker.example/")
  end

  test "safe_oidc_pt rejects userinfo even when host matches" do
    controller = OidcSsoInitiatorTestController.new
    controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "www.example.com")

    assert_equal "/", controller.send(:safe_oidc_pt, "http://attacker@www.example.com/path")
    assert_equal "/", controller.send(:safe_oidc_pt, "http://user:pw@www.example.com/path")
  end

  test "safe_oidc_pt rejects control characters" do
    controller = OidcSsoInitiatorTestController.new
    controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "www.example.com")

    assert_equal "/", controller.send(:safe_oidc_pt, "/foo\r\nSet-Cookie: x=1")
    assert_equal "/", controller.send(:safe_oidc_pt, "/foo\x00bar")
  end

  test "safe_oidc_pt returns same-host internal path only" do
    controller = OidcSsoInitiatorTestController.new
    controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "www.example.com")

    assert_equal "/oidc/sso", controller.send(:safe_oidc_pt, "http://www.example.com/oidc/sso")
    assert_equal "/oidc/sso?ri=jp", controller.send(:safe_oidc_pt, "http://www.example.com/oidc/sso?ri=jp")
    assert_equal "/already/relative", controller.send(:safe_oidc_pt, "/already/relative")
  end

  test "authenticate! renders unauthorized json for unauthenticated json requests" do
    get "/oidc/sso", as: :json

    assert_response :unauthorized
    assert_equal({ "error" => "Unauthorized" }, response.parsed_body)
  end

  test "authenticate! calls risk enforcer for logged in clients" do
    called = false

    SignRiskEnforcer.stub(:call, ->(_resource) { called = true }) do
      get "/oidc/sso", headers: { "X-Logged-In" => "1" }
    end

    assert_response :ok
    assert called
  end

  private

  def with_env(values)
    previous = {}
    values.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end

# DAMP local helper copy for former shared test support.
class OidcSsoInitiatorTestController
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    headers = {
      "Client-Agent" => TEST_BROWSER_USER_AGENT,
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "X-CSRF-Token" => csrf_token,
    }
    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end
    headers
  end

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)
    return base unless user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"

    ensure_user_token_reference_records!
    token = session_public_id.present? ? ClientToken.find_by(public_id: session_public_id) : nil
    token ||= ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
    token ||= ClientToken.create!(
      user_id: user.id,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)
    return base unless staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"

    ensure_staff_token_reference_records!
    token = session_public_id.present? ? OperatorToken.find_by(public_id: session_public_id) : nil
    token ||= OperatorToken.where(staff_id: staff.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= OperatorToken.create!(
      staff_id: staff.id,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)
    return base unless visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"

    ensure_visitor_token_reference_records!
    token = session_public_id.present? ? VisitorToken.find_by(public_id: session_public_id) : nil
    token ||= VisitorToken.where(visitor_id: visitor.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= VisitorToken.create!(
      visitor_id: visitor.id,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil, resource_type: nil,
                           dpop_jkt: nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || "unknown"
    resource_type ||=
      case resource
      when Client then "client"
      when Operator then "operator"
      when Visitor then "visitor"
      end
    AuthenticationToken.encode(
      resource,
      host: host_value,
      session_id: session_id,
      session_public_id: session_public_id,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: jwt_issuer_id_for_test_host(host_value, resource_type),
    )
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "SIGN")
    surface =
      if service == "SIGN"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
    if defined?(VisitorSecretCredentialStatus)
      [
        VisitorSecretCredentialStatus::ACTIVE,
        VisitorSecretCredentialStatus::EXPIRED,
        VisitorSecretCredentialStatus::REVOKED,
        VisitorSecretCredentialStatus::USED,
        VisitorSecretCredentialStatus::DELETED,
        VisitorSecretCredentialStatus::NOTHING,
      ].each do |id|
        VisitorSecretCredentialStatus.find_or_create_by!(id: id)
      end
    end
    return unless defined?(VisitorSecretCredentialKind)

    [VisitorSecretCredentialKind::LOGIN, VisitorSecretCredentialKind::RECOVERY,
     VisitorSecretCredentialKind::API,].each do |id|
      VisitorSecretCredentialKind.find_or_create_by!(id: id)
    end

  end

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    insert_verified_visitor_email!(visitor_id: visitor.id, address: email_address)
    visitor.refresh_mfa_status! if visitor.respond_to?(:refresh_mfa_status!)
    visitor.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def insert_verified_visitor_email!(visitor_id:, address:)
    VisitorEmail.insert_all(
      [
        {
          visitor_id: visitor_id,
          address: address,
          address_digest: IdentifierBlindIndex.bidx_for_email(address),
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          otp_private_key: SecureRandom.base64(24),
          otp_counter: "",
          otp_attempts_count: 0,
          public_id: SecureRandom.alphanumeric(21),
          created_at: Time.current,
          updated_at: Time.current,
        },
      ],
    )
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_visitor_verification(token, scope: nil)
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    attrs = {
      last_step_up_at: at,
      last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
      last_step_up_aal: ("aal2" if token.respond_to?(:last_step_up_aal)),
      last_step_up_method: ("passkey" if token.respond_to?(:last_step_up_method)),
      last_step_up_session_public_id: (token.public_id if token.respond_to?(:last_step_up_session_public_id)),
      last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
      last_step_up_audience: (step_up_test_audience_for_token(token) if token.respond_to?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    when "VisitorToken" then "step_up:com"
    else "step_up:app"
    end
  end

  def signed_step_up_pt_for(path, surface:, session_nonce:)
    safe_path = path.to_s
    return nil if safe_path.blank? || !safe_path.start_with?("/") || safe_path.match?(/[\x00-\x1F\x7F]/)

    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256",
      serializer: JSON,
      url_safe: true,
    )
    verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => surface.to_s,
        "session_nonce" => session_nonce.to_s,
        "pt" => safe_path, },
      purpose: :path_target,
      expires_in: 15.minutes,
    )
  end

  def signed_step_up_grant_for(actor:, token:, scope:, return_to:, surface:, methods: %i(email_otp totp passkey),
                               aal: "aal2")
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface.to_s,
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      required_scope: scope.to_s,
      required_aal: aal,
      allowed_methods: methods,
      return_to: return_to,
      expires_at: 15.minutes.from_now,
    ).grant
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    {
      "JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
      "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
      "JWT_SIGN_APP_ACTIVE_KID" => "sign-app-test",
      "JWT_SIGN_APP_PRIVATE_KEY" => jump_rt_key,
      "JWT_SIGN_ORG_ACTIVE_KID" => "sign-org-test",
      "JWT_SIGN_ORG_PRIVATE_KEY" => jump_rt_key,
      "JWT_SIGN_COM_ACTIVE_KID" => "sign-com-test",
      "JWT_SIGN_COM_PRIVATE_KEY" => jump_rt_key,
      "JWT_ACME_APP_ACTIVE_KID" => "acme-app-test",
      "JWT_ACME_APP_PRIVATE_KEY" => jump_rt_key,
      "JWT_ACME_ORG_ACTIVE_KID" => "acme-org-test",
      "JWT_ACME_ORG_PRIVATE_KEY" => jump_rt_key,
      "JWT_ACME_COM_ACTIVE_KID" => "acme-com-test",
      "JWT_ACME_COM_PRIVATE_KEY" => jump_rt_key,
      "JWT_CORE_APP_ACTIVE_KID" => "core-app-test",
      "JWT_CORE_APP_PRIVATE_KEY" => jump_rt_key,
      "JWT_CORE_ORG_ACTIVE_KID" => "core-org-test",
      "JWT_CORE_ORG_PRIVATE_KEY" => jump_rt_key,
      "JWT_CORE_COM_ACTIVE_KID" => "core-com-test",
      "JWT_CORE_COM_PRIVATE_KEY" => jump_rt_key,
      "JWT_BASE_APP_ACTIVE_KID" => "base-app-test",
      "JWT_BASE_APP_PRIVATE_KEY" => jump_rt_key,
      "JWT_BASE_ORG_ACTIVE_KID" => "base-org-test",
      "JWT_BASE_ORG_PRIVATE_KEY" => jump_rt_key,
      "JWT_BASE_COM_ACTIVE_KID" => "base-com-test",
      "JWT_BASE_COM_PRIVATE_KEY" => jump_rt_key,
    }.each do |key, value|
      @jump_rt_env_originals[key] = ENV[key] unless @jump_rt_env_originals.key?(key)
      ENV[key] = value
    end
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def csrf_headers(token)
    { "X-CSRF-Token" => token }
  end

  def fetch_csrf_token(path)
    get(path)
    response.body[/name="authenticity_token" value="([^"]+)"/, 1] || response.body
  end

  def social_callback_headers(host)
    scheme = host.to_s.include?("localhost") ? "http" : "https"
    origin = "#{scheme}://#{host}"
    cookies["csrf_token"] = csrf_token_value if respond_to?(:cookies)
    {
      "Host" => host,
      "Origin" => origin,
      "Referer" => "#{origin}/",
      "Sec-Fetch-Site" => "same-origin",
      "X-STRICT-SOCIAL-STATE" => "1",
      "X-CSRF-Token" => csrf_token_value,
    }
  end

  def social_auth_state_from_response
    session[:social_auth_state].presence || begin
      uri = URI.parse(response.location.to_s)
      Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
    rescue URI::InvalidURIError
      nil
    end
  end

  def seed_social_auth_session(provider:, intent: "login", user: nil, entry: nil, ri: "jp", rt: nil, referer: nil)
    host = configured_host(:sign_service)
    host!(host) if respond_to?(:host!)
    normalized_provider = SocialIdentifiable.normalize_provider(provider)
    continue_path =
      if intent.to_s == "link"
        public_send(:"auth_app_settings_#{normalized_provider}_path", ri: ri)
      elsif entry.to_s == "sign_up"
        public_send(:"auth_app_social_#{normalized_provider}_registration_path", ri: ri, rt: rt)
      else
        public_send(:"auth_app_social_#{normalized_provider}_session_path", ri: ri, rt: rt)
      end
    headers = social_callback_headers(host)
    headers["Referer"] = referer if referer.present?
    if user
      user_headers = as_user_headers(user, host: host)
      token = ClientToken.find_by(public_id: user_headers["X-TEST-SESSION-PUBLIC-ID"])
      mark_token_step_up_satisfied_for_test(
        token,
        scope: SocialAuth::SOCIAL_LINK_SCOPE,
      ) if intent.to_s == "link" && token
      headers = headers.merge(user_headers)
    end
    post(continue_path, headers: headers)
    social_auth_state_from_response
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines =
      case raw
      when Array then raw
      when String then raw.split("\n")
      else []
      end
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def assert_oidc_authorize_redirect(location, host:, client_id: "base-rails-rp")
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal client_id, query["client_id"]
    assert_predicate query["state"], :present?
  end
end

# DAMP local helper copy on the test class.
class OidcSsoInitiatorTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def with_preference_jwt_keys(host: nil)
    audiences = host ? [host] : PreferenceJwtConfiguration.audiences
    pub_key_for_stub = ->(_kid, **_options) { self.class::PREFERENCE_JWT_KEY }
    PreferenceJwtConfiguration.stub(:private_key, self.class::PREFERENCE_JWT_KEY) do
      PreferenceJwtConfiguration.stub(:public_key, self.class::PREFERENCE_JWT_KEY) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, self.class::PREFERENCE_JWT_KEY) do
          PreferenceJwtConfiguration.stub(:public_key_for, pub_key_for_stub) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, audiences) { yield }
              end
            end
          end
        end
      end
    end
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    host_headers.merge("X-CSRF-Token" => csrf_token)
  end

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)
    return base unless user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"

    ensure_user_token_reference_records!
    token = session_public_id.present? ? ClientToken.find_by(public_id: session_public_id) : nil
    token ||= ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
    token ||= ClientToken.create!(
      user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)
    return base unless staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"

    ensure_staff_token_reference_records!
    token = session_public_id.present? ? OperatorToken.find_by(public_id: session_public_id) : nil
    token ||= OperatorToken.where(staff_id: staff.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= OperatorToken.create!(
      staff_id: staff.id, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)
    return base unless visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"

    ensure_visitor_token_reference_records!
    token = session_public_id.present? ? VisitorToken.find_by(public_id: session_public_id) : nil
    token ||= VisitorToken.where(visitor_id: visitor.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= VisitorToken.create!(
      visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_visitor_verification(token, scope: nil)
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(SIGN_APP SIGN_ORG SIGN_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google_app] =
      OmniAuth::AuthHash.new(
        provider: "google_app", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end

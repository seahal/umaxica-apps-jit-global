# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/oidc_auth_admission_test_helper"

class SocialCallbackGuardTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers
  include OidcAuthAdmissionTestHelper

  self.fixture_table_names = []

  setup do
    @previous_omniauth_mode = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = true
    @previous_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    https!
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @previous_id_service_url = ENV["PRIVATE_AUTH_SERVICE_URL"]
    ENV["PRIVATE_AUTH_SERVICE_URL"] = @host
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)
    SocialCallbackGuard.instance_variable_set(:@allowed_request_origins, nil)
  end

  teardown do
    OmniAuth.config.test_mode = @previous_omniauth_mode
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    ActionController::Base.allow_forgery_protection = @previous_protection
    if @previous_id_service_url.nil?
      ENV.delete("PRIVATE_AUTH_SERVICE_URL")
    else
      ENV["PRIVATE_AUTH_SERVICE_URL"] = @previous_id_service_url
    end
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)
    SocialCallbackGuard.instance_variable_set(:@allowed_request_origins, nil)
  end

  test "callback phase rejects when state is missing without consuming provider state" do
    state, state_row, ceremony = begin_google_attempt!
    before = ceremony.reload.attributes
    token_count = ClientToken.count

    get auth_app_social_google_callback_path(ri: "jp"), headers: provider_callback_headers

    assert_response :forbidden
    assert_equal auth_app_sign_in_url(host: @host, protocol: "https", ri: "jp"), response.location
    assert_nil state_row.reload.consumed_at
    assert_equal before, ceremony.reload.attributes
    assert_equal token_count, ClientToken.count
    assert_predicate state, :present?
  end

  test "callback phase rejects a mismatched state without consuming the expected state" do
    _state, state_row, ceremony = begin_google_attempt!
    before = ceremony.reload.attributes

    get auth_app_social_google_callback_path(ri: "jp", state: "unrelated-state"),
        headers: provider_callback_headers

    assert_response :forbidden
    assert_equal auth_app_sign_in_url(host: @host, protocol: "https", ri: "jp"), response.location
    assert_nil state_row.reload.consumed_at
    assert_equal before, ceremony.reload.attributes
  end

  test "callback phase rejects an expired state without consuming it" do
    state, state_row, ceremony = begin_google_attempt!
    before = ceremony.reload.attributes

    travel_to(6.minutes.from_now) do
      get auth_app_social_google_callback_path(ri: "jp", state: state),
          headers: provider_callback_headers
    end

    assert_response :forbidden
    assert_nil state_row.reload.consumed_at
    assert_equal before, ceremony.reload.attributes
  end

  test "callback phase rejects a replay after the verified callback consumed state" do
    state, state_row, ceremony = begin_google_attempt!
    headers = provider_callback_headers(origin: "https://accounts.google.com")

    get auth_app_social_google_callback_path(ri: "jp", state: state), headers: headers

    assert_response :bad_request
    assert_predicate state_row.reload.consumed_at, :present?
    assert_not_predicate ceremony.reload, :authentication_evidence_recorded?
    token_count = ClientToken.count

    get auth_app_social_google_callback_path(ri: "jp", state: state), headers: headers

    assert_response :forbidden
    assert_equal token_count, ClientToken.count
    assert_predicate state_row.reload.consumed_at, :present?
  end

  test "callback phase rejects a host excluded by the social callback policy" do
    state, state_row, ceremony = begin_google_attempt!
    before = ceremony.reload.attributes

    SocialCallbackGuard.stub(:allowed_hosts, ["unrelated.example"]) do
      get auth_app_social_google_callback_path(ri: "jp", state: state), headers: provider_callback_headers
    end

    assert_response :forbidden
    assert_equal auth_app_sign_in_url(host: @host, protocol: "https", ri: "jp"), response.location
    assert_nil state_row.reload.consumed_at
    assert_equal before, ceremony.reload.attributes
  end

  test "callback endpoint refuses a non-GET callback method" do
    state, state_row, ceremony = begin_google_attempt!
    before = ceremony.reload.attributes

    post auth_app_social_google_callback_path(ri: "jp", state: state), headers: provider_callback_headers

    assert_response :not_found
    assert_nil state_row.reload.consumed_at
    assert_equal before, ceremony.reload.attributes
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
  end

  test "callback accepts the provider origin after matching state validation" do
    state, state_row, ceremony = begin_google_attempt!

    get auth_app_social_google_callback_path(ri: "jp", state: state),
        headers: provider_callback_headers(origin: "https://accounts.google.com")

    assert_response :bad_request
    assert_equal I18n.t("sign.app.social.verified_subject_guidance.unregistered.title"),
                 response.parsed_body.at_css("h1").text
    assert_predicate state_row.reload.consumed_at, :present?
    assert_not_predicate ceremony.reload, :authentication_evidence_recorded?
  end

  test "Google callback GET without an Origin header reaches verified subject handling" do
    state, state_row, ceremony = begin_google_attempt!

    get auth_app_social_google_callback_path(ri: "jp", state: state), headers: provider_callback_headers

    assert_response :bad_request
    assert_predicate state_row.reload.consumed_at, :present?
    assert_not_predicate ceremony.reload, :authentication_evidence_recorded?
  end

  test "module helpers normalize methods, hosts, and origins" do
    assert SocialCallbackGuard.allowed_request_method?("google", "POST")
    assert_not SocialCallbackGuard.allowed_request_method?("google", "GET")
    assert_not SocialCallbackGuard.allowed_callback_method?("apple", "POST")
    assert SocialCallbackGuard.allowed_callback_method?("apple", "GET")
    assert_equal "id.app.localhost", SocialCallbackGuard.normalize_host_port("https://id.app.localhost")
    assert_equal "id.app.localhost:444", SocialCallbackGuard.normalize_host_port("https://id.app.localhost:444")
    assert_nil SocialCallbackGuard.normalize_host_port("::not a uri::")
    assert_equal "https://id.app.localhost", SocialCallbackGuard.normalize_origin("https://id.app.localhost")
    assert_equal "https://id.app.localhost:444", SocialCallbackGuard.normalize_origin("https://id.app.localhost:444/path")
    assert_nil SocialCallbackGuard.normalize_origin("ftp://id.app.localhost")
    assert_equal "https://id.app.localhost", SocialCallbackGuard.sanitize_source_header("https://id.app.localhost/path")
  end

  test "allowed hosts includes sign host environment names" do
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)

    begin
      with_env("PRIVATE_AUTH_SERVICE_URL" => "log.umaxica.app", "AUTH_STAFF_URL" => "log.umaxica.org") do
        SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)

        assert_includes SocialCallbackGuard.allowed_hosts, "log.umaxica.app"
        assert_includes SocialCallbackGuard.allowed_hosts, "log.umaxica.org"
      end
    ensure
      SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)
    end
  end

  # test_helper defines AUTH_SERVICE_URL / AUTH_STAFF_URL, but deployments
  # configure only the PUBLIC_ and PRIVATE_ variants. Without this guard the unset aliases raised
  # KeyError inside the Google callback instead of being skipped.
  test "allowed hosts skips auth host aliases that are not configured" do
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)

    begin
      with_env("AUTH_SERVICE_URL" => nil, "AUTH_STAFF_URL" => nil) do
        SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)

        hosts = SocialCallbackGuard.allowed_hosts

        assert_includes hosts, ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        assert_includes hosts, ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      end
    ensure
      SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)
    end
  end

  test "request phase helpers derive source, enforce state, and reject bad methods" do
    env = Rack::MockRequest.env_for(
      "https://#{@host}/social/google?foo=bar",
      "REQUEST_METHOD" => "POST",
      "HTTP_ORIGIN" => "https://#{@host}",
      "rack.session" => {},
    )

    source, normalized = SocialCallbackGuard.normalized_request_source(Rack::Request.new(env))

    assert_equal :origin, source
    assert_equal "https://#{@host}", normalized

    SocialCallbackGuard.ensure_state_query_param!(env, Rack::Request.new(env), "google")

    assert_includes env["QUERY_STRING"], "state="
    assert_equal "google", env["rack.session"][SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]

    env_with_state = Rack::MockRequest.env_for(
      "https://#{@host}/social/google?state=known",
      "REQUEST_METHOD" => "POST",
      "HTTP_ORIGIN" => "https://#{@host}",
      "rack.session" => {},
    )

    assert_nil SocialCallbackGuard.verify_request_phase!(env_with_state)
    assert_equal "known", env_with_state["rack.session"][SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]

    rejected = SocialCallbackGuard.verify_request_phase!(
      Rack::MockRequest.env_for(
        "https://#{@host}/social/google",
        "REQUEST_METHOD" => "DELETE",
        "HTTP_ORIGIN" => "https://#{@host}",
        "rack.session" => {},
      ),
    )

    assert_equal 403, rejected.first
  end

  private

  def begin_google_attempt!
    auth = OmniAuth::AuthHash.new(
      provider: "google",
      uid: "callback-guard-#{SecureRandom.hex(12)}",
      info: { email: "callback-guard@example.com", name: "Google Client" },
      credentials: { token: "google-token", expires_at: 1.hour.from_now.to_i },
    )
    OmniAuth.config.mock_auth[:google] = auth
    OmniAuth.config.mock_auth[:google_app] = auth
    bootstrap_auth_sign_in_admission!(surface: "app", region: "jp", target_link_uri: "/dashboard")
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')&.[]("content")

    assert_predicate csrf, :present?

    post(
      auth_app_social_google_session_path(ri: "jp"), params: { ri: "jp" }, headers: {
        "Origin" => "https://#{@host}",
        "Sec-Fetch-Site" => "same-origin",
        "X-CSRF-Token" => csrf,
      },
    )

    assert_equal 307, response.status

    state = session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    state_row = ClientOauthCallbackState.find_by!(
      state_digest: ClientOauthCallbackState.digest_state(state),
    )
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[cookie_name])
    raise RuntimeError, "social provider start has no active Auth ceremony" unless ceremony

    [state, state_row, ceremony]
  end

  def provider_callback_headers(origin: nil)
    headers = {
      "Host" => @host,
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    headers["Origin"] = origin if origin
    headers
  end

  def callback_headers(host: @host, origin: nil, referer: nil)
    headers = { "Host" => host, "X-STRICT-SOCIAL-STATE" => "1" }
    headers["Origin"] = origin if origin
    headers["Referer"] = referer if referer
    headers
  end

  def setup_apple_mock_auth(uid:)
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: uid,
      info: {},
      credentials: {
        token: "apple_token_#{SecureRandom.hex(8)}",
        discard_at: 1.week.from_now.to_i,
      },
    )
  end

  def create_google_identity!(user:, uid:)
    ClientGoogleIdentity.create!(
      user: user,
      uid: uid,
      provider: "google",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
  end

  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class SocialCallbackGuardTest
  private
end

# DAMP local helper copy for former shared test support.
class SocialCallbackGuardTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
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

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
    )
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :app),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
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

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
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

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
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

  def assert_oidc_authorize_redirect(location, host:, client_id: "base-rails-rp")
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal client_id, query["client_id"]
    assert_predicate query["state"], :present?
  end
end

# DAMP local route helper aliases for former shared test support.
class SocialCallbackGuardTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
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

# DAMP local helper copy on the test class.
class SocialCallbackGuardTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )

  private

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
    %w(AUTH_APP AUTH_ORG AUTH_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
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

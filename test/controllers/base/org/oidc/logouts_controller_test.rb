# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
# require "helpers/auth_helpers"

class Base::Org::Oidc::LogoutsControllerTest < ActionDispatch::IntegrationTest
  # include AuthHelpers

  self.fixture_table_names = []

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    @client = OidcClientRegistry.find!("core-org")
    @operator = Operator.create!(
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    @token = OperatorToken.create!(
      staff: @operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
    )
    @session_public_id = @token.public_id
    # Cookies only reach the request when the integration session's host matches it.
    host! @host
    https!
    # The staged logout confirmation redirects through the jump gateway, which needs signing keys.
    load_jump_rt_env!
  end

  test "routes get and post to oidc logout without changing helper" do
    get_route = Rails.application.routes.recognize_path("https://#{@host}/oidc/logout", method: :get)
    post_route = Rails.application.routes.recognize_path("https://#{@host}/oidc/logout", method: :post)

    assert_equal "base/org/oidc/logouts", get_route[:controller]
    assert_equal "show", get_route[:action]
    assert_equal "base/org/oidc/logouts", post_route[:controller]
    assert_equal "create", post_route[:action]
    assert_equal "/oidc/logout", base_org_oidc_logout_path
  end

  test "get without params renders confirmation without mutation" do
    auth_refresh_token = @token.rotate_refresh_token!
    auth_refresh_digest = @token.reload.refresh_token_digest
    auth_refresh_generation = @token.refresh_token_generation
    cookies.delete(AuthenticationBase::ACCESS_COOKIE_KEY)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = auth_refresh_token

    get base_org_oidc_logout_url(host: @host), params: { ri: "jp" }, headers: session_headers

    assert_response :ok
    assert_not_predicate @token.reload, :revoked?
    assert_equal auth_refresh_digest, @token.refresh_token_digest
    assert_equal auth_refresh_generation, @token.refresh_token_generation
    assert_nil response.location
  end

  test "post without params does not rotate the authentication refresh token" do
    auth_refresh_token = @token.rotate_refresh_token!
    auth_refresh_digest = @token.reload.refresh_token_digest
    auth_refresh_generation = @token.refresh_token_generation
    cookies.delete(AuthenticationBase::ACCESS_COOKIE_KEY)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = auth_refresh_token

    post base_org_oidc_logout_url(host: @host), headers: session_headers

    assert_response :ok
    assert_equal auth_refresh_digest, @token.reload.refresh_token_digest
    assert_equal auth_refresh_generation, @token.refresh_token_generation
  end

  test "validated logout request is staged through shared confirmation" do
    redirect_uri = @client.post_logout_redirect_uris.first

    get base_org_oidc_logout_url(host: @host),
        params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, state: "xyz", ri: "jp" },
        headers: session_headers

    assert_response :see_other
    assert_equal "/sign/out/edit", URI.parse(jump_rt_url_from_location(response.location)).path

    follow_redirect!

    assert_response :ok

    post base_org_oidc_logout_url(host: @host), headers: session_headers

    assert_response :see_other
    assert_predicate @token.reload, :revoked?

    location = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal URI.parse(redirect_uri).host, location.host
    assert_equal URI.parse(redirect_uri).path, location.path
    assert_equal "xyz", query["state"]
  end

  test "invalid post_logout_redirect_uri never redirects externally" do
    post base_org_oidc_logout_url(host: @host),
         params: {
           id_token_hint: id_token,
           post_logout_redirect_uri: "https://attacker.example/signed-out",
           state: "xyz",
           ri: "jp",
         },
         headers: session_headers

    assert_response :success
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
    assert_not_includes response.body, "xyz"
  end

  test "post_logout_redirect_uri registered for another realm never redirects externally" do
    cross_realm_uri = OidcClientRegistry.find!("core-app").post_logout_redirect_uris.first

    assert_not_nil cross_realm_uri, "core-app should register an app-realm post_logout uri"

    post base_org_oidc_logout_url(host: @host),
         params: { id_token_hint: id_token, post_logout_redirect_uri: cross_realm_uri, state: "xyz", ri: "jp" },
         headers: session_headers

    assert_response :success
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
    assert_not_includes response.body, "xyz"
  end

  test "logout_challenge for an unknown transaction is rejected as not found" do
    get base_org_oidc_logout_url(host: @host),
        params: { logout_challenge: "does-not-exist", ri: "jp" },
        headers: session_headers

    assert_response :unprocessable_content
  end

  test "POST with a cross-origin challenge hands off to the sign surface for this realm" do
    transaction =
      AcmeLogoutTransactionCoordinator.issue!(
        origin_surface: "side",
        initiating_client_id: "side-org",
        completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
          origin_surface: "side", ri: "jp",
          surface: "org",
        ),
        surface: "org",
        ri: "jp",
      ).transaction
    AcmeLogoutTransactionCoordinator.advance!(logout_challenge: transaction.logout_challenge, step: "origin_cleared")

    post base_org_oidc_logout_url(host: @host, logout_challenge: transaction.logout_challenge, ri: "jp"),
         headers: session_headers.merge("Sec-Fetch-Site" => "same-origin")

    assert_response :success
    assert_equal "sign_cleared", transaction.reload.expected_step
    sign_host = ENV.fetch("PRIVATE_AUTH_STAFF_URL", "auth.org.localhost")
    handoff_uri = URI.parse(css_select("form#sign-out-handoff-form").first["action"])

    assert_equal sign_host, handoff_uri.host
    assert_equal "/sign/out", handoff_uri.path
  end

  test "cross-site coordinated logout is rejected without cleanup or transaction advancement" do
    transaction = AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: "core",
      initiating_client_id: "core-org",
      completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
        origin_surface: "core", ri: "jp", surface: "org",
      ),
      surface: "org",
      ri: "jp",
    ).transaction
    AcmeLogoutTransactionCoordinator.advance!(logout_challenge: transaction.logout_challenge, step: "origin_cleared")
    expected_step_before = transaction.reload.expected_step
    observed = { info: [], warn: [] }
    logger = Rails.logger

    logger.stub(:warn, ->(*args, &block) { observed[:warn] << (args.first || block&.call).to_s }) do
      logger.stub(:info, ->(*args, &block) { observed[:info] << (args.first || block&.call).to_s }) do
        post base_org_oidc_logout_url(host: @host, logout_challenge: transaction.logout_challenge, ri: "jp"),
             headers: session_headers.merge(
               "Sec-Fetch-Site" => "cross-site",
               "Origin" => "https://attacker.example",
             )
      end
    end

    assert_response :forbidden
    assert_not_predicate @token.reload, :revoked?
    assert_equal expected_step_before, transaction.reload.expected_step
    events = (observed[:info] + observed[:warn]).join("\n")

    assert_includes events, "auth.sign_out.fetch_metadata.rejected"
    assert_not_includes events, "auth.sign_out.fetch_metadata.accepted"
  end

  test "missing fetch metadata is rejected without cleanup or transaction advancement" do
    transaction = AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: "core",
      initiating_client_id: "core-org",
      completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
        origin_surface: "core", ri: "jp", surface: "org",
      ),
      surface: "org",
      ri: "jp",
    ).transaction
    AcmeLogoutTransactionCoordinator.advance!(logout_challenge: transaction.logout_challenge, step: "origin_cleared")
    expected_step_before = transaction.reload.expected_step

    post base_org_oidc_logout_url(host: @host, logout_challenge: transaction.logout_challenge, ri: "jp"),
         headers: session_headers.merge("Sec-Fetch-Site" => nil)

    assert_response :forbidden
    assert_not_predicate @token.reload, :revoked?
    assert_equal expected_step_before, transaction.reload.expected_step
  end

  test "untrusted origin is rejected without cleanup or transaction advancement" do
    transaction = AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: "core",
      initiating_client_id: "core-org",
      completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
        origin_surface: "core", ri: "jp", surface: "org",
      ),
      surface: "org",
      ri: "jp",
    ).transaction
    AcmeLogoutTransactionCoordinator.advance!(logout_challenge: transaction.logout_challenge, step: "origin_cleared")
    expected_step_before = transaction.reload.expected_step

    post base_org_oidc_logout_url(host: @host, logout_challenge: transaction.logout_challenge, ri: "jp"),
         headers: session_headers.merge(
           "Sec-Fetch-Site" => "same-origin",
           "Origin" => "https://attacker.example",
         )

    assert_response :forbidden
    assert_not_predicate @token.reload, :revoked?
    assert_equal expected_step_before, transaction.reload.expected_step
  end

  # D2: the coordinated-logout CSRF declaration used to replace the inherited check, so an ordinary
  # POST without logout_challenge ran no CSRF verification at all.
  test "D2 cross-site POST without logout_challenge or token does not end the staged session" do
    redirect_uri = @client.post_logout_redirect_uris.first

    with_forgery_protection do
      get base_org_oidc_logout_url(host: @host),
          params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, ri: "jp" },
          headers: session_headers.merge("Sec-Fetch-Site" => "same-origin")
      post base_org_oidc_logout_url(host: @host),
           headers: session_headers.except("X-CSRF-Token").merge("Sec-Fetch-Site" => "cross-site")
    end

    assert_not_predicate @token.reload, :revoked?
    assert_empty enqueued_jobs.select { |job| job["job_class"] == "OidcBackchannelLogoutDeliveryJob" }
  end

  test "D2 same-origin POST without logout_challenge still ends the staged session" do
    redirect_uri = @client.post_logout_redirect_uris.first

    with_forgery_protection do
      get base_org_oidc_logout_url(host: @host),
          params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, ri: "jp" },
          headers: session_headers.merge("Sec-Fetch-Site" => "same-origin")
      post base_org_oidc_logout_url(host: @host), headers: session_headers.merge("Sec-Fetch-Site" => "same-origin")
    end

    assert_response :see_other
    assert_predicate @token.reload, :revoked?
  end

  private

  # A real browser presents the access token as a cookie alongside the Rails session cookie. The
  # harness headers carry it as a raw Cookie header, which would replace the jar (and the staged
  # logout request in the session), so the harness-issued token is placed in the jar instead.
  def session_headers
    harness = as_staff_headers(@operator, host: @host, session_public_id: @session_public_id)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = harness.fetch("Cookie").split("=", 2).last
    browser_headers.merge(harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
  end

  def id_token(resource: @operator, subject: OidcSubject.for(@operator, resource_type: "operator"),
               sid: @session_public_id)
    OidcIdTokenIssuer.call(
      resource: resource,
      client: @client,
      nonce: "nonce",
      issuer: OidcIssuer.for_resource_type("operator"),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("operator"),
      subject: subject,
      sid: sid,
    )
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Base::Org::Oidc::LogoutsControllerTest
  private
end

# DAMP local helper copy on the test class.
class Base::Org::Oidc::LogoutsControllerTest
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
    %w(AUTH_APP AUTH_ORG AUTH_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
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

# DAMP: authenticated header helpers that attach a real JWT access cookie so the
# Base RP authentication pipeline recognizes the logged-in session instead of
# redirecting to /oauth/authorize. This final reopening overrides any earlier
# helper definitions in this file so every "logged in" request carries a valid
# access token cookie for the correct actor and surface.
class Base::Org::Oidc::LogoutsControllerTest
  private

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

  # Derive the issuer id from the test host. Base RP hosts (www.umaxica.app/.org/.com)
  # must resolve to surface:BASE_* so the access token issuer matches the surface the
  # controller validates against.
  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service =
      if normalized.include?("acme")
        "ACME"
      elsif normalized.include?("core")
        "CORE"
      elsif normalized.include?("auth") || normalized.include?("sign") || normalized.include?("log.umaxica")
        "AUTH"
      else
        "BASE"
      end
    surface =
      if service == "AUTH"
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

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)
    return base unless user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"

    ensure_user_token_reference_records!
    token = session_public_id.present? ? ClientToken.find_by(public_id: session_public_id) : nil
    token ||= ClientToken.where(user_id: user.id).where("discard_at > ?", Time.current).order(created_at: :desc).first
    token ||= ClientToken.create!(
      user_id: user.id,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    token_public_id = session_public_id.presence || token.public_id
    access_token = jwt_access_token_for(user, host: host, session_public_id: token_public_id, resource_type: "client")
    set_access_cookie(access_token)
    base["Cookie"] = [base["Cookie"], "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{access_token}"].compact.join("; ")
    base["X-TEST-SESSION-PUBLIC-ID"] = token_public_id
    base
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)
    return base unless staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"

    ensure_staff_token_reference_records!
    token = session_public_id.present? ? OperatorToken.find_by(public_id: session_public_id) : nil
    token ||= OperatorToken.where(staff_id: staff.id).where(
      "discard_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= OperatorToken.create!(
      staff_id: staff.id,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    token_public_id = session_public_id.presence || token.public_id
    access_token = jwt_access_token_for(
      staff, host: host, session_public_id: token_public_id,
             resource_type: "operator",
    )
    set_access_cookie(access_token)
    base["Cookie"] = [base["Cookie"], "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{access_token}"].compact.join("; ")
    base["X-TEST-SESSION-PUBLIC-ID"] = token_public_id
    base
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)
    return base unless visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"

    ensure_visitor_token_reference_records!
    token = session_public_id.present? ? VisitorToken.find_by(public_id: session_public_id) : nil
    token ||= VisitorToken.where(visitor_id: visitor.id).where(
      "discard_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= VisitorToken.create!(
      visitor_id: visitor.id,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    token_public_id = session_public_id.presence || token.public_id
    access_token = jwt_access_token_for(
      visitor, host: host, session_public_id: token_public_id,
               resource_type: "visitor",
    )
    set_access_cookie(access_token)
    base["Cookie"] = [base["Cookie"], "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{access_token}"].compact.join("; ")
    base["X-TEST-SESSION-PUBLIC-ID"] = token_public_id
    base
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::VerificationCancellationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :client_tokens, :operator_tokens, :client_statuses, :operator_passkeys

  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  test "app cancellation sends the exact cancellation handoff to the OP authorize endpoint" do
    actor = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    email = actor.client_emails.create!(
      address: "cancellation-step-up-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    client = OidcClientRegistry.find!("core-app-jp")
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "client")
    oidc_issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "app", actor:, token:, client:, params:, validated_request:,
    )
    entry_ref = oidc_issuance.entry_ref
    transaction = oidc_issuance.ticket
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    binding = attach_auth_ceremony_entry!(
      auth_app_verification_path, reference: entry_ref, params: { ri: "jp" },
    )
    binding.confirm_base!(
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref:, nonce: oidc_issuance.authorization_transaction.login_challenge,
      ),
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    get auth_app_verification_path(ri: "jp", entry_ref: entry_ref), headers: NAVIGATION_HEADERS

    assert_response :see_other

    post auth_app_verification_cancellation_path(ri: "jp")

    assert_response :see_other
    destination = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(destination.query)

    expected_endpoint = URI.parse(OidcIssuer.authorization_endpoint("client"))

    assert_equal expected_endpoint.host, destination.host
    assert_equal expected_endpoint.path, destination.path
    assert_equal transaction.transaction_id, query.fetch("step_up_ticket_ref")
    assert_equal oidc_issuance.context.public_id, query.fetch("step_up_context_ref")
    assert_predicate query.fetch("step_up_cancellation_ref"), :present?
    assert_not query.key?("cancellation_handoff")
    assert_not_includes response.location, "jump.umaxica.net"
    assert_not_includes response.location, "/sign"
    assert_equal "pending", transaction.reload.status
    assert_nil transaction.canceled_at
    assert_nil token.reload.last_step_up_at
    assert_predicate token, :currently_usable?
    assert_equal 1,
                 ClientStepUpCeremonyTransaction.where(session_ref: token.public_id, status: %w(pending verified)).count
  end

  test "org cancellation sends the exact cancellation handoff to the OP authorize endpoint" do
    actor = operators(:one)
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor, root_login_established_at: Time.current)
    client = OidcClientRegistry.find!("core-org-jp")
    now = OpBaseOrgRecord.database_now
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch, operator_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "operator")
    oidc_issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "org", actor:, token:, client:, params:, validated_request:,
    )
    entry_ref = oidc_issuance.entry_ref
    transaction = oidc_issuance.ticket
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    https!
    binding = attach_auth_ceremony_entry!(
      auth_org_verification_path, reference: entry_ref, params: { ri: "jp" },
    )
    binding.confirm_base!(
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "org", entry_ref:, nonce: oidc_issuance.authorization_transaction.login_challenge,
      ),
    )
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    https!
    get auth_org_verification_path(ri: "jp", entry_ref: entry_ref), headers: NAVIGATION_HEADERS

    assert_response :see_other

    post auth_org_verification_cancellation_path(ri: "jp")

    assert_response :see_other
    destination = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(destination.query)

    expected_endpoint = URI.parse(OidcIssuer.authorization_endpoint("operator"))

    assert_equal expected_endpoint.host, destination.host
    assert_equal expected_endpoint.path, destination.path
    assert_equal transaction.transaction_id, query.fetch("step_up_ticket_ref")
    assert_equal oidc_issuance.context.public_id, query.fetch("step_up_context_ref")
    assert_predicate query.fetch("step_up_cancellation_ref"), :present?
    assert_not query.key?("cancellation_handoff")
    assert_not_includes response.location, "jump.umaxica.net"
    assert_not_includes response.location, "/sign"
    assert_equal "pending", transaction.reload.status
    assert_nil transaction.canceled_at
    assert_nil token.reload.last_step_up_at
    assert_predicate token, :currently_usable?
    assert_equal 1,
                 OperatorStepUpCeremonyTransaction.where(
                   session_ref: token.public_id,
                   status: %w(
                     pending verified
                   ),
                 ).count
  end

  # The destination is fixed by the server-held ceremony origin: neither a posted return_to nor the
  # Referer can steer it.
  test "app cancellation ignores a posted return_to and the referer" do
    [
      "https://evil.example/steal", "//evil.example/steal", "/identity/emails", "", "/identity\x00/emails",
    ].each do |posted_return_to|
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(authentication_epoch: 0, user: actor)
      email = actor.client_emails.create!(
        address: "cancellation-step-up-#{SecureRandom.hex(4)}@example.com",
        user_email_status_id: ClientEmailStatus::VERIFIED,
      )
      email.finalize_binding!
      client = OidcClientRegistry.find!("core-app-jp")
      now = OpBaseAppRecord.database_now
      grant = OpAppGrant.create!(
        authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
        oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
        oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
      )
      grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
      params = {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        scope: grant.oidc_scope,
        state: SecureRandom.urlsafe_base64(32),
        nonce: SecureRandom.urlsafe_base64(32),
        code_challenge: "a" * 43,
        code_challenge_method: "S256",
        prompt: "login",
        claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
      }
      validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "client")
      oidc_issuance = OidcStepUpAuthorizationIssuer.call!(
        surface: "app", actor:, token:, client:, params:, validated_request:,
      )
      entry_ref = oidc_issuance.entry_ref
      transaction = oidc_issuance.ticket
      host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      https!
      binding = attach_auth_ceremony_entry!(
        auth_app_verification_path, reference: entry_ref, params: { ri: "jp" },
      )
      binding.confirm_base!(
        base_token: token,
        browser_digest: AuthAdmissionBinding.browser_digest(
          surface: "app", entry_ref:, nonce: oidc_issuance.authorization_transaction.login_challenge,
        ),
      )
      host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      https!
      get auth_app_verification_path(ri: "jp", entry_ref: entry_ref), headers: NAVIGATION_HEADERS

      assert_response :see_other
      post auth_app_verification_cancellation_path(ri: "jp"),
           params: { return_to: posted_return_to, pt: posted_return_to },
           headers: { "Referer" => "https://evil.example/referer" }

      assert_response :see_other
      destination = URI.parse(response.location)
      query = Rack::Utils.parse_nested_query(destination.query)

      expected_endpoint = URI.parse(OidcIssuer.authorization_endpoint("client"))

      assert_equal expected_endpoint.host, destination.host, posted_return_to
      assert_equal expected_endpoint.path, destination.path, posted_return_to
      assert_equal transaction.transaction_id, query.fetch("step_up_ticket_ref"), posted_return_to
      assert_equal oidc_issuance.context.public_id, query.fetch("step_up_context_ref"), posted_return_to
      assert_predicate query.fetch("step_up_cancellation_ref"), :present?, posted_return_to
      assert_not query.key?("cancellation_handoff"), posted_return_to
      assert_not_includes response.location, "jump.umaxica.net", posted_return_to
      assert_not_includes response.location, "/sign", posted_return_to
    end
  end

  # Sentinels for the ceremony context: no cookie at all, and a cookie that names no ceremony.
  test "cancellation without an admitted ceremony is refused on every surface and changes nothing" do
    [
      ["PUBLIC_AUTH_SERVICE_URL", auth_app_verification_cancellation_path(ri: "jp")],
      ["PUBLIC_AUTH_STAFF_URL", auth_org_verification_cancellation_path(ri: "jp")],
    ].each do |host_key, path|
      host! ENV.fetch(host_key)
      post path

      assert_response :bad_request, host_key
      assert_equal I18n.t("errors.messages.invalid_request"), response.body
      assert_nil response.headers["Location"]

      cookies["auth_sid"] = "not-a-ceremony"
      post path

      assert_response :bad_request, host_key
      assert_nil response.headers["Location"]
    end
  end

  test "step-up cancellation is not reachable by GET" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}/verification/cancellation",
        method: :get,
      )
    end
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Auth::VerificationCancellationsControllerTest
  private
end

# DAMP local helper copy for former shared test support.
class Auth::VerificationCancellationsControllerTest
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
class Auth::VerificationCancellationsControllerTest
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

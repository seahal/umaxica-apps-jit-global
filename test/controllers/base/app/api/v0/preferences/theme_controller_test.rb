# typed: false
# frozen_string_literal: true

require "openssl"

require "test_helper"
# require "helpers/global_test_support"

class Base::App::Api::V0::Preferences::ThemeControllerTest < ActionDispatch::IntegrationTest
  # include PreferenceJwtHelper

  setup do
    _ = PreferenceBase # ensure autoload of JwtConfiguration/Token defined in same file
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    https!
  end

  test "GET show without a Preference JWT returns default theme sy" do
    cookies.delete(PreferenceCookieName.anonymous_jwt)

    get base_app_api_v0_preferences_theme_path, as: :json

    assert_response :ok
    assert_equal "sy", response.parsed_body["theme"]
  end

  test "GET show returns theme from preference jwt" do
    token = encode_preference_jwt(
      preferences: { "theme" => "dark" },
      host: @host,
      public_id: PublicId.generate,
    )
    cookies[PreferenceCookieName.anonymous_jwt] = token

    with_preference_realm_issuers do
      get base_app_api_v0_preferences_theme_path, as: :json

      assert_response :success
    end

    assert_response :ok
    assert_equal "dr", response.parsed_body["theme"]
  end

  test "GET show ignores a JavaScript theme cookie as canonical input" do
    cookies[PreferenceCookieName.anonymous_experience] = "{\"theme\":\"light\"}"

    get base_app_api_v0_preferences_theme_path, as: :json

    assert_response :ok
    assert_equal "sy", response.parsed_body["theme"]
  end

  test "PATCH update sets theme cookie and returns updated theme" do
    token = encode_preference_jwt(
      preferences: { "theme" => "system" },
      host: @host,
      public_id: PublicId.generate,
    )
    cookies[PreferenceCookieName.anonymous_jwt] = token

    with_preference_realm_issuers do
      patch base_app_api_v0_preferences_theme_path, params: { theme: "dark" }, as: :json
    end

    assert_response :ok
    assert_equal "dr", response.parsed_body["theme"]
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "#{PreferenceCookieName.anonymous_experience}="
    assert_includes set_cookie, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "PATCH update does not issue an authentication cookie with a Preference JWT" do
    token = encode_preference_jwt(
      preferences: { "theme" => "system" },
      host: @host,
      public_id: PublicId.generate,
    )
    cookies[PreferenceCookieName.anonymous_jwt] = token

    with_preference_realm_issuers do
      patch base_app_api_v0_preferences_theme_path, params: { theme: "dark" }, as: :json
    end

    assert_response :ok

    assert_predicate cookies[PreferenceCookieName.anonymous_jwt], :present?
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
  end

  # A signed-in actor who has never had a preference row gets one created on the first
  # write, together with the child records every preference type expects.
  test "PATCH update creates the actor preference record on a signed-in first write" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    root_token = ClientToken.create!(
      authentication_epoch: 0, user: client,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    BaseSelectorAuthority.prepare(surface: :app, principal: client, session: root_token)

    cell = RpCellBinding.for_client("base-app-ww")
    prior_runtime_role = ENV["UMAXICA_RUNTIME_ROLE"]
    prior_browser_admission = ENV["UMAXICA_RP_BROWSER_ADMISSION"]
    prior_forgery_protection = ActionController::Base.allow_forgery_protection
    ENV["UMAXICA_RUNTIME_ROLE"] = "#{cell.connection.tr("_", "-")}-#{cell.region}"
    ENV["UMAXICA_RP_BROWSER_ADMISSION"] = "open"
    ActionController::Base.allow_forgery_protection = true
    OidcOpJwksClient::CLIENTS.clear

    begin
      browser_client = OidcClientRegistry.find!("base-app-ww")
      verifier = SecureRandom.urlsafe_base64(48)
      authorization_params = {
        client_id: browser_client.client_id,
        redirect_uri: browser_client.redirect_uris.first,
        response_type: "code",
        scope: "openid",
        state: SecureRandom.hex(16),
        nonce: SecureRandom.hex(16),
        code_challenge_method: "S256",
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
      }
      code = OidcAuthorizationCodeIssuer.call(
        client: browser_client, params: authorization_params, resource: client,
        session_token: root_token, authentication_event_at: 1.minute.ago,
      )
      resource_type = OidcIssuer.resource_type_for_client(browser_client)
      token_exchange =
        OidcClientRegistry.stub(:authenticate_assertion, ->(*, **) { true }) do
          OidcTokenExchangeCoordinator.call(
            grant_type: "authorization_code", code: code.code, redirect_uri: code.redirect_uri,
            client_id: browser_client.client_id,
            client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
            client_assertion: "controller-test-assertion",
            token_endpoint_uri: OidcIssuer.token_endpoint(resource_type), code_verifier: verifier,
            expected_resource_type: resource_type,
          )
        end

      assert_predicate token_exchange, :success?

      token_response = token_exchange.token_response
      id_payload, = JWT.decode(token_response.fetch(:id_token), nil, false)
      enrollment = RpCallbackCommitter.call(
        cell: cell, issuer: id_payload.fetch("iss"), subject: id_payload.fetch("sub"), sid: id_payload.fetch("sid"),
        absolute_expires_at: 1.hour.from_now,
      )

      assert_predicate enrollment, :success?, enrollment.outcome.to_s
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = token_response.fetch(:access_token)
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = token_response.fetch(:refresh_token)
      cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id

      get(edit_base_app_sign_out_path(ri: "jp"))

      assert_response :success

      csrf_token = response.parsed_body.at_css('meta[name="csrf-token"]')&.[]("content") ||
        response.body[/name="authenticity_token" value="([^"]+)"/, 1]

      assert_predicate csrf_token, :present?, response.body[0, 500]

      assert_difference -> { ClientPreference.where(client_id: client.id).count }, 1 do
        patch(
          base_app_api_v0_preferences_theme_path,
          params: { theme: "dark" }.to_json,
          headers: {
            "Accept" => "application/json",
            "Content-Type" => "application/json",
            "Origin" => "https://#{@host}",
            "Sec-Fetch-Site" => "same-origin",
            "X-CSRF-Token" => csrf_token,
          },
        )
      end

      assert_response :ok
    ensure
      OidcOpJwksClient::CLIENTS.clear
      prior_runtime_role.nil? ? ENV.delete("UMAXICA_RUNTIME_ROLE") : ENV["UMAXICA_RUNTIME_ROLE"] = prior_runtime_role
      prior_browser_admission.nil? ? ENV.delete("UMAXICA_RP_BROWSER_ADMISSION") :
        ENV["UMAXICA_RP_BROWSER_ADMISSION"] = prior_browser_admission
      ActionController::Base.allow_forgery_protection = prior_forgery_protection
    end

    actor_preference = ClientPreference.find_by!(client_id: client.id)
    option_class = PreferenceClassRegistry.option_class("Client", :theme)

    assert_equal option_class::DARK,
                 PreferenceClassRegistry.record_class("Client", :theme).find_by!(
                   preference_id: actor_preference.id,
                 ).option_id
  end

  private

  def encode_preference_jwt(preferences:, host:, public_id:, preference_type: "AppPreference")
    jti = AppPreference.find_by(public_id:)&.jti || "test-jti-#{SecureRandom.uuid}"
    defaults = {
      "theme" => "system",
      "language" => "ja",
      "timezone" => "Asia/Tokyo",
      "currency" => "jpy",
      "date_format" => "iso",
      "time_format" => "24",
      "motion" => "standard",
      "density" => "standard",
      "page_size" => "infinity",
    }
    token = nil

    with_preference_realm_issuers do
      token = PreferenceToken.encode(
        defaults.merge(preferences),
        host: host,
        preference_type: preference_type,
        public_id: public_id,
        jti: jti,
        issued_at: Time.current,
      )
    end

    token
  end
end

# DAMP local helper copy on the test class.
class Base::App::Api::V0::Preferences::ThemeControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )

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

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
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
    %w(AUTH_APP AUTH_ORG ACME_APP ACME_ORG CORE_APP CORE_ORG BASE_APP BASE_ORG).each do |namespace|
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

  def fetch_csrf_token(path)
    with_forgery_protection do
      get(path)
      csrf_token = response.body[/<meta name="csrf-token" content="([^"]+)"/, 1] ||
        response.body[/name="authenticity_token" value="([^"]+)"/, 1]

      assert_predicate csrf_token, :present?, "expected a CSRF token in the response"
      csrf_token
    end
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

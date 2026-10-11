# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ComSocialLoginBlockedTest < ActionDispatch::IntegrationTest
  setup do
    @corporate_host = ENV.fetch("PRIVATE_AUTH_CORPORATE_URL")
    @service_host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
  end

  test "POST /social/google on corporate host returns 404" do
    host! @corporate_host
    post "/social/google"

    assert_response :not_found
  end

  test "POST /social for org Google provider on corporate host returns 404" do
    host! @corporate_host
    post "/social/google_#{"org"}"

    assert_response :not_found
  end

  test "POST /social/apple on corporate host returns 404" do
    host! @corporate_host
    post "/social/apple"

    assert_response :not_found
  end

  test "POST /social/google on service host does not return 404" do
    host! @service_host
    post "/social/google"
    # It should redirect to OmniAuth or fail CSRF, but NOT 404 from our guard
    assert_not_equal 404, response.status
  end

  test "corporate sign-in page does not contain social login buttons" do
    host! @corporate_host
    begin
      fv5064 = "/sign/in"
      fv5063 = login_challenge_for("com")
      fv5062 = :entry_ref
      fv5061 = { ri: "jp" }
      fv5060 = {}
      fv5059 = false
      fv5058 = nil
      fv5057 = nil
      begin
        fv5005 = self
        fv5012 = fv5064
        fv5055 = fv5063
        fv5056 = fv5062
        fv5021 = fv5061
        fv5014 = fv5060
        fv5043 = fv5059
        fv5042 = fv5058
        fv5017 = fv5057
        fv5011 = fv5021.merge(fv5056 => fv5055)
        fv5005.get(fv5012, params: fv5011, headers: fv5014)
        fv5049 =
          begin
            fv5054 = fv5005.response.body
            fv5053 = true
            fv5052 = Nokogiri::HTML(fv5054).at_css("form")
            if fv5052.nil? && fv5053
              nil
            else
              raise RuntimeError, "Auth continuation form is missing" unless fv5052

              fv5051 = fv5052.at_css("input[name='authenticity_token']")&.[]("value")
              raise RuntimeError,
                    "Auth continuation is missing its CSRF token" if fv5051.blank?

              fv5050 = fv5052.css("input[type='hidden']").to_h do |input|
                [input["name"], input["value"]]
              end.except("authenticity_token")
              [fv5052["action"], fv5051, fv5050]
            end
          end
        if fv5049

          fv5048, fv5046, fv5047 = fv5049

          fv5005.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
            "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
          fv5005.post(fv5048, params: fv5047.merge(authenticity_token: fv5046), headers: fv5014)
          fv5045 = fv5005.response.location
          if fv5045.present?

            fv5041 = URI.parse(fv5045)
            fv5040 = fv5041.host
            fv5016 =
              begin
                fv5044 = fv5040
                {
                  ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                  ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                  ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                }.fetch(fv5044)
              end
            fv5015 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
              surface: fv5016, reference: fv5041.path.split("/").fetch(-2),
            )

            if fv5043
              fv5023 = fv5042 || fv5005
              fv5023.host!(fv5040)
              fv5023.https!
              fv5023.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5039 = fv5041.request_uri
              fv5030 = fv5014.merge(
                "Host" => fv5040,
                "Origin" => "https://#{fv5040}",
                "Sec-Fetch-Site" => "same-origin",
              )
              fv5023.get(fv5039, headers: fv5030)
              fv5033, fv5031, fv5032 =
                begin
                  fv5038 = fv5023.response.body
                  fv5037 = false
                  fv5036 = Nokogiri::HTML(fv5038).at_css("form")
                  if fv5036.nil? && fv5037
                    nil
                  else
                    raise RuntimeError, "Auth continuation form is missing" unless fv5036

                    fv5035 = fv5036.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5035.blank?

                    fv5034 = fv5036.css("input[type='hidden']").to_h do |input|
                      [input["name"], input["value"]]
                    end.except("authenticity_token")
                    [fv5036["action"], fv5035, fv5034]
                  end
                end
              fv5023.post(
                fv5033,
                params: fv5032.merge(authenticity_token: fv5031),
                headers: fv5030,
              )
              begin
                fv5024 = fv5023
                fv5026 = "session"
                fv5025 = fv5024.response.cookies[fv5026]
                if fv5025.nil?
                  fv5029 = fv5024.response.headers["Set-Cookie"] || fv5024.response.headers["set-cookie"]
                  fv5028 =
                    if fv5029.is_a?(String) && fv5029.start_with?("[")
                      JSON.parse(fv5029)
                    else
                      Array(fv5029)
                    end
                  fv5027 =
                    fv5028.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                      entry.split(";", 2).first.to_s.start_with?("#{fv5026}=")
                    end
                  if fv5027

                    _, fv5025 = fv5027.split(";", 2).first.to_s.split("=", 2)
                    fv5025 = Rack::Utils.unescape(fv5025.to_s)
                  end
                end

                unless fv5025.nil?
                  fv5024.cookies.delete(fv5026)
                  # Rack::Test's []= uses its default host. The current request may target a
                  # different surface, so install the cookie against the browser's active host.
                  fv5024.cookies.merge(
                    "#{fv5026}=#{Rack::Utils.escape(fv5025)}",
                    URI.parse("https://#{fv5024.host}/"),
                  )
                end
              end
              fv5022 = fv5023.response.location
              raise RuntimeError, "Base confirmation did not return to Auth" if fv5022.blank?

              fv5019 = URI.parse(fv5022)
              if fv5021[:ri].present?
                fv5020 = Rack::Utils.parse_nested_query(fv5019.query.to_s)
                fv5020["ri"] ||= fv5021[:ri].to_s
                fv5019.query = URI.encode_www_form(fv5020)
              end
              fv5005.host!(fv5019.host)
              fv5005.https!
              fv5018 = fv5019.request_uri
              fv5001 = fv5014.merge("Host" => fv5019.host)
              fv5005.get(fv5018, headers: fv5001)
            else
              fv5015.confirm_base!(
                base_token: fv5017,
                browser_digest: AuthAdmissionBinding.browser_digest(
                  surface: fv5016,
                  entry_ref: fv5015.entry_ref,
                  nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                ),
              )
              fv5013 = fv5005.host
              fv5005.host!(fv5013)
              fv5005.https!
              fv5001 = fv5014.merge("Host" => fv5013)
              fv5005.get(fv5012, params: fv5011, headers: fv5001)
            end
            fv5004, fv5002, fv5003 =
              begin
                fv5010 = fv5005.response.body
                fv5009 = false
                fv5008 = Nokogiri::HTML(fv5010).at_css("form")
                if fv5008.nil? && fv5009
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5008

                  fv5007 = fv5008.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5007.blank?

                  fv5006 = fv5008.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5008["action"], fv5007, fv5006]
                end
              end
            fv5005.post(
              fv5004,
              params: fv5003.merge(authenticity_token: fv5002),
              headers: fv5001,
            )
          end
        end
      end
    end

    assert_response :see_other
    follow_redirect!

    assert_response :success
    assert_not_includes response.body, "/auth/google_app"
    assert_not_includes response.body, "/auth/google_#{"org"}"
    assert_not_includes response.body, "/auth/google_#{"com"}"
    assert_not_includes response.body, "/auth/apple"
    assert_not_includes response.body, "/social/google"
    assert_not_includes response.body, "/social/apple"
    # Check for i18n keys absence if they were social-specific
    assert_not_includes response.body, "Googleで続行" if I18n.locale == :ja
  end

  test "corporate Google provider request is blocked" do
    host! @corporate_host

    post "/auth/google_#{"com"}"

    assert_response :not_found
  end

  test "corporate guard does not open app google when legacy COM flag is on" do
    host! @corporate_host
    with_env("COM_#{"GOOGLE"}_SIGNUP_ENABLED" => "true", "COM_#{"GOOGLE"}_SIGNIN_ENABLED" => "false") do
      post "/social/google", headers: social_callback_headers(@corporate_host)
    end

    assert_response :not_found
  end

  private

  def login_challenge_for(surface)
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: surface,
      intent: "sign_in",
      params: {
        response_type: "code",
        client_id: "core-com",
        redirect_uri: OidcClientRegistry.find!("core-com").redirect_uris.first,
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: nil,
    ).reference
  end

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end

# DAMP local helper copy for former shared test support.
class ComSocialLoginBlockedTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
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

  def insert_verified_visitor_email!(visitor_id:, address:)
    VisitorEmail.insert_all(
      [
        {
          visitor_id: visitor_id,
          address: address,
          address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :com),
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
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
      user_headers =
        as_user_headers(user, host: host)
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
class ComSocialLoginBlockedTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

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

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address, realm: :com),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
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

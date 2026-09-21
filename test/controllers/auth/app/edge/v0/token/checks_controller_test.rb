# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
# require "helpers/auth_helpers"

class Auth::App::Edge::V0::Token::ChecksControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @user = clients(:one)
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    host! @host
    ClientToken.where(user: @user).delete_all
  end

  test "GET check with valid JWT access token returns 200" do
    # Create a token record and generate tokens
    token_record = ClientToken.create!(user: @user)
    token_record.rotate_refresh_token!

    # Generate a valid JWT access token
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
    )

    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :ok
    json = response.parsed_body

    assert json["authenticated"], "Client should be authenticated"
    assert_equal "client", json["type"]
    assert_equal @user.id, json["id"]
    assert_equal token_record.device_session.public_id, json["sid"]
  end

  # DBSC registration is offered to authenticated sessions that are not yet device-bound. This is
  # the response the `script/dbsc_probe` registration check targets, and the header Chromium reads
  # to start a DBSC session. A non-DBSC token must therefore receive `Secure-Session-Registration`
  # (and its legacy `Sec-Session-Registration` alias) pointing at the DBSC refresh endpoint.
  test "GET check offers Secure-Session-Registration to a non-DBSC-bound session" do
    token_record = ClientToken.create!(user: @user)
    token_record.rotate_refresh_token!

    assert_not token_record.binding_method_dbsc?,
               "fresh token must not be DBSC-bound for this registration-offer assertion"

    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
    )

    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :ok

    registration = response.headers[AuthIoKeys::Headers::SECURE_DBSC_REGISTRATION]
    legacy_registration = response.headers[AuthIoKeys::Headers::DBSC_REGISTRATION]

    assert_predicate registration, :present?, "expected Secure-Session-Registration on check response"
    assert_equal registration, legacy_registration
    assert_includes registration, "(ES256 RS256);"
    assert_includes registration, %(path="#{auth_app_edge_v0_token_dbsc_path}")
    assert_includes registration, "challenge="
  end

  # The advertised path is the DBSC proof audience, so it must be identical across registration
  # and refresh. Per-request context params (ri/lx/tz) merged into generated URLs must not leak
  # into it, or a later region switch would break the bound-session refresh.
  test "GET check with context params still advertises the canonical DBSC path" do
    token_record = ClientToken.create!(user: @user)
    token_record.rotate_refresh_token!
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
    )

    get "/edge/v0/token/check?ri=us&lx=en&tz=UTC",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :ok
    registration = response.headers[AuthIoKeys::Headers::SECURE_DBSC_REGISTRATION]

    assert_includes registration, %(path="#{auth_app_edge_v0_token_dbsc_path}")
    assert_no_match(/path="[^"]*[?#]/, registration)
  end

  test "GET check without access token returns 401" do
    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_not json["authenticated"]
    assert_equal({ "authenticated" => false }, json)
  end

  test "GET check with invalid JWT returns 401" do
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = "invalid.jwt.token"

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_not json["authenticated"]
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
  end

  test "GET check with expired JWT returns 401" do
    # Create a token record
    token_record = ClientToken.create!(user: @user)
    token_record.rotate_refresh_token!

    # Generate a JWT that's already expired
    # We need to manipulate time to create an expired token
    expired_token = nil
    travel_to(2.hours.ago) do
      expired_token = jwt_access_token_for(
        @user,
        host: @host,
        session_public_id: token_record.public_id,
        resource_type: "client",
      )
    end

    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = expired_token

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_not json["authenticated"]
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
  end

  test "GET check with wrong resource type returns 401" do
    # Create a token record
    token_record = ClientToken.create!(user: @user)
    token_record.rotate_refresh_token!

    # Generate a JWT with wrong resource type (operator instead of user)
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "operator", # wrong type for user endpoint
    )

    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_not json["authenticated"]
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
  end

  test "GET check includes Cache-Control no-store header" do
    token_record = ClientToken.create!(user: @user)
    access_token = jwt_access_token_for(
      @user, host: @host, session_public_id: token_record.public_id,
             resource_type: "client",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :success

    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "GET check with Bearer header takes precedence over cookie" do
    # Create a token record and generate tokens
    token_record = ClientToken.create!(user: @user)
    token_record.rotate_refresh_token!

    # Generate a valid JWT access token
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
    )

    # Set invalid cookie but valid Bearer header
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = "invalid.cookie.token"

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "Bearer #{access_token}",
        },
        as: :json

    assert_response :ok
    json = response.parsed_body

    assert json["authenticated"], "Bearer token should take precedence"
    assert_equal "client", json["type"]
    assert_equal @user.id, json["id"]
    assert_equal token_record.device_session.public_id, json["sid"]
  end

  test "GET check accepts DPoP-bound token with valid proof" do
    token_record = ClientToken.create!(user: @user)
    private_key, jwk = generate_dpop_jwk
    jkt = JitSecurityJwtThumbprintCalculator.calculate(jwk)
    token_record.update!(dpop_jkt: jkt)
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
      dpop_jkt: jkt,
    )
    proof = build_dpop_proof(
      private_key, jwk, method: "GET", uri: "http://#{@host}/edge/v0/token/check",
                        access_token: access_token,
    )

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "DPoP #{access_token}",
          "DPoP" => proof,
        },
        as: :json

    assert_response :ok
    assert response.parsed_body["authenticated"]
    assert_equal token_record.device_session.public_id, response.parsed_body["sid"]
  end

  test "GET check rejects DPoP-bound token presented as Bearer" do
    token_record = ClientToken.create!(user: @user)
    private_key, jwk = generate_dpop_jwk
    jkt = JitSecurityJwtThumbprintCalculator.calculate(jwk)
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
      dpop_jkt: jkt,
    )
    proof = build_dpop_proof(
      private_key, jwk, method: "GET", uri: "http://#{@host}/edge/v0/token/check",
                        access_token: access_token,
    )

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "Bearer #{access_token}",
          "DPoP" => proof,
        },
        as: :json

    assert_response :unauthorized
    assert_predicate response.headers["DPoP-Nonce"], :present?
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
  end

  test "GET check rejects DPoP-bound token without proof" do
    token_record = ClientToken.create!(user: @user)
    _private_key, jwk = generate_dpop_jwk
    jkt = JitSecurityJwtThumbprintCalculator.calculate(jwk)
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
      dpop_jkt: jkt,
    )

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "DPoP #{access_token}",
        },
        as: :json

    assert_response :unauthorized
    assert_predicate response.headers["DPoP-Nonce"], :present?
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
  end

  test "GET check rejects DPoP proof with wrong ath" do
    token_record = ClientToken.create!(user: @user)
    private_key, jwk = generate_dpop_jwk
    jkt = JitSecurityJwtThumbprintCalculator.calculate(jwk)
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
      dpop_jkt: jkt,
    )
    proof = build_dpop_proof(
      private_key, jwk, method: "GET", uri: "http://#{@host}/edge/v0/token/check",
                        access_token: "different-token",
    )

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "DPoP #{access_token}",
          "DPoP" => proof,
        },
        as: :json

    assert_response :unauthorized
    assert_predicate response.headers["DPoP-Nonce"], :present?
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
  end

  test "GET check rejects when access token cnf jkt differs from stored token JKT" do
    token_record = ClientToken.create!(user: @user)
    _stored_key, stored_jwk = generate_dpop_jwk
    proof_key, proof_jwk = generate_dpop_jwk
    stored_jkt = JitSecurityJwtThumbprintCalculator.calculate(stored_jwk)
    proof_jkt = JitSecurityJwtThumbprintCalculator.calculate(proof_jwk)
    token_record.update!(dpop_jkt: stored_jkt)
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
      dpop_jkt: proof_jkt,
    )
    proof = build_dpop_proof(
      proof_key, proof_jwk, method: "GET", uri: "http://#{@host}/edge/v0/token/check",
                            access_token: access_token,
    )

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "DPoP #{access_token}",
          "DPoP" => proof,
        },
        as: :json

    assert_response :unauthorized
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
  end

  test "GET check with missing sid returns 401" do
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: nil,
      resource_type: "client",
    )

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "Bearer #{access_token}",
        },
        as: :json

    assert_response :unauthorized
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
  end

  test "logout destroys token record so old Bearer access fails" do
    token_record = ClientToken.create!(user: @user)
    refresh_plain = token_record.rotate_refresh_token!
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
    )

    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = refresh_plain

    # Verify token exists before logout
    assert_not_nil ClientToken.find_by(public_id: token_record.public_id)

    # Simulate logout by destroying the token directly (the cookie-based destroy
    # requires domain matching which is complex in integration tests)
    token_record.destroy!

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "Bearer #{access_token}",
        },
        as: :json

    assert_response :unauthorized
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
  end

  private

  def generate_dpop_jwk
    ec = OpenSSL::PKey::EC.generate("prime256v1")
    jwk = JWT::JWK.new(ec).export
    [ec, jwk]
  end

  def build_dpop_proof(private_key, jwk, method:, uri:, access_token:)
    payload = {
      "htm" => method,
      "htu" => uri,
      "iat" => Time.current.to_i,
      "jti" => SecureRandom.uuid,
      "ath" => JitSecurityJwtThumbprintCalculator.ath(access_token),
    }
    JWT.encode(payload, private_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })
  end
end

# DAMP local helper copy for former shared test support.
class Auth::App::Edge::V0::Token::ChecksControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

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

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
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
class Auth::App::Edge::V0::Token::ChecksControllerTest
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
    token ||= ClientToken.where(user_id: user.id).where("discard_at > ?", Time.current).order(created_at: :desc).first
    token ||= ClientToken.create!(
      user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
      }",
      )
    else
      base
    end
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
      staff_id: staff.id, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }",
      )
    else
      base
    end
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
      visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor")
      }",
      )
    else
      base
    end
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

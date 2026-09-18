# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "minitest/mock"
require "base64"
require "support/webauthn_fake_client_helper"

module Auth::App::In
  class PasskeysControllerTest < ActionDispatch::IntegrationTest
    include WebauthnFakeClientHelper

    fixtures :clients, :client_statuses, :client_email_statuses, :client_telephone_statuses

    setup do
      host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
      TurnstileVerifierStub.challenge_enabled = true
      TurnstileVerifierStub.challenge_response = { "success" => true }
      TurnstileVerifierStub.enabled = true
      TurnstileVerifierStub.response = { "success" => true }
      @user = create_verified_user_with_email(email_address: "passkey_test_user_#{SecureRandom.hex(6)}@example.com")
      @user_email = @user.client_emails.first # Use the email created by the helper

      @user_telephone = ClientTelephone.create!(
        user: @user,
        number: "+819012345678",
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
      ) unless ClientTelephone.find_by(user: @user)

      # Real-crypto passkey for login: registered via the gem's FakeClient so
      # verification exercises the actual signature/RP ID/origin/UV path.
      @fake_client = webauthn_fake_client
      @passkey = register_fake_client_passkey!(client: @fake_client, user: @user, description: "Login Key")
    end

    teardown do
      TurnstileVerifierStub.challenge_enabled = false
      TurnstileVerifierStub.challenge_response = nil
      TurnstileVerifierStub.enabled = false
      TurnstileVerifierStub.response = nil
    end
    test "should get new" do
      get new_auth_app_sign_in_passkey_path(ri: "jp")

      assert_response :success
      assert_equal "auth/app/sign/in/passkeys/new", inertia_component

      panel = inertia_props.fetch("panel")

      assert_equal auth_app_sign_in_passkey_options_path(ri: "jp"), panel.fetch("options_url")
      assert_equal auth_app_sign_in_passkey_verification_path(ri: "jp"), panel.fetch("verification_url")
      assert_equal "jp", panel.fetch("region")
      assert_equal auth_app_sign_in_path(ri: "jp"), inertia_props.fetch("back_link").fetch("href")
    end

    # Case F-1: Identifier does not exist
    test "options returns an indistinguishable padded challenge if identifier is not found" do
      post auth_app_sign_in_passkey_options_path(ri: "jp"),
           params: options_params(identifier: "unknown@example.com")

      assert_response :ok
      assert_predicate response.parsed_body["challenge_id"], :present?
      assert_equal 4, response.parsed_body.dig("options", "allowCredentials").size
    end

    test "options returns error if identifier missing" do
      post auth_app_sign_in_passkey_options_path(ri: "jp"), params: options_params(identifier: nil)

      assert_response :unprocessable_content
      assert_includes response.body, I18n.t("errors.webauthn.pii_required")
    end

    # Case F-2: Identifier exists but no passkey
    test "options returns an indistinguishable padded challenge if the account has no passkeys" do
      user_no_passkey = clients(:two)
      user_no_passkey_email = ClientEmail.create!(user: user_no_passkey, address: "nopasskey@example.com")

      post auth_app_sign_in_passkey_options_path(ri: "jp"),
           params: options_params(identifier: user_no_passkey_email.address)

      assert_response :ok
      assert_predicate response.parsed_body["challenge_id"], :present?
      assert_equal 4, response.parsed_body.dig("options", "allowCredentials").size
    end

    test "options returns challenge and allowCredentials for email identifier" do
      email = ClientEmail.find_by(user: @user).address

      post auth_app_sign_in_passkey_options_path(ri: "jp"), params: options_params(identifier: email)

      assert_response :ok
      json = response.parsed_body

      assert_not_nil json["challenge_id"]
      options = json["options"]

      assert_equal 4, options["allowCredentials"].size

      Rails.logger.debug { "DEBUG: allowCredentials = #{options["allowCredentials"].inspect}" }
      Rails.logger.debug { "DEBUG: allowCredentials = #{options["allowCredentials"].inspect}" }
      Rails.logger.debug { "DEBUG: passkey_id = #{@passkey.webauthn_id}" }

      # Verify allowCredentials contains our passkey ID
      match = options["allowCredentials"].any? { |c| c["id"] == @passkey.webauthn_id }

      assert match, "Expected allowCredentials to contain #{@passkey.webauthn_id}"

      # Case F-4: Challenge saved with correct purpose
      assert_not_nil session[:passkey_challenges][json["challenge_id"]]
      assert_equal "authentication", session[:passkey_challenges][json["challenge_id"]]["purpose"]
    end

    test "options returns challenge and allowCredentials for telephone identifier" do
      post auth_app_sign_in_passkey_options_path(ri: "jp"),
           params: options_params(identifier: @user_telephone.number)

      assert_response :ok
      json = response.parsed_body

      assert_not_nil json["challenge_id"]
      assert_not_empty json.dig("options", "allowCredentials")
    end

    # Case F-3b: JSON response format validation for authentication options (regression test)
    test "options returns valid Base64URL encoded challenge" do
      email = ClientEmail.find_by(user: @user).address

      post auth_app_sign_in_passkey_options_path(ri: "jp"), params: options_params(identifier: email)

      assert_response :ok
      json = response.parsed_body
      options = json["options"]

      # Verify challenge is Base64URL encoded
      challenge = options["challenge"]

      assert_match(/\A[A-Za-z0-9_-]+\z/, challenge, "challenge should be Base64URL format")
      padding_needed = (4 - (challenge.length % 4)) % 4

      assert_operator padding_needed, :<=, 2,
                      "challenge should have valid Base64URL padding (0-2 chars), but would need #{padding_needed}"

      # Verify no duplicate keys in JSON
      json_string = response.body
      challenge_count = json_string.scan(/"challenge"/).count

      assert_equal 1, challenge_count,
                   "JSON should contain exactly one 'challenge' key (found #{challenge_count})"

      # Verify allowCredentials IDs are properly encoded
      options["allowCredentials"].each_with_index do |credential, index|
        cred_id = credential["id"]

        assert_match(
          /\A[A-Za-z0-9_-]+\z/, cred_id,
          "allowCredentials[#{index}].id should be Base64URL format",
        )
      end
    end

    # Case G-1: Verification success
    test "verification logs user in on success" do
      assert_not_nil @passkey, "Passkey must exist"
      # Get challenge
      email = ClientEmail.find_by(user: @user).address
      post auth_app_sign_in_passkey_options_path(ri: "jp"), params: options_params(identifier: email)
      explanation = response.parsed_body
      challenge_id = explanation["challenge_id"]

      params = assertion_params_for(
        challenge_id: challenge_id,
        challenge: explanation.dig("options", "challenge"),
      )

      # Should log in
      post auth_app_sign_in_passkey_verification_path(ri: "jp", pt: "/settings/emails"), params: params

      assert_response :ok
      json = response.parsed_body

      assert_equal "ok", json["status"]
      assert_not_nil json["access_token"]
      assert_equal "Bearer", json["token_type"]
      assert_equal AuthenticationBase::ACCESS_TOKEN_TTL.to_i, json["expires_in"]
      assert_equal auth_app_sign_in_check_path(ri: "jp"), json["redirect_url"]

      # Challenge verification updates sign count
      assert_equal 1, @passkey.reload.sign_count
    end

    test "verification rejects a UV=false assertion even with a valid signature" do
      post auth_app_sign_in_passkey_options_path(ri: "jp"),
           params: options_params(identifier: @user_email.address)
      body = response.parsed_body

      post auth_app_sign_in_passkey_verification_path(ri: "jp"), params: {
        challenge_id: body["challenge_id"],
        credential: fake_assertion(
          @fake_client, challenge: body.dig("options", "challenge"), user_verified: false,
        ),
      }

      assert_response :unauthorized
      assert_includes response.body, I18n.t("errors.webauthn.verification_failed")
    end

    test "verification with session limit exceeded returns session_restricted" do
      # Create 2 active sessions to hit the limit
      ClientToken.where(user_id: @user.id).delete_all
      2.times do
        create_rotated_active_user_session(@user, rotations: 3)
      end

      # Get challenge
      email = ClientEmail.find_by(user: @user).address
      post auth_app_sign_in_passkey_options_path(ri: "jp"), params: options_params(identifier: email)
      explanation = response.parsed_body

      post auth_app_sign_in_passkey_verification_path(ri: "jp"), params: assertion_params_for(
        challenge_id: explanation["challenge_id"],
        challenge: explanation.dig("options", "challenge"),
      )

      assert_response :ok
      json = response.parsed_body

      assert_equal "session_restricted", json["status"]
      assert_equal auth_app_sign_in_session_path(ri: "jp"), json["redirect_url"]
      assert_equal 0, ClientToken.where(user_id: @user.id, user_token_status_id: ClientTokenStatus::RESTRICTED).count
    end

    test "verification returns same response for credential mismatch and missing verified pii" do
      # Baseline: credential mismatch
      post auth_app_sign_in_passkey_options_path(ri: "jp"),
           params: options_params(identifier: @user_email.address)
      baseline_challenge_id = response.parsed_body["challenge_id"]

      post auth_app_sign_in_passkey_verification_path(ri: "jp"), params: {
        challenge_id: baseline_challenge_id,
        credential: {
          id: Base64.urlsafe_encode64("unknown_credential", padding: false),
          response: { clientDataJSON: "e30=", authenticatorData: "e30=", signature: "sig", userHandle: "h" },
        },
      }

      assert_response :unauthorized
      mismatch_body = response.body

      # PII missing user with valid passkey credential
      user_without_verified_pii = Client.create!(status_id: ClientStatus::NOTHING, mfa_level_enabled: false)
      email = user_without_verified_pii.client_emails.create!(
        address: "unverified_passkey_#{SecureRandom.hex(4)}@example.com",
        user_email_status_id: ClientEmailStatus::VERIFIED,
      )
      passkey = ClientPasskey.create!(
        user: user_without_verified_pii,
        webauthn_id: Base64.urlsafe_encode64("pii_missing_login_id_#{SecureRandom.hex(4)}", padding: false),
        external_id: SecureRandom.uuid,
        public_key: "pii_missing_public_key",
        description: "PII missing key",
        status_id: ClientPasskeyStatus::ACTIVE,
      )
      email.update!(user_email_status_id: ClientEmailStatus::UNVERIFIED)

      post auth_app_sign_in_passkey_options_path(ri: "jp"), params: options_params(identifier: email.address)
      pii_challenge_id = response.parsed_body["challenge_id"]

      post auth_app_sign_in_passkey_verification_path(ri: "jp"), params: {
        challenge_id: pii_challenge_id,
        credential: {
          id: passkey.webauthn_id,
          response: { clientDataJSON: "e30=",
                      authenticatorData: "e30=",
                      signature: "sig",
                      userHandle: "h", },
        },
      }

      assert_response :unauthorized
      assert_equal mismatch_body, response.body
    end

    test "verification returns unauthorized when challenge actor and passkey owner mismatch" do
      post auth_app_sign_in_passkey_options_path(ri: "jp"),
           params: options_params(identifier: @user_email.address)
      challenge_id = response.parsed_body["challenge_id"]

      other_user = create_verified_user_with_email(email_address: "passkey_other_#{SecureRandom.hex(4)}@example.com")
      other_passkey = ClientPasskey.create!(
        user: other_user,
        webauthn_id: Base64.urlsafe_encode64("other_user_key_#{SecureRandom.hex(4)}", padding: false),
        external_id: SecureRandom.uuid,
        public_key: "other_user_key",
        description: "Other Client Key",
        status_id: ClientPasskeyStatus::ACTIVE,
      )

      post auth_app_sign_in_passkey_verification_path(ri: "jp"), params: {
        challenge_id: challenge_id,
        credential: {
          id: other_passkey.webauthn_id,
          response: { clientDataJSON: "e30=",
                      authenticatorData: "e30=",
                      signature: "sig",
                      userHandle: "h", },
        },
      }

      assert_response :unauthorized
      assert_includes response.body, I18n.t("errors.webauthn.credential_not_found")
    end

    test "verification returns 422 when login result status is unknown" do
      post auth_app_sign_in_passkey_options_path(ri: "jp"),
           params: options_params(identifier: @user_email.address)
      body = response.parsed_body

      original_method = Auth::App::Sign::In::Passkey::VerificationsController.instance_method(:perform_passkey_sign_in)
      Auth::App::Sign::In::Passkey::VerificationsController.define_method(:perform_passkey_sign_in) do |_passkey|
        { status: :unknown }
      end
      begin
        post(
          auth_app_sign_in_passkey_verification_path(ri: "jp"), params: assertion_params_for(
            challenge_id: body["challenge_id"],
            challenge: body.dig("options", "challenge"),
          ),
        )
      ensure
        Auth::App::Sign::In::Passkey::VerificationsController.define_method(:perform_passkey_sign_in, original_method)
      end

      assert_response :unprocessable_content
      assert_includes response.body, I18n.t("errors.login_failed")
    end

    test "verification rejects replaying a consumed challenge" do
      email = ClientEmail.find_by(user: @user).address
      post auth_app_sign_in_passkey_options_path(ri: "jp"), params: options_params(identifier: email)
      body = response.parsed_body

      # First attempt fails UV policy but must still burn the challenge.
      post auth_app_sign_in_passkey_verification_path(ri: "jp"), params: {
        challenge_id: body["challenge_id"],
        credential: fake_assertion(
          @fake_client, challenge: body.dig("options", "challenge"), user_verified: false,
        ),
      }

      assert_response :unauthorized

      # Replaying the same challenge with a valid assertion is rejected.
      post auth_app_sign_in_passkey_verification_path(ri: "jp"), params: assertion_params_for(
        challenge_id: body["challenge_id"],
        challenge: body.dig("options", "challenge"),
      )

      assert_response :bad_request
      assert_includes response.body, I18n.t("errors.webauthn.challenge_invalid")
    end

    test "options does not disclose that the user is at the session hard reject limit" do
      # Create 2 active + 1 restricted to hit the hard limit
      ClientToken.where(user_id: @user.id).delete_all
      2.times do
        create_rotated_active_user_session(@user, rotations: 3)
      end
      restricted = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
      restricted.rotate_refresh_token!(discarded_at: 15.minutes.from_now)

      post auth_app_sign_in_passkey_options_path(ri: "jp"),
           params: options_params(identifier: @user_email.address),
           as: :json

      assert_response :ok
      assert_predicate response.parsed_body["challenge_id"], :present?
      assert_equal 4, response.parsed_body.dig("options", "allowCredentials").size
    end

    test "options returns turnstile error when response token is missing" do
      TurnstileVerifierStub.challenge_enabled = false
      TurnstileVerifierStub.enabled = false
      TurnstileVerifierStub.response = { "success" => false, "error" => "missing cf-turnstile-response" }

      post auth_app_sign_in_passkey_options_path(ri: "jp"), params: { identifier: @user_email.address }

      assert_response :unprocessable_content
      assert_equal I18n.t("turnstile_error"), response.parsed_body["error"]
    end

    private

    def register_fake_client_passkey!(client:, user:, description:)
      ClientPasskey.create!(
        user: user,
        external_id: SecureRandom.uuid,
        description: description,
        status_id: ClientPasskeyStatus::ACTIVE,
        **fake_credential_record_attrs(client),
      )
    end

    def assertion_params_for(challenge_id:, challenge:, client: @fake_client)
      {
        challenge_id: challenge_id,
        credential: fake_assertion(client, challenge: challenge),
      }
    end

    def options_params(identifier:)
      {
        identifier: identifier,
        "cf-turnstile-response": "test_token",
      }
    end

    def create_rotated_active_user_session(user, rotations:)
      token = ClientToken.create!(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
      refresh = token.rotate_refresh_token!

      rotations.times do
        refresh = SignRefreshTokenIssuer.call(refresh_token: refresh)[:refresh_token]
      end
    end
  end
end

# DAMP local helper copy for former shared test support.
class Auth::App::In::PasskeysControllerTest
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
class Auth::App::In::PasskeysControllerTest
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
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
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
    %w(SIGN_APP SIGN_ORG SIGN_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
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

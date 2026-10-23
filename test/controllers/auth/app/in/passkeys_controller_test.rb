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
      host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      TurnstileVerifierStub.challenge_enabled = true
      TurnstileVerifierStub.challenge_response = { "success" => true }
      TurnstileVerifierStub.enabled = true
      TurnstileVerifierStub.response = { "success" => true }
      @user = create_verified_user_with_email(email_address: "passkey_test_user_#{SecureRandom.hex(6)}@example.com")
      @user_email = @user.client_emails.first # Use the email created by the helper
      # Only an effective binding counts as a verified contact (D-85).
      @user_email.finalize_binding!

      @user_telephone = ClientTelephone.create!(
        user: @user,
        number: "+819012345678",
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
      ) unless ClientTelephone.find_by(user: @user)

      # Real-crypto passkey for login: registered via the gem's FakeClient so
      # verification exercises the actual signature/RP ID/origin/UV path.
      @fake_client = webauthn_fake_client
      @passkey = register_fake_client_passkey!(client: @fake_client, user: @user, description: "Login Key")
      # Auth runs a ceremony only for a browser that Base admitted (D-82).
      begin
        fv5026 = "app"
        fv5025 = auth_app_sign_in_path
        fv5024 = { ri: "jp" }
        fv5023 = { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL") }
        begin
          fv5001 = self
          fv5017 = fv5026.to_s
          fv5013 = fv5025
          fv5012 = fv5024
          fv5020 = fv5023
          fv5015 = fv5001.cookies["__Host-auth_sid"].presence || fv5001.cookies["auth_sid"].presence
          if fv5015.present?
            fv5022 = {
              "app" => ClientAuthCeremonySession,
              "com" => VisitorAuthCeremonySession,
              "org" => OperatorAuthCeremonySession,
            }.fetch(fv5017).find_active_by_raw_sid(fv5015)
            fv5021 = fv5022&.admitted? && fv5022.admission_purpose == "authentication_handoff"
          end

          unless fv5021
            fv5014 = ENV.fetch(
              { "app" => "PUBLIC_AUTH_SERVICE_URL",
                "com" => "PUBLIC_AUTH_CORPORATE_URL",
                "org" => "PUBLIC_AUTH_STAFF_URL", }.fetch(fv5017),
            )

            fv5002 = fv5020.merge(
              "Host" => fv5014, "Origin" => "https://#{fv5014}", "Sec-Fetch-Site" => "same-origin",
            )
            fv5011 = OidcTestEntry.issue!(
              surface: fv5017,
              intent: "sign_in",
              base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
              base_token: nil,
            )
            fv5018 = BaseAuthAdmissionCoordinator.find_admission_binding!(
              surface: fv5017, reference: fv5011.reference,
            )
            fv5019, fv5015 = fv5018.class.auth_admission_session_class.issue!
            fv5018.attach_auth_session!(auth_session: fv5019, confirmation_ref: SecureRandom.uuid)
            fv5018.confirm_base!(
              base_token: nil,
              browser_digest: AuthAdmissionBinding.browser_digest(
                surface: fv5017,
                entry_ref: fv5011.reference,
                nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
              ),
            )
            fv5001.host!(fv5014)
            fv5001.https!
            fv5016 = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
            fv5001.cookies.delete("auth_sid")
            fv5001.cookies.delete("__Host-auth_sid")
            store_raw_cookies(
              fv5001.cookies,
              "#{fv5016}=#{Rack::Utils.escape(fv5015)}", URI.parse("https://#{fv5014}/"),
            )
            fv5001.get(
              fv5013,
              params: fv5012.merge(entry_ref: fv5011.reference),
              headers: fv5002,
            )
            fv5005, fv5003, fv5004 =
              begin
                fv5010 = fv5001.response.body
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
            fv5001.post(
              fv5005,
              params: fv5004.merge(authenticity_token: fv5003),
              headers: fv5002,
            )

            cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
            ClientAuthCeremonySession.find_active_by_raw_sid(cookies[cookie_name])
            @primary_sign_in_binding = nil

            assert_equal 303, fv5001.response.status
          end
        end
      end
    end

    teardown do
      TurnstileVerifierStub.challenge_enabled = false
      TurnstileVerifierStub.challenge_response = nil
      TurnstileVerifierStub.enabled = false
      TurnstileVerifierStub.response = nil
    end
    test "should get new" do
      get new_auth_app_sign_in_passkey_path(ri: "jp", fb: @primary_sign_in_binding)

      assert_response :success
      assert_equal "auth/app/sign/in/passkeys/new", inertia_component

      panel = inertia_props.fetch("panel")

      options_uri = URI.parse(panel.fetch("options_url"))
      verification_uri = URI.parse(panel.fetch("verification_url"))

      assert_equal URI.parse(auth_app_sign_in_passkey_options_path(ri: "jp")).path, options_uri.path
      assert_equal URI.parse(auth_app_sign_in_passkey_verification_path(ri: "jp")).path, verification_uri.path
      # An OIDC-parent primary phase has no sign-in flow, so the endpoints carry no phase binding.
      assert_nil Rack::Utils.parse_nested_query(options_uri.query)["fb"]
      assert_nil Rack::Utils.parse_nested_query(verification_uri.query)["fb"]
      assert_equal "jp", panel.fetch("region")
      assert_equal "identifier", panel.fetch("identifier_param")
      assert_predicate panel.fetch("field").fetch("label"), :present?
      assert_equal URI.parse(auth_app_sign_in_path(ri: "jp")).path,
                   URI.parse(inertia_props.fetch("back_link").fetch("href")).path
    end

    test "options binds the challenge to the named Identity and does not disclose credential descriptors" do
      post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding), params: options_params

      assert_response :ok
      json = response.parsed_body

      assert_predicate json.dig("options", "challenge"), :present?
      assert_empty Array(json.dig("options", "allowCredentials"))
      assert_equal "app:#{@user.id}", session[:passkey_challenges].fetch(json.fetch("challenge_id"))["actor_global_key"]
      assert_not_includes response.body, @passkey.webauthn_id
    end

    test "an unknown identifier gets the same response shape and a challenge no credential can satisfy" do
      post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding),
           params: options_params(identifier: @user_email.address)

      assert_response :ok
      known = response.parsed_body

      post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding),
           params: options_params(identifier: "unknown-identifier@example.com")

      assert_response :ok
      unknown = response.parsed_body

      assert_equal known.keys.sort, unknown.keys.sort
      assert_equal known.fetch("options").keys.sort, unknown.fetch("options").keys.sort
      assert_empty Array(unknown.dig("options", "allowCredentials"))
      assert_equal "app:0", session[:passkey_challenges].fetch(unknown.fetch("challenge_id"))["actor_global_key"]
    end

    test "options refuses a missing identifier without issuing a challenge" do
      post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding),
           params: { "cf-turnstile-response": "test_token" }

      assert_response :unprocessable_content
      assert_empty session[:passkey_challenges].to_h
    end

    test "options selects the Identity by its effective telephone" do
      @user_telephone.finalize_binding!
      post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding),
           params: options_params(identifier: @user_telephone.number)

      assert_response :ok
      json = response.parsed_body

      assert_empty Array(json.dig("options", "allowCredentials"))
      assert_equal "app:#{@user.id}", session[:passkey_challenges].fetch(json.fetch("challenge_id"))["actor_global_key"]
    end

    # Case F-3b: JSON response format validation for authentication options (regression test)
    test "options returns valid Base64URL encoded challenge" do
      email = ClientEmail.find_by(user: @user).address

      post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding),
           params: options_params(identifier: email)

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
      challenge_count = json_string.scan('"challenge"').count

      assert_equal 1, challenge_count,
                   "JSON should contain exactly one 'challenge' key (found #{challenge_count})"

      assert_empty Array(options["allowCredentials"])
    end

    # Case G-1: Verification success
    test "verification records authentication evidence and issues no session" do
      assert_not_nil @passkey, "Passkey must exist"
      # Get challenge
      email = ClientEmail.find_by(user: @user).address
      post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding),
           params: options_params(identifier: email)
      explanation = response.parsed_body
      challenge_id = explanation["challenge_id"]

      params = assertion_params_for(
        challenge_id: challenge_id,
        challenge: explanation.dig("options", "challenge"),
      )

      # Should log in
      post auth_app_sign_in_passkey_verification_path(ri: "jp", fb: @primary_sign_in_binding, pt: "/settings/emails"),
           params: params

      assert_response :ok
      json = response.parsed_body

      assert_equal "ok", json["status"]
      # Auth proves the credential and hands the result to Base; it issues no session (D-10).
      assert_equal %w(redirect_url status), json.keys.sort
      assert_equal 0, ClientToken.where(user_id: @user.id).count
      ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies["auth_sid"])

      assert_predicate ceremony, :authentication_evidence_recorded?
      assert_equal URI.parse(auth_app_sign_in_check_path(ri: "jp")).path, URI.parse(json.fetch("redirect_url")).path

      # Challenge verification updates sign count
      assert_equal 1, @passkey.reload.sign_count
    end

    test "verification rejects a UV=false assertion even with a valid signature" do
      post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding),
           params: options_params(identifier: @user_email.address)
      body = response.parsed_body

      post auth_app_sign_in_passkey_verification_path(ri: "jp", fb: @primary_sign_in_binding), params: {
        challenge_id: body["challenge_id"],
        credential: fake_assertion(
          @fake_client, challenge: body.dig("options", "challenge"), user_verified: false,
        ),
      }

      assert_response :unauthorized
      assert_includes response.body, I18n.t("errors.webauthn.verification_failed")
    end

    test "missing credential and invalid signature have identical public refusals" do
      refusals = []
      token_count = ClientToken.count
      original_sign_count = @passkey.sign_count
      [:missing, :invalid_signature].each do |failure|
        post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding),
             params: options_params

        assert_response :ok
        options = response.parsed_body
        assertion = @fake_client.get(
          challenge: options.fetch("options").fetch("challenge"), user_verified: true, sign_count: 1,
        )
        if failure == :missing
          assertion["id"] = Base64.urlsafe_encode64("unregistered-credential", padding: false)
        else
          assertion.fetch("response")["signature"] = Base64.urlsafe_encode64("invalid-signature", padding: false)
        end
        post auth_app_sign_in_passkey_verification_path(ri: "jp", fb: @primary_sign_in_binding),
             params: { challenge_id: options.fetch("challenge_id"), credential: assertion }

        assert_response :unauthorized
        refusals << [response.status, response.body, response.headers["Content-Type"],
                     response.headers["Location"], response.headers["Cache-Control"],]
      end

      assert_equal refusals.first, refusals.last
      assert_equal token_count, ClientToken.count
      assert_equal original_sign_count, @passkey.reload.sign_count
    end

    test "verification returns same response for credential mismatch and missing verified pii" do
      # Baseline: credential mismatch
      post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding),
           params: options_params(identifier: @user_email.address)
      baseline_challenge_id = response.parsed_body["challenge_id"]

      post auth_app_sign_in_passkey_verification_path(ri: "jp", fb: @primary_sign_in_binding), params: {
        challenge_id: baseline_challenge_id,
        credential: {
          id: Base64.urlsafe_encode64("unknown_credential", padding: false),
          response: { clientDataJSON: "e30=", authenticatorData: "e30=", signature: "sig", userHandle: "h" },
        },
      }

      assert_response :unauthorized
      mismatch_body = response.body

      # PII missing user with valid passkey credential
      user_without_verified_pii = Client.create!(status_id: ClientStatus::NOTHING, security_mode_id: SecurityModeConfigurable::NORMAL)
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

      post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding),
           params: options_params(identifier: email.address)
      pii_challenge_id = response.parsed_body["challenge_id"]

      post auth_app_sign_in_passkey_verification_path(ri: "jp", fb: @primary_sign_in_binding), params: {
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

    test "verification uses credential ownership and ignores a forged userHandle" do
      post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding),
           params: options_params
      body = response.parsed_body
      credential = fake_assertion(@fake_client, challenge: body.dig("options", "challenge"))
      credential["response"]["userHandle"] = Base64.urlsafe_encode64("forged-user-handle", padding: false)

      post auth_app_sign_in_passkey_verification_path(ri: "jp", fb: @primary_sign_in_binding), params: {
        challenge_id: body.fetch("challenge_id"),
        credential: credential,
      }

      assert_response :ok
      assert_equal "ok", response.parsed_body["status"]
      # The evidence names the credential owner, never the forged handle; Auth issues no session (D-10).
      assert_equal 0, ClientToken.where(user_id: @user.id).count
      ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies["auth_sid"])

      assert_predicate ceremony, :authentication_evidence_recorded?
      assert_equal @user.id, ClientSignInFlow.order(:id).last.principal_id
    end

    test "verification rejects a disabled discoverable credential" do
      @passkey.update!(status_id: ClientPasskeyStatus::DISABLED)
      post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding), params: options_params
      body = response.parsed_body

      post auth_app_sign_in_passkey_verification_path(ri: "jp", fb: @primary_sign_in_binding),
           params: assertion_params_for(
             challenge_id: body.fetch("challenge_id"),
             challenge: body.dig("options", "challenge"),
           )

      assert_response :unauthorized
      assert_includes response.body, I18n.t("errors.webauthn.verification_failed")
      assert_empty ClientToken.where(user_id: @user.id)
    end

    test "verification rejects a discoverable credential owned by a suspended client" do
      @user.update!(deactivated_at: Time.current)
      post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding), params: options_params
      body = response.parsed_body

      post auth_app_sign_in_passkey_verification_path(ri: "jp", fb: @primary_sign_in_binding),
           params: assertion_params_for(
             challenge_id: body.fetch("challenge_id"),
             challenge: body.dig("options", "challenge"),
           )

      assert_response :unauthorized
      assert_includes response.body, I18n.t("errors.webauthn.verification_failed")
      assert_empty ClientToken.where(user_id: @user.id)
    end

    test "verification returns 422 when login result status is unknown" do
      post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding),
           params: options_params(identifier: @user_email.address)
      body = response.parsed_body

      original_method = Auth::App::Sign::In::Passkey::VerificationsController.instance_method(:perform_passkey_sign_in)
      Auth::App::Sign::In::Passkey::VerificationsController.define_method(:perform_passkey_sign_in) do |_passkey|
        { status: :unknown }
      end
      begin
        post(
          auth_app_sign_in_passkey_verification_path(ri: "jp", fb: @primary_sign_in_binding),
          params: assertion_params_for(
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
      post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding),
           params: options_params(identifier: email)
      body = response.parsed_body

      # First attempt fails UV policy but must still burn the challenge.
      post auth_app_sign_in_passkey_verification_path(ri: "jp", fb: @primary_sign_in_binding), params: {
        challenge_id: body["challenge_id"],
        credential: fake_assertion(
          @fake_client, challenge: body.dig("options", "challenge"), user_verified: false,
        ),
      }

      assert_response :unauthorized

      # Replaying the same challenge with a valid assertion is rejected.
      post auth_app_sign_in_passkey_verification_path(ri: "jp", fb: @primary_sign_in_binding),
           params: assertion_params_for(
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
      restricted = ClientToken.create!(authentication_epoch: 0, user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
      restricted.rotate_refresh_token!(discard_at: 15.minutes.from_now)

      post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding),
           params: options_params(identifier: @user_email.address),
           as: :json

      assert_response :ok
      assert_predicate response.parsed_body["challenge_id"], :present?
      assert_empty Array(response.parsed_body.dig("options", "allowCredentials"))
    end

    test "options returns turnstile error when response token is missing" do
      TurnstileVerifierStub.challenge_enabled = false
      TurnstileVerifierStub.enabled = false
      TurnstileVerifierStub.response = { "success" => false, "error" => "missing cf-turnstile-response" }

      post auth_app_sign_in_passkey_options_path(ri: "jp", fb: @primary_sign_in_binding),
           params: { identifier: @user_email.address }

      assert_response :unprocessable_content
      assert_equal I18n.t("turnstile_error"), response.parsed_body["error"]
    end

    private

    def register_fake_client_passkey!(client:, user:, description:)
      passkey = ClientPasskey.create!(
        user: user,
        external_id: SecureRandom.uuid,
        description: description,
        status_id: ClientPasskeyStatus::ACTIVE,
        **fake_credential_record_attrs(client),
      )
      # The credential's MFA callback refreshes the persisted Client row. Keep
      # this fixture owner usable for later optimistic-locking assertions.
      user.reload
      passkey
    end

    def assertion_params_for(challenge_id:, challenge:, client: @fake_client)
      {
        challenge_id: challenge_id,
        credential: fake_assertion(client, challenge: challenge),
      }
    end

    def options_params(identifier: @user_email.address)
      { "cf-turnstile-response": "test_token", identifier: identifier }
    end

    def create_rotated_active_user_session(user, rotations:)
      token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
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

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::NOTHING,
      visibility_id: VisitorVisibility::VISITOR,
    )
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

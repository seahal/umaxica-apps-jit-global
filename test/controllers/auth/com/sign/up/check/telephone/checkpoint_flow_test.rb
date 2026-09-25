# typed: false
# frozen_string_literal: true

require "test_helper"

# Drives the com telephone sign-up checkpoint sequence through public endpoints so the
# requirement bookkeeping is exercised through the real sequence.
class Auth::Com::Sign::Up::Check::Telephone::CheckpointFlowTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    host! @host
    cookies["csrf_token"] = csrf_token_value
    Rails.configuration.x.rate_limit.fetch(:store).clear
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }

    Prosopite.pause do
      [VisitorStatus::NOTHING, VisitorStatus::ACTIVE].each { |id| VisitorStatus.find_or_create_by!(id: id) }
      VisitorVisibility::DEFAULTS.each { |id| VisitorVisibility.find_or_create_by!(id: id) }
      [
        VisitorTelephoneStatus::UNVERIFIED,
        VisitorTelephoneStatus::VERIFIED,
        VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
        VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP,
      ].each { |id| VisitorTelephoneStatus.find_or_create_by!(id: id) }
      VisitorPasskeyStatus::DEFAULTS.each { |id| VisitorPasskeyStatus.find_or_create_by!(id: id) }
      VisitorTokenDbscStatus.ensure_defaults!
      VisitorTokenStatus::DEFAULTS.each { |id| VisitorTokenStatus.find_or_create_by!(id: id) }
    end
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "the passkey checkpoint issues a challenge and clears its requirement once registered" do
    verify_telephone_via_otp!("+819022220001")
    cycle = current_sign_up_flow

    get auth_com_sign_up_check_telephone_passkey_url(ri: "jp"), headers: default_headers

    assert_response :success

    register_passkey!(cycle, "com_checkpoint_1")

    assert cycle.reload.requirement_cleared?(:passkey)
    assert_not_includes cycle.completed_requirements.keys, "passcode"
  end

  private

  def start_telephone_signup!(raw_number)
    post(
      auth_com_sign_up_telephone_url(ri: "jp"),
      params: {
        visitor_telephone: {
          raw_number: raw_number,
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      },
      headers: default_headers,
    )

    assert_response :redirect
    VisitorTelephone.order(:created_at).last
  end

  def verify_telephone_via_otp!(raw_number)
    telephone = start_telephone_signup!(raw_number)

    patch(
      auth_com_sign_up_check_telephone_otp_url(ri: "jp"),
      params: { visitor_telephone: { pass_code: otp_code_for(telephone) } },
      headers: default_headers,
    )

    assert_redirected_to auth_com_sign_up_guard_telephone_url(ri: "jp")

    get(auth_com_sign_up_guard_telephone_url(ri: "jp"), headers: default_headers)

    telephone.reload
  end

  # The WebAuthn verifier and the credential object are the third-party seam here; everything the
  # controller and the sequence do around them stays real.
  def register_passkey!(cycle, webauthn_suffix)
    post(auth_com_sign_up_check_telephone_passkey_url(ri: "jp"), headers: default_headers)

    assert_response :ok
    challenge_id = response.parsed_body["challenge_id"]

    mock_credential = Object.new
    mock_credential.define_singleton_method(:id) { "#{webauthn_suffix}_webauthn_id" }
    mock_credential.define_singleton_method(:public_key) { "#{webauthn_suffix}_public_key" }
    mock_credential.define_singleton_method(:sign_count) { 1 }
    mock_credential.define_singleton_method(:verify) { |_challenge| true }

    registration_context =
      Struct.new(
        :webauthn_id, :sign_count, :aaguid, :transports, :backup_eligible, :backup_state,
        :authenticator_attachment,
      )
        .new("#{webauthn_suffix}_webauthn_id", 1)

    Webauthn::RegistrationVerifier.stub(:verify!, registration_context) do
      WebAuthn::Credential.stub(:from_create, mock_credential) do
        patch(
          auth_com_sign_up_check_telephone_passkey_url(ri: "jp"),
          params: {
            challenge_id: challenge_id,
            checkpoint_version: cycle.reload.checkpoint_version,
            credential: {
              id: "#{webauthn_suffix}_webauthn_id",
              response: { clientDataJSON: "e30=", attestationObject: "e30=" },
            },
            description: "Signup Passkey",
          },
          headers: default_headers,
        )
      end
    end

    assert_response :created
    assert_equal auth_com_sign_up_check_telephone_birthdate_path(ri: "jp"),
                 response.parsed_body.fetch("redirect_url")
  end

  def current_sign_up_flow
    public_id = session.dig(:com_sign_up_flow_locator, "public_id")

    assert_predicate public_id, :present?
    VisitorSignUpFlow.find_by!(public_id: public_id)
  end

  def otp_code_for(telephone)
    otp_data = telephone.get_otp
    ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s
  end

  def default_headers
    { "Host" => @host, "HTTPS" => "on", "X-CSRF-Token" => csrf_token_value }
  end

  def csrf_token_value
    "test-csrf-token"
  end
end

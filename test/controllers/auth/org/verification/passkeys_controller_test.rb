# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"
require_relative "../../../../support/webauthn_fake_client_helper"

# Assertion verification is covered by the Passkey committer tests; these cases cover the admitted
# HTTP boundary on the staff surface.
class Auth::Org::Verification::PasskeysControllerTest < ActionDispatch::IntegrationTest
  include WebauthnFakeClientHelper

  fixtures :operators, :operator_tokens, :operator_passkeys

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  test "the admitted passkey page renders without creating a challenge" do
    actor = operators(:one)
    token = operator_tokens(:one)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor,
      token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_email", allowed_methods: [:passkey], purpose: "step_up",
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes,
        audience: "step_up:org", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      ),
      return_to: "/identity/emails",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: token,
    )
    record = OperatorStepUpSession.find_by!(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id)
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    admit_auth_ceremony_entry!(
      auth_org_verification_path,
      reference: issuance.reference,
      params: { ri: "jp" },
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "org", entry_ref: issuance.reference, nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      ),
    )

    get new_auth_org_verification_passkey_path(ri: "jp")

    assert_response :success
    assert_nil record.reload.passkey_challenge_ref
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at
  end

  # Sentinels of the challenge reference: missing, empty, zero, unknown and NUL-bearing.
  test "an assertion without an issued challenge is refused and keeps the ceremony pending" do
    actor = operators(:one)
    token = operator_tokens(:one)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor,
      token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_email", allowed_methods: [:passkey], purpose: "step_up",
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes,
        audience: "step_up:org", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      ),
      return_to: "/identity/emails",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: token,
    )
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    admit_auth_ceremony_entry!(
      auth_org_verification_path,
      reference: issuance.reference,
      params: { ri: "jp" },
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "org", entry_ref: issuance.reference, nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      ),
    )

    [nil, "", "0", "unknown-challenge", "abc\u0000def"].each do |challenge_id|
      post auth_org_verification_passkey_path(ri: "jp"), params: {
        challenge_id: challenge_id,
        credential: {
          id: "credential",
          rawId: "credential",
          type: "public-key",
          response: { authenticatorData: "data", clientDataJSON: "json", signature: "signature" },
        },
      }, as: :json

      assert_response :unprocessable_content, challenge_id.inspect
      assert_equal({ "error" => I18n.t("errors.webauthn.verification_failed") }, response.parsed_body)
    end
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil issuance.transaction.verified_credential_ref
    assert_nil token.reload.last_step_up_at
  end

  test "the passkey endpoints are refused without an admitted ceremony" do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")

    get new_auth_org_verification_passkey_path(ri: "jp")

    assert_response :bad_request
    post auth_org_verification_passkey_options_path(ri: "jp")

    assert_response :bad_request
    post auth_org_verification_passkey_path(ri: "jp")

    assert_response :bad_request
    assert_nil response.headers["Location"]
  end

  test "a registration with missing or false resident-key proof is refused over HTTP without a candidate" do
    actor, token, issuance = admitted_registration_bootstrap!
    [nil, { "credProps" => { "rk" => false } }].each do |extensions|
      options = registration_options!
      fake = webauthn_fake_client(origin: "https://#{ENV.fetch("PUBLIC_AUTH_STAFF_URL")}")
      attestation = fake_attestation(
        fake, challenge: options.fetch("options").fetch("challenge"), extensions: extensions,
      )

      post auth_org_verification_registration_passkey_path(ri: "jp"),
           params: { challenge_id: options.fetch("challenge_id"), credential: attestation, description: "Laptop" },
           as: :json

      assert_response :unprocessable_content
      assert_equal 0, OperatorPasskeyCeremonyCandidate.where(
        step_up_ceremony_transaction_ref: issuance.transaction.transaction_id,
      ).count
      assert_equal "pending", issuance.transaction.reload.status
      assert_equal 0, actor.staff_passkeys.count
      assert_nil token.reload.last_step_up_at
    end
  end

  test "a registration without user verification is refused over HTTP without a candidate" do
    actor, token, issuance = admitted_registration_bootstrap!
    options = registration_options!
    fake = webauthn_fake_client(origin: "https://#{ENV.fetch("PUBLIC_AUTH_STAFF_URL")}")
    attestation = fake_attestation(
      fake, challenge: options.fetch("options").fetch("challenge"), user_verified: false,
            extensions: { "credProps" => { "rk" => true } },
    )

    post auth_org_verification_registration_passkey_path(ri: "jp"),
         params: { challenge_id: options.fetch("challenge_id"), credential: attestation, description: "Laptop" },
         as: :json

    assert_response :unprocessable_content
    assert_equal 0, OperatorPasskeyCeremonyCandidate.where(
      step_up_ceremony_transaction_ref: issuance.transaction.transaction_id,
    ).count
    assert_equal "pending", issuance.transaction.reload.status
    assert_equal 0, actor.staff_passkeys.count
    assert_nil token.reload.last_step_up_at
  end

  test "a registration with resident-key proof and user verification records only a candidate" do
    actor, token, issuance = admitted_registration_bootstrap!
    options = registration_options!
    fake = webauthn_fake_client(origin: "https://#{ENV.fetch("PUBLIC_AUTH_STAFF_URL")}")
    attestation = fake_attestation(
      fake, challenge: options.fetch("options").fetch("challenge"), user_verified: true,
            extensions: { "credProps" => { "rk" => true } },
    )

    post auth_org_verification_registration_passkey_path(ri: "jp"),
         params: { challenge_id: options.fetch("challenge_id"), credential: attestation, description: "Laptop" },
         as: :json

    assert_response :created
    assert_equal 1, OperatorPasskeyCeremonyCandidate.where(
      step_up_ceremony_transaction_ref: issuance.transaction.transaction_id,
    ).count
    assert_equal "verified", issuance.transaction.reload.status
    assert_equal 0, actor.staff_passkeys.count
    assert_nil token.reload.last_step_up_at
  end

  private

  def admitted_registration_bootstrap!
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::NOTHING)
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor, root_login_established_at: Time.current)
    nonce = "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor,
      token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_email", purpose: "bootstrap", step_up_required: false,
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, allowed_methods: [:passkey], audience: "step_up:org",
        session_binding: token.public_id,
        token_binding: token.public_id, require_session_binding: true, ttl: 15.minutes,
      ),
      return_to: "/identity/emails", base_browser_nonce: nonce, base_token: token,
    )
    host!(ENV.fetch("PUBLIC_AUTH_STAFF_URL"))
    https!
    admit_auth_ceremony_entry!(
      new_auth_org_verification_registration_passkey_path,
      reference: issuance.reference,
      params: { ri: "jp" },
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "org", entry_ref: issuance.reference, nonce: nonce,
      ),
    )
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    [actor, token, issuance]
  end

  def registration_options!
    post(
      auth_org_verification_registration_passkey_options_path(ri: "jp"),
      params: { "cf-turnstile-response" => "test-only" }, as: :json,
    )

    assert_response :ok
    response.parsed_body
  end
end

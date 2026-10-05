# frozen_string_literal: true

require "test_helper"

# Assertion verification is covered by the Passkey committer tests; these cases cover the admitted
# HTTP boundary on the staff surface.
class Auth::Org::Verification::PasskeysControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_tokens, :operator_passkeys

  test "the admitted passkey page renders without creating a challenge" do
    actor = operators(:one)
    token = operator_tokens(:one)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_email", allowed_methods: [:passkey], purpose: "step_up",
        audience: "step_up:org", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/emails",
    )
    record = OperatorStepUpSession.find_by!(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id)
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    post auth_org_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }

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
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_email", allowed_methods: [:passkey], purpose: "step_up",
        audience: "step_up:org", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/emails",
    )
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    post auth_org_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }

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
end

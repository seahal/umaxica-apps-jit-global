# typed: false
# frozen_string_literal: true

require "test_helper"

# Legacy AAL labels remain observable wire/storage labels only. The explicit requirement and
# evidence fields are the authority, and an explicit legacy demand is refused at issuance.
class IdentityStepUpCeremonyAalTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def issue_grant(required_aal: StepUpRequirement::NO_AAL)
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: "app", actor_ref: "actor-public-id", session_ref: "session-public-id",
      required_scope: "settings_email", required_aal: required_aal,
      step_up_required: true, user_verification_required: false, full_reauthentication_required: false,
      audience: "step_up:app", token_binding: "session-public-id", require_session_binding: true,
      allowed_methods: %i(totp passkey), phishing_resistant_required: false,
      return_to: "/identity/emails", expires_at: 15.minutes.from_now,
    ).grant
  end

  def decode_grant(token)
    IdentityStepUpCeremonyGrant.decode(
      token,
      issuer_id: IdentityStepUpCeremonyContract.acme_issuer_id("app"),
    )
  end

  test "the no-AAL storage label decodes as no legacy requirement" do
    assert_nil decode_grant(issue_grant).required_aal
  end

  test "an explicit legacy AAL demand is refused instead of translated" do
    assert_raises(ArgumentError) { issue_grant(required_aal: "aal2") }
  end

  def issue_result(aal: "aal1", user_verified: false, phishing_resistant: false)
    IdentityStepUpCeremonyResultIssuer.issue!(
      surface: "app", actor_ref: "actor-public-id", session_ref: "session-public-id",
      transaction_id: SecureRandom.uuid, grant_jti: SecureRandom.uuid, scope: "settings_email",
      aal: aal, method: "totp", phishing_resistant: phishing_resistant,
      user_verified: user_verified, full_reauthentication: false, credential_ref: "credential-public-id",
      challenge_id: SecureRandom.uuid, expires_at: 5.minutes.from_now,
    )
  end

  def decode_result(token)
    IdentityStepUpCeremonyResult.decode(
      token,
      issuer_id: IdentityStepUpCeremonyContract.sign_issuer_id("app"),
    )
  end

  test "a result exposes its legacy label without making it an authority" do
    result = decode_result(issue_result(aal: "aal2"))

    assert_equal :aal2, result.achieved_aal
    assert_not_respond_to result, :aal_required?
    assert_not result["user_verified"]
  end

  test "explicit evidence survives independently of the legacy label" do
    result = decode_result(issue_result(aal: "none", user_verified: true, phishing_resistant: true))

    assert_equal "none", result["aal"]
    assert result["user_verified"]
    assert result["phishing_resistant"]
    assert_equal "credential-public-id", result["credential_ref"]
  end
end

# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class OrgStepUpPasskeyCommittersTest < ActiveSupport::TestCase
  fixtures :operators, :operator_tokens

  setup do
    @actor = operators(:one)
    @token = operator_tokens(:one)
    @token.update!(authentication_context: nil)
    @fake = WebAuthn::FakeClient.new("https://auth.umaxica.org", encoding: :base64url)
    registration = @fake.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
    relying_party = WebAuthn::RelyingParty.new(
      id: "auth.umaxica.org", allowed_origins: [@fake.origin], encoding: :base64url,
    )
    credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
    @credential = @actor.staff_passkeys.create!(
      webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0,
    )
    @requirement = StepUpRequirement.new(
      scope: "settings_passkey", allowed_methods: [:passkey], purpose: "step_up",
      audience: "step_up:org", session_binding: @token.public_id, token_binding: @token.public_id,
      require_session_binding: true,
    )
    @transaction = BaseStepUpAdmissionIssuer.call!(
      actor: @actor, token: @token, requirement: @requirement, return_to: "/settings/passkeys",
    ).transaction
    @record = OperatorStepUpSession.find_by!(step_up_ceremony_transaction_ref: @transaction.transaction_id)
    @config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.org", origin: @fake.origin)
    options = Webauthn::AssertionVerifier.options_for(
      config: @config, allow_ids: [@credential.webauthn_id], purpose: :ordinary_step_up,
    )
    @reference = @record.issue_bound_passkey_challenge!(
      transaction: @transaction, challenge: options.challenge, rp_id: @config.rp_id, origin: @config.origin,
    )
    @assertion = @fake.get(challenge: options.challenge, user_verified: true, sign_count: 5)
  end

  test "ORG real signature evidence uses the existing credential reference and Base finalizes once" do
    IdentityStepUpPasskeyVerificationCommitter.call!(
      actor: @actor, transaction: @transaction, session_record: @record, config: @config,
      reference: @reference, credential_params: @assertion,
    )

    assert_equal "verified", @transaction.reload.status
    assert_equal @credential.external_id, @transaction.verified_credential_ref
    assert_equal 5, @credential.reload.sign_count
    assert_not_nil @credential.uv_verified_at
    assert_nil @token.reload.last_step_up_at

    ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: @transaction.transaction_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @transaction, ceremony_session_ref: ceremony.id.to_s,
    )
    2.times do
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, requirement: @requirement, raw_result: result.code,
      )

      assert_equal "consumed", @transaction.reload.status
      assert_equal @transaction.verified_at, @token.reload.last_step_up_at
      assert_predicate ceremony.reload, :completed?
      assert_predicate StepUpResolver.call(token: @token, requirement: @requirement), :satisfied?
    end
    assert_raises(StepUpSessionConsumable::ChallengeError) do
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: @actor, transaction: @transaction, session_record: @record, config: @config,
        reference: @reference, credential_params: @assertion,
      )
    end
  end

  test "ORG revoked credential cannot verify a valid signature" do
    @credential.update!(status_id: OperatorPasskeyStatus::REVOKED)

    assert_raises(ActiveRecord::RecordNotFound) do
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: @actor, transaction: @transaction, session_record: @record, config: @config,
        reference: @reference, credential_params: @assertion,
      )
    end
    assert_equal "pending", @transaction.reload.status
    assert_not_nil @record.reload.passkey_challenge_consumed_at
    assert_equal 0, @credential.reload.sign_count
    assert_nil @token.reload.last_step_up_at
  end

  test "ORG credential revoked after verification cannot establish Base freshness" do
    IdentityStepUpPasskeyVerificationCommitter.call!(
      actor: @actor, transaction: @transaction, session_record: @record, config: @config,
      reference: @reference, credential_params: @assertion,
    )
    ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: @transaction.transaction_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @transaction, ceremony_session_ref: ceremony.id.to_s,
    )
    @credential.update!(status_id: OperatorPasskeyStatus::REVOKED)

    assert_raises(ActiveRecord::RecordNotFound) do
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, requirement: @requirement, raw_result: result.code,
      )
    end
    assert_equal "verified", @transaction.reload.status
    assert_nil @transaction.consumed_at
    assert_nil @token.reload.last_step_up_at
    assert_not_predicate ceremony.reload, :completed?
  end
end

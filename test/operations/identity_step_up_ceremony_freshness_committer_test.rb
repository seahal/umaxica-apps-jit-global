# frozen_string_literal: true

require "test_helper"

# Verification evidence here is synthetic; signature verification is exercised by the Passkey
# committer tests. This boundary verifies atomic Base finalization and transport replay.
class IdentityStepUpCeremonyFreshnessCommitterTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  setup do
    @actor = clients(:one)
    @credential = @actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
    @token = ClientToken.create!(user: @actor)
    @requirement = StepUpRequirement.new(
      scope: "settings_birthdate", allowed_methods: [:passkey], purpose: "step_up",
      audience: "step_up:app", session_binding: @token.public_id, token_binding: @token.public_id,
      require_session_binding: true,
    )
    @transaction = BaseStepUpAdmissionIssuer.call!(
      actor: @actor, token: @token, requirement: @requirement, return_to: "/identity/birthdate",
    ).transaction
    @transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: @credential.public_id,
    )
    @ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: @transaction.transaction_id,
    )
    @issuance = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @transaction, ceremony_session_ref: @ceremony.id.to_s,
    )
  end

  test "Base atomically consumes the exact ticket and retains the original event on replay" do
    event = @transaction.verified_at
    2.times do
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, requirement: @requirement,
        raw_result: @issuance.code,
      )

      assert_equal "consumed", @transaction.reload.status
      assert_equal event, @token.reload.last_step_up_at
      assert_equal "settings_birthdate", @token.last_step_up_scope
      assert_predicate @ceremony.reload, :completed?
    end
  end

  test "revoking the verified credential before Base completion prevents freshness" do
    @credential.update!(discard_at: Time.current)
    assert_raises(ActiveRecord::RecordNotFound) do
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, requirement: @requirement,
        raw_result: @issuance.code,
      )
    end
    assert_equal "verified", @transaction.reload.status
    assert_nil @token.reload.last_step_up_at
    assert_not_predicate @ceremony.reload, :completed?
  end
end

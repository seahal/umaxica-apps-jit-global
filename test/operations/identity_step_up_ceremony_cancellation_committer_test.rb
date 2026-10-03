# frozen_string_literal: true

require "test_helper"

class IdentityStepUpCeremonyCancellationCommitterTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  setup do
    @actor = clients(:one)
    @token = ClientToken.create!(user: @actor)
    @requirement = StepUpRequirement.new(
      scope: "settings_birthdate", allowed_methods: [:passkey], purpose: "step_up",
      audience: "step_up:app", session_binding: @token.public_id, token_binding: @token.public_id,
      require_session_binding: true,
    )
    @transaction = BaseStepUpAdmissionIssuer.call!(
      actor: @actor, token: @token, requirement: @requirement, return_to: "/identity/birthdate",
    ).transaction
    @ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: @transaction.transaction_id,
    )
  end

  test "cancellation closes the exact transaction and its admitted Auth continuity" do
    assert IdentityStepUpCeremonyCancellationCommitter.call!(actor: @actor, token: @token, transaction: @transaction)
    assert_equal "canceled", @transaction.reload.status
    assert_not_nil @transaction.canceled_at
    assert_predicate @ceremony.reload, :cancelled?
    assert_nil @token.reload.last_step_up_at
    assert IdentityStepUpCeremonyCancellationCommitter.call!(actor: @actor, token: @token, transaction: @transaction)
    assert_equal "canceled", @transaction.reload.status
  end

  test "another browser session cannot cancel and a finalized result cannot be canceled" do
    other_token = ClientToken.create!(user: @actor)
    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyCancellationCommitter.call!(actor: @actor, token: other_token, transaction: @transaction)
    end
    assert_equal "pending", @transaction.reload.status
    assert_not_predicate @ceremony.reload, :cancelled?
    credential = @actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
    # Synthetic proof tests the cancellation/finalization boundary, not WebAuthn cryptography.
    @transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: credential.public_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @transaction,
      ceremony_session_ref: @ceremony.id.to_s,
    )
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction, requirement: @requirement, raw_result: result.code,
    )
    event = @token.reload.last_step_up_at

    assert_not IdentityStepUpCeremonyCancellationCommitter.call!(
      actor: @actor, token: @token,
      transaction: @transaction,
    )
    assert_equal "consumed", @transaction.reload.status
    assert_equal event, @token.reload.last_step_up_at
    assert_not_predicate @ceremony.reload, :cancelled?
  end
end

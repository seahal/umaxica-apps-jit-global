# frozen_string_literal: true

require "test_helper"

class IdentityStepUpCeremonyCancellationCommitterTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  setup do
    @actor = clients(:one)
    @token = ClientToken.create!(authentication_epoch: 0, user: @actor)
    @requirement = StepUpRequirement.new(
      scope: "settings_birthdate", step_up_required: true, allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: @actor.public_id,
      resource_ref: nil, tenant_ref: nil, purpose: "step_up",
      audience: "step_up:app", session_binding: @token.public_id, token_binding: @token.public_id,
      require_session_binding: true,
    )
    @transaction = BaseStepUpAdmissionIssuer.call!(
      actor: @actor, token: @token, requirement: @requirement, return_to: "/identity/birthdate",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: @token,
    ).transaction
    binding = ClientAuthAdmissionBinding.find_by!(step_up_ceremony_transaction_id: @transaction.id)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: @token, browser_digest: binding.base_browser_digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: binding.entry_ref, surface: "app", expected_intent: "step_up", binding:, raw_auth_sid: raw_sid,
    )
    @ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: @transaction.transaction_id,
      previous_raw_sid: raw_sid,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: @ceremony)
  end

  test "cancel-and-start rejects another Base browser nonce before canceling or issuing" do
    assert_no_difference ["ClientStepUpCeremonyTransaction.count", "ClientAuthAdmissionBinding.count"] do
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseStepUpCancelAndStartCommitter.call!(
          actor: @actor, token: @token, previous_transaction: @transaction,
          requirement: @requirement, return_to: "/identity/birthdate",
          base_browser_nonce: "different-browser-nonce", base_token: @token,
        )
      end
    end
    assert_equal ["pending", nil, nil, nil],
                 [@transaction.reload.status, @transaction.canceled_at, @ceremony.reload.cancelled_at,
                  @token.reload.last_step_up_at,]
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

  test "revoked device cannot cancel a still pending ceremony or its Auth continuity" do
    @token.device_session.revoke!(reason: "user_logout")

    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyCancellationCommitter.call!(actor: @actor, token: @token, transaction: @transaction)
    end
    assert_equal ["pending", nil, nil, nil],
                 [@transaction.reload.status, @transaction.canceled_at, @ceremony.reload.cancelled_at,
                  @token.reload.last_step_up_at,]
  end

  test "revoked device cannot finalize otherwise valid proof or write freshness" do
    credential = @actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
    # Synthetic proof isolates root authorization at finalization, not WebAuthn cryptography.
    @transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: credential.public_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @transaction,
      ceremony_session_ref: @ceremony.id.to_s,
    )
    @token.device_session.revoke!(reason: "user_logout")

    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, requirement: @requirement, raw_result: result.code,
      )
    end
    assert_equal ["verified", nil, nil],
                 [@transaction.reload.status, @token.reload.last_step_up_at, @ceremony.reload.completed_at]
  end

  test "root token revocation closes pending proof and Auth continuity atomically" do
    @token.revoke!

    assert_predicate @token.reload, :revoked?
    assert_equal "revoked", @transaction.reload.status
    assert_not_nil @transaction.revoked_at
    assert_not_nil @ceremony.reload.revoked_at
    assert_nil @token.last_step_up_at
    assert_operator @token.step_up_session.reload.discard_at, :<=, ClientToken.database_now
  end

  test "refresh rotation closes old pending proof instead of transferring it to the replacement" do
    raw = @token.rotate_refresh_token!
    _, verifier = ClientToken.parse_refresh_token(raw)
    digest = ClientToken.digest_refresh_token(verifier)
    result = ClientToken.rotate_refresh!(presented_refresh_digest: digest)

    assert_equal :rotated, result[:status]
    assert_equal "revoked", @transaction.reload.status
    assert_not_nil @ceremony.reload.revoked_at
    assert_nil result[:token].last_step_up_at
    assert_not_equal @token.public_id, result[:token].public_id
  end

  test "another browser session cannot cancel and a finalized result cannot be canceled" do
    other_token = ClientToken.create!(authentication_epoch: 0, user: @actor)
    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyCancellationCommitter.call!(actor: @actor, token: other_token, transaction: @transaction)
    end
    assert_equal "pending", @transaction.reload.status
    assert_not_predicate @ceremony.reload, :cancelled?
    credential = @actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
    # Synthetic proof tests the cancellation/finalization boundary, not WebAuthn cryptography.
    @transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true,
      user_verified: true,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: credential.public_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @transaction,
      ceremony_session_ref: @ceremony.id.to_s,
    )
    stale_parent = ClientStepUpCeremonyTransaction.find(@transaction.id)
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction, requirement: @requirement, raw_result: result.code,
    )
    event = @token.reload.last_step_up_at

    assert_no_difference ["ClientStepUpCeremonyTransaction.count", "ClientAuthAdmissionBinding.count"] do
      outcome = BaseStepUpCancelAndStartCommitter.call!(
        actor: @actor, token: @token, previous_transaction: stale_parent,
        requirement: @requirement, return_to: "/identity/birthdate",
        base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: @token,
      )

      assert_equal @transaction.id, outcome.transaction.id
      assert_equal "consumed", outcome.transaction.status
    end

    assert_not IdentityStepUpCeremonyCancellationCommitter.call!(
      actor: @actor, token: @token,
      transaction: @transaction,
    )
    assert_equal "consumed", @transaction.reload.status
    assert_equal event, @token.reload.last_step_up_at
    assert_not_predicate @ceremony.reload, :cancelled?
  end
end

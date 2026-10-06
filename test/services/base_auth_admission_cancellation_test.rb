# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseAuthAdmissionCancellationTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    @transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: clients(:one).public_id, session_ref: "client-session-#{SecureRandom.hex(4)}",
      required_scope: "settings_email", required_aal: StepUpRequirement::NO_AAL,
      allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:app",
    )
  end

  test "cancellation issuance persists one lookup reference and encrypted handoff without changing state" do
    issuance = BaseAuthAdmissionCoordinator.issue_cancellation!(transaction: @transaction)
    retry_issuance = BaseAuthAdmissionCoordinator.issue_cancellation!(transaction: @transaction)

    assert_equal "pending", @transaction.reload.status
    assert_equal issuance.reference, @transaction.cancellation_handoff_ref
    assert_equal issuance.handoff, @transaction.cancellation_handoff_ciphertext
    assert_nil @transaction.cancellation_handoff_digest
    assert_equal issuance.reference, retry_issuance.reference
    assert_equal issuance.handoff, retry_issuance.handoff
    assert_equal @transaction, BaseAuthAdmissionCoordinator.read_cancellation_handoff!(
      handoff: issuance.handoff, surface: "app", transaction_ref: @transaction.transaction_id,
    )
  end

  test "exact cancellation handoff remains valid after durable cancellation and rejects a different handoff" do
    issuance = BaseAuthAdmissionCoordinator.issue_cancellation!(transaction: @transaction)
    digest = BaseAuthAdmissionCoordinator.cancellation_handoff_digest(issuance.handoff)
    @transaction.commit_cancellation!(
      now: ClientStepUpCeremonyTransaction.database_now,
      cancellation_handoff_digest: digest,
    )

    assert_equal "canceled", @transaction.reload.status
    assert_equal digest, @transaction.cancellation_handoff_digest
    assert_equal @transaction, BaseAuthAdmissionCoordinator.read_cancellation_handoff!(
      handoff: issuance.handoff, surface: "app", transaction_ref: @transaction.transaction_id,
    )

    other = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: clients(:one).public_id, session_ref: "other-session-#{SecureRandom.hex(4)}",
      required_scope: "settings_email", required_aal: StepUpRequirement::NO_AAL,
      allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:app",
    )
    other_issuance = BaseAuthAdmissionCoordinator.issue_cancellation!(transaction: other)
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.read_cancellation_handoff!(
        handoff: other_issuance.handoff, surface: "app", transaction_ref: @transaction.transaction_id,
      )
    end
  end

  test "base browser marker map keeps separate transaction entries behind one opaque locator" do
    store = Valkey::AuthState::BaseStepUpMarkerStore.new
    locator = SecureRandom.urlsafe_base64(32, padding: false)
    first_ref = SecureRandom.uuid
    second_ref = SecureRandom.uuid
    expires_at = 5.minutes.from_now

    store.issue!(
      locator:, transaction_ref: first_ref, surface: "app", actor_ref: "actor-1",
      session_ref: "session-1", expires_at:,
    )
    store.issue!(
      locator:, transaction_ref: second_ref, surface: "app", actor_ref: "actor-1",
      session_ref: "session-1", expires_at:,
    )

    assert_equal first_ref, store.read(locator:, transaction_ref: first_ref).fetch("transaction_ref")
    assert_equal second_ref, store.read(locator:, transaction_ref: second_ref).fetch("transaction_ref")
  end
end

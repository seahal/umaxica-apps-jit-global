# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignUpCancellationTest < ActiveSupport::TestCase
  test "cancel records durable cleanup intent and schedules dependent records" do
    user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: user,
      raw_address: "cancel-#{SecureRandom.hex(6)}@example.com",
      confirm_policy: true,
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    cycle = create_cycle(
      principal_id: user.id,
      pending_contact_type: "email",
      pending_contact_id: email.id,
    )

    result = SignUpCancellation.call(cycle: cycle, actor_context: nil)

    assert_equal :ok, result.status
    assert_equal ClientSignUpFlowStatus::CANCELLED, cycle.reload.status_id
    assert_equal ClientSignUpFlowCleanupStatus::COMPLETED, cycle.cleanup_status_id
    assert_not_nil cycle.cleanup_completed_at
    assert_operator cycle.purge_eligible_at, :>, Time.current
    assert_equal ClientEmailStatus::DELETED, email.reload.user_email_status_id
    assert_operator email.discard_at, :<=, Time.current
    assert_operator email.purge_eligible_at, :>, Time.current
  end

  test "replayed cancel reruns cleanup when previous cleanup did not finish" do
    cycle = create_cycle(
      status_id: ClientSignUpFlowStatus::CANCELLED,
      step: "cancelled",
      cancelled_at: 1.minute.ago,
      cleanup_status_id: ClientSignUpFlowCleanupStatus::FAILED,
      cleanup_error_code: "boom",
    )

    result = SignUpCancellation.call(cycle: cycle, actor_context: nil)

    assert_equal :ok, result.status
    assert_equal ClientSignUpFlowCleanupStatus::COMPLETED, cycle.reload.cleanup_status_id
    assert_nil cycle.cleanup_error_code
  end

  test "artifact cleanup only schedules the bound pending passkey" do
    user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    telephone = ClientTelephone.create!(
      user: user,
      raw_number: "+12345670001",
      confirm_policy: true,
      confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    existing_passkey = ClientPasskey.create!(
      user: user,
      webauthn_id: "existing-#{SecureRandom.hex(8)}",
      public_key: "existing-public-key",
      sign_count: 0,
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    pending_passkey = ClientPasskey.create!(
      user: user,
      webauthn_id: "pending-#{SecureRandom.hex(8)}",
      public_key: "pending-public-key",
      sign_count: 0,
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    cycle = create_cycle(
      principal_id: user.id,
      entry_method: "telephone",
      pending_contact_type: "telephone",
      pending_contact_id: telephone.id,
      pending_passkey_registration_id: pending_passkey.id,
      status_id: ClientSignUpFlowStatus::CANCELLED,
      step: "cancelled",
      cleanup_status_id: ClientSignUpFlowCleanupStatus::PENDING,
    )
    cycle.update_columns(discard_at: cycle.created_at, purge_eligible_at: cycle.created_at + 29.minutes)

    SignUpArtifactCleanup.call(cycle: cycle)

    assert_equal ClientSignUpFlowCleanupStatus::COMPLETED, cycle.reload.cleanup_status_id
    assert_equal ClientPasskeyStatus::ACTIVE, existing_passkey.reload.status_id
    assert_predicate existing_passkey.discard_at, :infinite?
    assert_equal ClientPasskeyStatus::DELETED, pending_passkey.reload.status_id
    assert_operator pending_passkey.discard_at, :<=, Time.current
    assert_equal ClientTelephoneStatus::DELETED, telephone.reload.user_telephone_status_id
  end

  private

  def create_cycle(attrs = {})
    ClientSignUpFlow.create!(
      {
        principal_id: 123,
        status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
        step: "checkpoint",
        nonce_digest: ClientSignUpFlow.digest_nonce("nonce"),
        issued_at: Time.current,
        expires_at: 15.minutes.from_now,
        entry_method: "email",
      }.merge(attrs),
    )
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class FlowSignUpTest < ActiveSupport::TestCase
  setup do
    now = ClientSignUpFlow.database_now
    @record = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      entry_method: "email", step: "start", nonce_digest: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
      issued_at: now, expires_at: now + 15.minutes,
    )
  end

  test "predicates reflect the current real sign-up status" do
    assert_predicate @record, :sign_up_started?
    assert_not @record.sign_up_contact_pending?
    assert_not @record.sign_up_credential_pending?
    assert_not @record.sign_up_checkpoint_pending?
    assert_not @record.sign_up_completed?
    assert_predicate @record, :sign_up_in_progress?
    assert_predicate @record, :sign_up_cancelable?
    assert_not @record.sign_up_terminal?
  end

  test "class methods resolve current status ids and tolerate unknown status names" do
    assert_equal [ClientSignUpFlowStatus::STARTED], ClientSignUpFlow.sign_up_status_ids_for("STARTED", "UNKNOWN")
    assert_includes ClientSignUpFlow.sign_up_in_progress_status_ids, ClientSignUpFlowStatus::STARTED
    assert_includes ClientSignUpFlow.sign_up_cancelable_status_ids, ClientSignUpFlowStatus::STARTED
    assert_equal [100, 900, 910, 920, 930, 70, 80], ClientSignUpFlow.sign_up_terminal_status_ids
  end

  test "the cancelled predicate follows the public cancellation transition" do
    assert_not @record.sign_up_cancelled?
    @record.cancel_sign_up!

    assert_predicate @record.reload, :sign_up_cancelled?
    assert_predicate @record, :sign_up_terminal?
    assert_not @record.sign_up_cancelable?
  end

  test "advances through the real sign-up lifecycle and completes" do
    @record.advance_sign_up_to_contact!

    assert_equal [ClientSignUpFlowStatus::CONTACT_PENDING, "contact"], [@record.status_id, @record.step]
    @record.advance_sign_up_to_credential!

    assert_equal ClientSignUpFlowStatus::CREDENTIAL_PENDING, @record.status_id
    @record.verify_sign_up_contact!
    @record.advance_sign_up_to_guardrail!
    @record.advance_sign_up_to_checkpoint!

    assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, @record.status_id
    @record.begin_sign_up_finalization!
    @record.complete_sign_up!
    @record.reload

    assert_equal [ClientSignUpFlowStatus::COMPLETED, "completed"], [@record.status_id, @record.step]
    assert_predicate @record, :sign_up_completed?
    assert_not @record.sign_up_in_progress?
    assert_not @record.sign_up_cancelable?
    assert_predicate @record, :sign_up_terminal?
    assert_predicate @record.completed_at, :present?
  end

  test "discard_sign_up preserves the retention deadline" do
    deadline = @record.purge_eligible_at
    @record.discard_sign_up!(now: @record.created_at)

    assert_equal [@record.created_at, deadline], [@record.reload.discard_at, @record.purge_eligible_at]
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::OperatorSignUpFlow)
  end
end

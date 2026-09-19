# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignUpStateMachineTest < ActiveSupport::TestCase
  test "contact submission and verification advance the ticket" do
    ticket = create_cycle(ClientSignUpFlow, entry_method: "email")

    submit = SignUpStateMachine.call(ticket: ticket, event: :submit_contact, actor_context: nil)
    verify = SignUpStateMachine.call(ticket: ticket.reload, event: :verify_contact, actor_context: nil)

    assert_equal :advanced, submit.status
    assert_equal :verify_contact, submit.next_event
    assert_equal ClientSignUpFlowStatus::CONTACT_VERIFIED, ticket.reload.status_id
    assert_equal "contact_verified", ticket.step
    assert_equal :enter_guardrail, verify.next_event
  end

  test "expired tickets reject mutation before side effects" do
    ticket = create_cycle(ClientSignUpFlow, issued_at: 2.minutes.ago, expires_at: 1.minute.ago)

    result = SignUpStateMachine.call(ticket: ticket, event: :submit_contact, actor_context: nil)

    assert_equal :expired, result.status
    assert_equal ClientSignUpFlowStatus::STARTED, ticket.reload.status_id
    assert_equal "start", ticket.step
  end

  test "terminal tickets reject mutation" do
    ticket = create_cycle(
      ClientSignUpFlow,
      status_id: ClientSignUpFlowStatus::COMPLETED,
      step: "completed",
      completed_at: Time.current,
    )

    result = SignUpStateMachine.call(ticket: ticket, event: :submit_contact, actor_context: nil)

    assert_equal :invalid_transition, result.status
    assert_equal ClientSignUpFlowStatus::COMPLETED, ticket.reload.status_id
  end

  test "com tickets reject social callback events" do
    ticket = create_cycle(VisitorSignUpFlow, entry_method: "email")

    result = SignUpStateMachine.call(ticket: ticket, event: :start_social_callback, actor_context: nil)

    assert_equal :invalid_transition, result.status
    assert_equal VisitorSignUpFlowStatus::STARTED, ticket.reload.status_id
  end

  test "app social tickets can enter and complete callback for new identities" do
    ticket = create_cycle(ClientSignUpFlow, entry_method: "google")

    start = SignUpStateMachine.call(ticket: ticket, event: :start_social_callback, actor_context: nil)
    complete = SignUpStateMachine.call(ticket: ticket.reload, event: :complete_social_callback, actor_context: nil)

    assert_equal :advanced, start.status
    assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, ticket.reload.status_id
    assert_equal "checkpoint", ticket.step
    assert_equal :clear_requirement, complete.next_event
  end

  test "contact-verified tickets cannot enter the checkpoint without the guardrail" do
    ticket = create_cycle(
      ClientSignUpFlow,
      entry_method: "email",
      status_id: ClientSignUpFlowStatus::CONTACT_VERIFIED,
      step: "contact_verified",
    )

    result = SignUpStateMachine.call(ticket: ticket, event: :enter_checkpoint, actor_context: nil)

    assert_equal :invalid_transition, result.status
    assert_equal ClientSignUpFlowStatus::CONTACT_VERIFIED, ticket.reload.status_id
    assert_equal "contact_verified", ticket.step
  end

  test "checkpoint requirement clearing persists safe requirement state" do
    ticket = create_cycle(
      ClientSignUpFlow,
      entry_method: "telephone",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      completed_requirements: {
        "otp" => { "cleared" => true },
        "passkey" => { "cleared" => true },
        "passcode" => { "cleared" => true },
      },
    )

    result = SignUpStateMachine.call(
      ticket: ticket,
      event: :clear_requirement,
      actor_context: nil,
      payload: { requirement: :birthdate, checkpoint_version: ticket.checkpoint_version },
    )

    assert_equal :advanced, result.status
    assert_equal :finalize, result.next_event
    assert ticket.reload.requirement_cleared?(:birthdate)
    assert ticket.requirement_cleared?(:passkey)
  end

  test "checkpoint requirement clearing rejects out of order requirements" do
    ticket = create_cycle(
      ClientSignUpFlow,
      entry_method: "telephone",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      completed_requirements: { "otp" => { "cleared" => true } },
    )

    result = SignUpStateMachine.call(
      ticket: ticket,
      event: :clear_requirement,
      actor_context: nil,
      payload: { requirement: :birthdate, checkpoint_version: ticket.checkpoint_version },
    )

    assert_equal :invalid_transition, result.status
    assert_not ticket.reload.requirement_cleared?(:birthdate)
  end

  test "checkpoint requirement clearing rejects stale replay after requirement is clear" do
    ticket = create_cycle(
      ClientSignUpFlow,
      entry_method: "email",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      completed_requirements: {
        "otp" => { "cleared" => true },
        "birthdate" => { "cleared" => true },
      },
    )

    result = SignUpStateMachine.call(
      ticket: ticket,
      event: :clear_requirement,
      actor_context: nil,
      payload: { requirement: :birthdate, checkpoint_version: ticket.checkpoint_version },
    )

    assert_equal :invalid_transition, result.status
    assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, ticket.reload.status_id
  end

  test "clearing the last checkpoint requirement points to finalization" do
    ticket = create_cycle(
      ClientSignUpFlow,
      entry_method: "email",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      completed_requirements: { "otp" => { "cleared" => true } },
    )

    result = SignUpStateMachine.call(
      ticket: ticket,
      event: :clear_requirement,
      actor_context: nil,
      payload: { requirement: :birthdate, checkpoint_version: ticket.checkpoint_version },
    )

    assert_equal :finalize, result.next_event
    assert ticket.reload.requirement_cleared?(:birthdate)
  end

  test "checkpoint requirement clearing rejects stale checkpoint version" do
    ticket = create_cycle(
      ClientSignUpFlow,
      entry_method: "email",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      checkpoint_version: 2,
    )

    result = SignUpStateMachine.call(
      ticket: ticket,
      event: :clear_requirement,
      actor_context: nil,
      payload: { requirement: :birthdate, checkpoint_version: 1 },
    )

    assert_equal :invalid_transition, result.status
    assert_not ticket.reload.requirement_cleared?(:birthdate)
    assert_equal 2, ticket.checkpoint_version
  end

  test "finalize blocks until every required requirement is clear" do
    ticket = create_cycle(
      ClientSignUpFlow,
      entry_method: "telephone",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      completed_requirements: {
        "otp" => { "cleared" => true },
        "birthdate" => { "cleared" => true },
      },
    )

    result = SignUpStateMachine.call(ticket: ticket, event: :finalize, actor_context: nil)

    assert_equal :blocked, result.status
    assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, ticket.reload.status_id
  end

  test "finalize requires accepted typed side effect result" do
    ticket = create_cycle(
      ClientSignUpFlow,
      entry_method: "email",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      completed_requirements: {
        "otp" => { "cleared" => true },
        "birthdate" => { "cleared" => true },
      },
    )

    missing_result = SignUpStateMachine.call(ticket: ticket, event: :finalize, actor_context: nil)
    accepted = SignUpStateMachine.call(
      ticket: ticket.reload,
      event: :finalize,
      actor_context: nil,
      payload: { finalization_result: :accepted },
    )

    assert_equal :blocked, missing_result.status
    assert_equal :advanced, accepted.status
    assert_equal ClientSignUpFlowStatus::FINALIZED, ticket.reload.status_id
    assert_equal "finalized", ticket.step
  end

  test "sign-in handoff accepted then complete marks sign-up completed" do
    ticket = create_cycle(
      ClientSignUpFlow,
      entry_method: "email",
      status_id: ClientSignUpFlowStatus::FINALIZED,
      step: "finalized",
      completed_requirements: { "birthdate" => { "cleared" => true } },
    )

    handoff = SignUpStateMachine.call(
      ticket: ticket,
      event: :handoff_to_sign_in,
      actor_context: nil,
      payload: { sign_in_handoff_status: :accepted, sign_in_handoff: :boundary_result },
    )
    complete = SignUpStateMachine.call(ticket: ticket.reload, event: :complete, actor_context: nil)

    assert_equal :sign_in_handoff_accepted, handoff.status
    assert_equal :complete, handoff.next_event
    assert_equal :completed, complete.status
    assert_equal ClientSignUpFlowStatus::COMPLETED, ticket.reload.status_id
    assert_equal "completed", ticket.step
    assert_predicate ticket.completed_at, :present?
  end

  test "failed handoff does not mark durable sign-up completed" do
    ticket = create_cycle(
      ClientSignUpFlow,
      entry_method: "email",
      status_id: ClientSignUpFlowStatus::FINALIZED,
      step: "finalized",
      completed_requirements: { "birthdate" => { "cleared" => true } },
    )

    result = SignUpStateMachine.call(
      ticket: ticket,
      event: :handoff_to_sign_in,
      actor_context: nil,
      payload: { sign_in_handoff_status: :failed, sign_in_handoff: :boundary_result },
    )

    assert_equal :sign_in_handoff_failed, result.status
    assert_equal ClientSignUpFlowStatus::FINALIZED, ticket.reload.status_id
  end

  test "fail expire and cancel use terminal statuses" do
    failed = create_cycle(ClientSignUpFlow)
    expired = create_cycle(ClientSignUpFlow)
    cancelled = create_cycle(ClientSignUpFlow)

    fail_result = SignUpStateMachine.call(ticket: failed, event: :fail, actor_context: nil)
    expire_result = SignUpStateMachine.call(ticket: expired, event: :expire, actor_context: nil)
    cancel_result = SignUpStateMachine.call(ticket: cancelled, event: :cancel, actor_context: nil)

    assert_equal :failed, fail_result.status
    assert_equal ClientSignUpFlowStatus::FAILED, failed.reload.status_id
    assert_predicate failed.failed_at, :present?
    assert_equal :expired, expire_result.status
    assert_equal ClientSignUpFlowStatus::EXPIRED, expired.reload.status_id
    assert_equal :failed, cancel_result.status
    assert_equal ClientSignUpFlowStatus::CANCELLED, cancelled.reload.status_id
    assert_predicate cancelled.cancelled_at, :present?
  end

  test "cancel is rejected after finalizing starts" do
    ticket = create_cycle(
      ClientSignUpFlow,
      status_id: ClientSignUpFlowStatus::FINALIZING,
      step: "finalizing",
    )

    result = SignUpStateMachine.call(ticket: ticket, event: :cancel, actor_context: nil)

    assert_equal :invalid_transition, result.status
    assert_equal ClientSignUpFlowStatus::FINALIZING, ticket.reload.status_id
  end

  test "cancel replay on cancelled ticket is idempotent" do
    ticket = create_cycle(
      ClientSignUpFlow,
      status_id: ClientSignUpFlowStatus::CANCELLED,
      step: "cancelled",
      cancelled_at: 1.minute.ago,
    )

    result = SignUpStateMachine.call(ticket: ticket, event: :cancel, actor_context: nil)

    assert_equal :ok, result.status
    assert_equal ClientSignUpFlowStatus::CANCELLED, ticket.reload.status_id
  end

  test "failed helper builds failed result" do
    ticket = create_cycle(ClientSignUpFlow)
    machine = SignUpStateMachine.send(:new, ticket: ticket, event: :start, actor_context: nil, payload: {})

    result = machine.send(:failed, "something went wrong", cleanup_required: true)

    assert_equal :failed, result.status
    assert_includes result.errors, "something went wrong"
    assert_predicate result, :cleanup_required?
  end

  test "checkpoint_version_matches rescues invalid integer format" do
    ticket = create_cycle(ClientSignUpFlow)
    payload = { checkpoint_version: "not-a-number" }
    machine = SignUpStateMachine.send(
      :new, ticket: ticket, event: :clear_requirement,
            actor_context: nil, payload: payload,
    )

    result = machine.send(:checkpoint_version_matches?)

    assert_not result
  end

  private

  def create_cycle(cycle_class, attrs = {})
    cycle_class.create!(cycle_attrs(cycle_class).merge(attrs))
  end

  def cycle_attrs(cycle_class)
    {
      principal_id: 123,
      status_id: cycle_class::STATUS_IDS.first,
      step: cycle_class::STEPS.first,
      nonce_digest: cycle_class.digest_nonce("nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
      entry_method: "email",
    }
  end
end

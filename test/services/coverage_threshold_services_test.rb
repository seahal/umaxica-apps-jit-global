# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageThresholdServicesTest < ActiveSupport::TestCase
  test "sign-up state machine dispatches real terminal and linear transitions" do
    cases = {
      start: [[], :ok, ClientSignUpFlowStatus::STARTED],
      submit_contact: [[], :advanced, ClientSignUpFlowStatus::CONTACT_PENDING],
      verify_contact: [[:submit_contact], :advanced, ClientSignUpFlowStatus::CONTACT_VERIFIED],
      enter_guardrail: [%i(submit_contact verify_contact), :advanced, ClientSignUpFlowStatus::GUARDRAIL_PENDING],
      enter_checkpoint: [%i(submit_contact verify_contact enter_guardrail), :advanced,
                         ClientSignUpFlowStatus::CHECKPOINT_PENDING,],
      halt: [[], :failed, ClientSignUpFlowStatus::HALTED],
      expire: [[], :expired, ClientSignUpFlowStatus::EXPIRED],
      cancel: [[], :failed, ClientSignUpFlowStatus::CANCELLED],
    }
    cases.each do |event, (prior_events, expected_result, expected_status)|
      now = ClientSignUpFlow.database_now
      ticket = ClientSignUpFlow.create!(
        entry_method: "email", step: "start", nonce_digest: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
        issued_at: now - 16.minutes, expires_at: now + 15.minutes,
      )
      prior_events.each do |prior_event|
        preparation = SignUpStateMachine.call(ticket: ticket, event: prior_event, actor_context: nil)

        assert_equal :advanced, preparation.status, prior_event
      end
      if event == :expire
        # Move only the deadline; explicit expiry must not terminalize a live operation.
        ticket.update_columns(expires_at: ClientSignUpFlow.database_now - 1.second)
      end
      result = SignUpStateMachine.call(ticket: ticket, event: event, actor_context: nil)

      assert_equal [expected_result, expected_status], [result.status, ticket.reload.status_id], event
    end
  end

  test "sign-up state machine clears real requirements and completes once" do
    now = ClientSignUpFlow.database_now
    ticket = ClientSignUpFlow.create!(
      entry_method: "email", step: "start", nonce_digest: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
      issued_at: now, expires_at: now + 15.minutes,
    )
    %i(submit_contact verify_contact enter_guardrail enter_checkpoint).each do |event|
      result = SignUpStateMachine.call(ticket: ticket, event: event, actor_context: nil)

      assert_equal :advanced, result.status, event
    end
    %i(otp birthdate).each do |requirement|
      result = SignUpStateMachine.call(
        ticket: ticket, event: :clear_requirement, actor_context: nil,
        payload: { requirement: requirement, checkpoint_version: ticket.reload.checkpoint_version },
      )

      assert_equal :advanced, result.status, requirement
    end
    finalization = SignUpStateMachine.call(
      ticket: ticket, event: :finalize, actor_context: nil, payload: { finalization_result: :accepted },
    )

    assert_equal [:advanced, ClientSignUpFlowStatus::FINALIZING], [finalization.status, ticket.reload.status_id]
    assert_equal :invalid_transition, SignUpStateMachine.call(ticket: ticket, event: :cancel, actor_context: nil).status

    completion = SignUpStateMachine.call(ticket: ticket, event: :complete, actor_context: nil)

    assert_equal [:completed, true, true],
                 [completion.status, ticket.reload.sign_up_completed?, ticket.completed_at.present?]
    assert_equal :invalid_transition,
                 SignUpStateMachine.call(ticket: ticket, event: :submit_contact, actor_context: nil).status
  end

  test "sign-up state machine durably expires a real overdue ticket and refuses discarded tickets" do
    now = ClientSignUpFlow.database_now
    expired = ClientSignUpFlow.create!(
      entry_method: "email", step: "start", nonce_digest: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
      issued_at: now - 16.minutes, expires_at: now + 1.minute,
    )
    # Move only the deadline: the public state machine owns the resulting expiry transition.
    expired.update_columns(expires_at: now - 1.second)
    result = SignUpStateMachine.call(ticket: expired, event: :start, actor_context: nil)

    assert_equal [:expired, ClientSignUpFlowStatus::EXPIRED], [result.status, expired.reload.status_id]

    discarded = ClientSignUpFlow.create!(
      entry_method: "email", step: "start", nonce_digest: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
      issued_at: now, expires_at: now + 15.minutes,
    )
    discarded.discard_sign_up!(now: discarded.created_at)
    result = SignUpStateMachine.call(ticket: discarded, event: :start, actor_context: nil)

    assert_equal [:expired, ClientSignUpFlowStatus::STARTED], [result.status, discarded.reload.status_id]
  end

  test "credential inventory result exposes availability and removal predicates" do
    result = AuthenticationCredentialInventory::Result.new(
      actor: nil, excluding: nil, sign_in_methods: [:email],
      step_up_methods: [:passkey],
      uv_step_up_methods: [:passkey], contact_identifiers: [:email],
      phishing_resistant_methods: [:passkey],
    )

    assert_equal [:email], result.sign_in_methods
    assert_predicate result, :has_usable_sign_in_capability?
    assert_predicate result, :has_usable_step_up_capability?
    assert_equal [:email], result.usable_sign_in_capabilities
    assert_equal [:passkey], result.usable_step_up_capabilities
    assert_equal 1, result.usable_sign_in_capabilities.length
  end
end

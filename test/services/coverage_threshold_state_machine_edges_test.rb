# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageThresholdStateMachineEdgesTest < ActiveSupport::TestCase
  test "state machine rejects unknown events and malformed payloads" do
    now = ClientSignUpFlow.database_now
    ticket = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      entry_method: "email", step: "start", nonce_digest: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
      issued_at: now, expires_at: now + 15.minutes,
    )

    result = SignUpStateMachine.call(ticket: ticket, event: :unknown, actor_context: nil)

    assert_equal :invalid_transition, result.status
    assert_equal ClientSignUpFlowStatus::STARTED, ticket.reload.status_id
    machine = SignUpStateMachine.new(ticket: ticket, event: :start, actor_context: nil, payload: Object.new)

    assert_equal({}, machine.payload)
    assert_equal :ok, machine.call.status
    assert_equal ClientSignUpFlowStatus::STARTED, ticket.reload.status_id
  end
end

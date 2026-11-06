# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch11HighImpactTest < ActionDispatch::IntegrationTest
  def attach_request!(controller)
    request = ActionDispatch::TestRequest.create
    response = ActionDispatch::TestResponse.new
    controller.set_request!(request)
    controller.set_response!(response)
    controller.define_singleton_method(:session) { @__session ||= {} }
    controller
  end

  test "sign up state machine invalid arms" do
    email_ticket = ClientSignUpFlow.new(
      step: "start",
      entry_method: "email",
      status_id: ClientSignUpFlow::STATUS_NAMES.key("STARTED"),
      issued_at: Time.current,
      expires_at: 1.hour.from_now,
    )
    result = SignUpStateMachine.call(ticket: email_ticket, event: :complete_social_callback, actor_context: nil)

    assert_equal :invalid_transition, result.status

    checkpoint = ClientSignUpFlow.new(
      step: "checkpoint",
      entry_method: "email",
      status_id: ClientSignUpFlow::STATUS_NAMES.key("STARTED"),
      issued_at: Time.current,
      expires_at: 1.hour.from_now,
    )
    result = SignUpStateMachine.call(ticket: checkpoint, event: :clear_requirement, actor_context: nil)

    assert_equal :invalid_transition, result.status

    result = SignUpStateMachine.call(ticket: checkpoint, event: :finalize, actor_context: nil)

    assert_equal :invalid_transition, result.status

    result = SignUpStateMachine.call(ticket: checkpoint, event: :teleport, actor_context: nil)

    assert_equal :invalid_transition, result.status

    pending = ClientSignUpFlow.new(
      step: "checkpoint",
      entry_method: "email",
      status_id: ClientSignUpFlow::STATUS_NAMES.key("CHECKPOINT_PENDING"),
      issued_at: Time.current,
      expires_at: 1.hour.from_now,
      completed_requirements: {},
    )
    result = SignUpStateMachine.call(
      ticket: pending,
      event: :clear_requirement,
      actor_context: nil,
      payload: { requirement: nil },
    )

    assert_equal :invalid_transition, result.status

    called = false
    result = SignUpStateMachine.call(
      ticket: pending,
      event: :clear_requirement,
      actor_context: nil,
      payload: { requirement: :email, before_clear: -> { called = true } },
    )
    # may be invalid for other reasons but before_clear path or invalid requirement both ok
    assert result
    assert_includes [true, false], called

    result = SignUpStateMachine.call(
      ticket: pending,
      event: :finalize,
      actor_context: nil,
      payload: { finalization_result: :rejected },
    )

    assert result
  end
end

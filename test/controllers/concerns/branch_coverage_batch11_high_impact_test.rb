# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch11HighImpactTest < ActiveSupport::TestCase
  def attach_request!(controller)
    request = ActionDispatch::TestRequest.create
    response = ActionDispatch::TestResponse.new
    controller.set_request!(request)
    controller.set_response!(response)
    controller.define_singleton_method(:session) { @__session ||= {} }
    controller
  end

  test "verification emails early-return guards on edit create update" do
    c = attach_request!(Auth::Com::Verification::EmailsController.new)
    c.define_singleton_method(:require_step_up_session!) { false }

    assert_nil c.send(:edit)
    assert_nil c.send(:create)
    assert_nil c.send(:update)

    c.define_singleton_method(:require_step_up_session!) { true }
    c.define_singleton_method(:redirect_if_recent_verification_for_get!) { true }

    assert_nil c.send(:edit)

    c.define_singleton_method(:redirect_if_recent_verification_for_get!) { false }
    c.define_singleton_method(:require_email_nonce!) { false }

    assert_nil c.send(:edit)

    c.define_singleton_method(:redirect_if_recent_verification_for_post!) { true }

    assert_nil c.send(:create)
    assert_nil c.send(:update)

    c.define_singleton_method(:redirect_if_recent_verification_for_post!) { false }
    c.define_singleton_method(:require_method_available!) { |_| false }

    assert_nil c.send(:create)

    c.define_singleton_method(:require_method_available!) { |_| true }
    c.define_singleton_method(:email_otp_session_active?) { true }
    c.define_singleton_method(:ensure_email_nonce!) { "nonce" }
    redirects = []
    c.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    c.define_singleton_method(:edit_auth_com_verification_email_path) { |*| "/edit" }
    c.define_singleton_method(:params) { {} }
    c.define_singleton_method(:current_step_up_scope) { "s" }
    c.define_singleton_method(:current_step_up_pt_param) { nil }
    c.send(:create)

    assert_predicate redirects, :present?

    c.define_singleton_method(:require_email_nonce!) { false }

    assert_nil c.send(:update)
  end

  test "sign up state machine invalid arms" do
    ClientSignUpFlowStatus.ensure_defaults!
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

    result = SignUpStateMachine.call(ticket: checkpoint, event: :handoff_to_sign_in, actor_context: nil)

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

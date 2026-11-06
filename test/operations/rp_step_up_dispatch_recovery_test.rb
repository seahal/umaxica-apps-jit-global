# frozen_string_literal: true

require "test_helper"

class RpStepUpDispatchRecoveryTest < ActiveSupport::TestCase
  fixtures :clients
  self.fixture_table_names = %w(clients)

  test "dispatch just before sixty seconds remains dispatching and later recovery marks it indeterminate" do
    dispatch!
    transition = @state.transitions.find_by!(to_state_id: RpStepUpStateStatus::DISPATCHING)
    now = RpBaseAppRecord.database_now
    transition.update!(occurred_at: now - 59.seconds)

    assert_equal 0, RpBaseAppRecord.stub(:database_now, now) { RpStepUpDispatchRecovery.call(cell: @cell) }
    assert_equal RpStepUpStateStatus::DISPATCHING, @state.reload.state_id

    transition.update!(occurred_at: now - 60.seconds)

    assert_equal 1, RpBaseAppRecord.stub(:database_now, now) { RpStepUpDispatchRecovery.call(cell: @cell) }
    assert_equal RpStepUpStateStatus::INDETERMINATE, @state.reload.state_id
    assert_equal "dispatch_deadline_passed",
                 @state.transitions.find_by!(to_state_id: RpStepUpStateStatus::INDETERMINATE).reason_code
    assert_equal "dispatch_deadline_passed",
                 RpStepUpAuditOutbox.find_by!(context_ref: @state.public_id, event_type: "step_up.indeterminate")
                   .reason_code
    assert_equal 0, RpStepUpDispatchRecovery.call(cell: @cell)
  end

  test "expired pending work is terminalized with one expiration event" do
    now = RpBaseAppRecord.database_now
    @state.update!(expires_at: now)

    assert_equal 1, RpBaseAppRecord.stub(:database_now, now) { RpStepUpDispatchRecovery.call(cell: @cell) }
    assert_equal RpStepUpStateStatus::EXPIRED, @state.reload.state_id
    assert_equal 1, RpStepUpAuditOutbox.where(context_ref: @state.public_id, event_type: "step_up.expired").count
    assert_equal 0, RpStepUpDispatchRecovery.call(cell: @cell)
  end

  private

  def setup
    @actor = clients(:one)
    @cell = RpCellBinding.fetch("rp_base_app")
    issuer = OidcIssuer.for_resource_type("client")
    subject = OidcSubject.for(@actor, resource_type: "client")
    sid = SecureRandom.alphanumeric(21)
    @browser_binding = SecureRandom.urlsafe_base64(32)
    @session = RpCallbackCommitter.call(
      cell: @cell, issuer:, subject:, sid:, absolute_expires_at: 1.hour.from_now,
    ).session
    binding = RpBaseAppOpSessionBinding.includes(identity_binding: :principal).find(@session.op_session_binding_id)
    principal = binding.identity_binding.principal
    access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: principal,
      rp_session: @session,
      payload: {
        "iss" => issuer,
        "aud" => [@cell.client_id],
        "sid" => sid,
        "sub" => subject,
        "client_id" => @cell.client_id,
        AuthenticationContextValue::CLAIM => AuthenticationContextValue::NORMAL_KEY,
      },
      security_context: nil,
    )
    started = RpStepUpStartIssuer.call(
      cell: @cell,
      access_state:,
      actor: @actor,
      browser_binding: @browser_binding,
      return_target: "/settings/security",
    )
    @state = RpStepUpState.find_by!(public_id: started.state_ref)
  end

  def dispatch!
    RpStepUpStateTransitionWriter.call(cell: @cell, state_ref: @state.public_id) do |state, _session, _binding, now|
      assert_equal RpStepUpStateStatus::PENDING, state.state_id
      assert_operator state.expires_at, :>, now

      RpStepUpStateTransitionWriter::Decision.new(
        to_status_id: RpStepUpStateStatus::DISPATCHING,
        reason_code: "dispatch_started",
        event_type: nil,
        payload: nil,
        outcome: :dispatching,
      )
    end
  end
end

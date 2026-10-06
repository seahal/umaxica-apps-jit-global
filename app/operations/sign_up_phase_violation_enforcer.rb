# typed: false
# frozen_string_literal: true

# Halts a sign-up flow after a state-changing request contradicted its authoritative phase, or
# after the browser started a new flow from the entry while this one was still active.
#
# `halt` is a system decision (adr/idp-flow-lifecycle-vocabulary.md): it is never `cancel`, and no
# request parameter selects it. The violation is re-evaluated against the reloaded row under the
# flow lock, so a request that raced a legitimate advance is judged against the state that
# advance committed. A flow that has already reached a terminal state is left exactly as it is:
# a completed sign-up keeps its committed account.
class SignUpPhaseViolationEnforcer
  def self.call(flow:, surface:, reason_code:, requested_step: nil, request_id: nil)
    new(flow, surface, reason_code, requested_step, request_id).call
  end
  public_class_method :call

  public

  def initialize(flow, surface, reason_code, requested_step, request_id)
    @flow = flow
    @surface = surface.to_sym
    @reason_code = reason_code.to_s
    @requested_step = requested_step&.to_sym
    @request_id = request_id
  end

  # Returns true when this call halted the flow.
  def call
    expected_step = nil
    violating = false
    subject_present = false

    @flow.class.connection_class_for_self.connected_to(role: :writing) do
      @flow.with_cycle_lock do
        @flow.reload
        next if @flow.sign_up_terminal? || @flow.expired?(@flow.class.database_now)

        expected_step = current_step
        violating = @requested_step.nil? || expected_step != @requested_step
        subject_present = @flow.principal_id.present?
      end
    end
    return false unless violating

    # The pending actor is removed by the termination cleanup, so the audit subject is read first.
    subject = subject_present ? audit_subject : nil
    SignUpTermination.call(cycle: @flow, event: :halt)
    return false unless @flow.reload.sign_up_halted?

    SignFlowHaltRecorder.call(
      flow: @flow, subject: subject, surface: @surface, flow_kind: "sign_up", reason_code: @reason_code,
      request_id: @request_id, expected_phase: expected_step, requested_phase: @requested_step,
    )
    true
  end

  private

  def current_step
    registry = SignUpRequirementRegistry.for_ticket(@flow, surface: @surface)
    SignUpStepGate.current_step_for(@flow, registry)
  end

  def audit_subject
    case @flow
    when ClientSignUpFlow then Client.find_by(id: @flow.principal_id)
    when VisitorSignUpFlow then Visitor.find_by(id: @flow.principal_id)
    else raise ArgumentError, "unsupported sign-up flow class: #{@flow.class.name}"
    end
  end
end

# typed: false
# frozen_string_literal: true

# Performs the irreversible sign-in HALTED transition for a request that was bound to the current
# flow but no longer names its committed phase/generation. The row is reloaded and locked before
# the comparison; an old page therefore cannot halt a replacement flow and a racing valid advance
# wins or is itself rejected by the lifecycle transition graph.
class SignInPhaseViolationEnforcer
  def self.call(flow:, surface:, reason_code:, requested_phase:, request_id: nil)
    new(flow, surface, reason_code, requested_phase, request_id).call
  end
  public_class_method :call

  public

  def initialize(flow, surface, reason_code, requested_phase, request_id)
    @flow = flow
    @surface = surface.to_sym
    @reason_code = reason_code.to_s
    @requested_phase = requested_phase.to_s
    @request_id = request_id
  end

  def call
    return false unless flow

    decision = nil
    flow.with_cycle_lock do
      flow.reload
      current_phase = flow.class.state_name_for(flow.state_id)
      if sign_in_terminal?(flow) || flow.expired?(flow.class.database_now)
        decision = { halted: false, expected_phase: current_phase }
        next
      end

      flow.halt_sign_in!
      flow.reload
      decision = {
        halted: flow.sign_in_halted?,
        expected_phase: current_phase,
        # Flows are strict-loading; the halt audit reads its subject explicitly.
        subject: flow.association(:principal).scope.take,
      }
    end

    return false unless decision.is_a?(Hash) && decision[:halted]

    SignFlowHaltRecorder.call(
      flow: flow,
      subject: decision[:subject],
      surface: @surface,
      flow_kind: "sign_in",
      reason_code: @reason_code,
      request_id: @request_id,
      expected_phase: decision[:expected_phase],
      requested_phase: @requested_phase,
    )
    true
  end

  private

  attr_reader :flow

  def sign_in_terminal?(cycle)
    cycle.sign_in_completed? || cycle.sign_in_failed? || cycle.sign_in_expired? ||
      cycle.sign_in_cancelled? || cycle.sign_in_halted?
  end
end

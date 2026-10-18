# typed: false
# frozen_string_literal: true

# Behavior shared by the sign-up entry controllers (the forms that start a flow) and the step
# controllers that inherit from them.
#
# The including controller provides `sign_up_surface` and `sign_up_flow_locator`.
module SignUpFlowEntry
  extend ActiveSupport::Concern

  private

  # Query parameters that bind a generated step URL to the flow this request is serving, so the
  # server can tell which flow instance a later request from that page presumes. With no flow there
  # is nothing to bind and the step gate refuses the resulting unbound request.
  def sign_up_flow_binding_params
    flow = @sign_up_ticket || sign_up_flow_locator.current
    return {} unless flow

    { AuthIoKeys::Params::FLOW_BINDING => SignFlowBindingCodec.encode(flow: flow, surface: sign_up_surface) }
  end

  # Submitting the entry form starts a new flow instance. A flow this browser still holds is never
  # reused or silently overwritten: it is ended as HALTED (a system decision; the user expressed no
  # cancellation) and its locator is dropped, so the new flow gets its own row, public id, and
  # nonce, and nothing rendered for the earlier flow can act on the new one. This runs before the
  # new contact is created so the earlier flow's artifact cleanup cannot remove the new artifacts.
  def supersede_active_sign_up_flow!
    flow = sign_up_flow_locator.current
    return unless flow

    SignUpPhaseViolationEnforcer.call(
      flow: flow, surface: sign_up_surface, reason_code: "superseded_by_restart", request_id: request.request_id,
    )
    state = SignUpSessionState.for(session, surface: sign_up_surface)
    state.cycle_payload = nil
    state.sequence_id = nil
  end

  # The fixed refusal for a request that contradicts the authoritative flow instance or phase. The
  # body is one constant string for every cause, so the response does not disclose which phase,
  # flow, or reason was involved. It is always the Japanese copy: the contract fixes the body
  # rather than localizing it.
  def render_sign_flow_phase_refusal
    no_store
    render plain: I18n.t("errors.messages.phase_violation_refused", locale: :ja), status: :conflict
  end
end

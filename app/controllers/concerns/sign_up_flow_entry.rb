# typed: false
# frozen_string_literal: true

# Behavior shared by the sign-up entry controllers (the forms that start a flow) and the step
# controllers that inherit from them.
#
# The including controller provides `sign_up_surface` and `sign_up_flow_locator`.
module SignUpFlowEntry
  extend ActiveSupport::Concern

  private

  def current_sign_up_flow_ticket
    state = SignUpSessionState.for(session, surface: sign_up_surface)
    locator = sign_up_flow_locator
    flow = locator.current(
      admission_binding: auth_sign_up_admission_binding!, ceremony_session: admitted_auth_ceremony_session,
      public_id: state.sequence_id,
    )
    if locator.released_public_id.present? && state.sequence_id == locator.released_public_id
      state.cycle_payload = nil
      state.sequence_id = nil
    end
    flow
  end

  # Query parameters that bind a generated step URL to the flow this request is serving, so the
  # server can tell which flow instance a later request from that page presumes. With no flow there
  # is nothing to bind and the step gate refuses the resulting unbound request.
  def sign_up_flow_binding_params
    flow = @sign_up_ticket || current_sign_up_flow_ticket
    return {} unless flow

    { AuthIoKeys::Params::FLOW_BINDING => SignFlowBindingCodec.encode(flow: flow, surface: sign_up_surface) }
  end

  # Sign-up entry is fail-closed: while this browser's Admission Binding still owns an attempt that
  # is not terminal and cleaned up, a new entry submit is refused and creates nothing. Controllers
  # never terminate or clean up the earlier attempt themselves; only the background expiry and
  # cleanup jobs release it.
  def sign_up_entry_held_by_earlier_attempt?
    sign_up_flow_locator.unreleased_attempt?(
      admission_binding: auth_sign_up_admission_binding!, ceremony_session: admitted_auth_ceremony_session,
    )
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

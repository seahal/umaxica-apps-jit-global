# typed: false
# frozen_string_literal: true

# Enforces a signed sign-in flow-instance/phase binding at an HTTP boundary. The binding identifies
# the page's original flow only; SignInCycleLocator remains the browser's actor/token authority.
module SignInPhaseBindingControllerSupport
  extend ActiveSupport::Concern

  private

  def enforce_sign_in_phase_binding!(expected_phase:)
    current_flow = sign_in_phase_binding_current_flow
    binding = SignInFlowBindingCodec.decode(params[AuthIoKeys::Params::FLOW_BINDING])

    # An entry without an active flow is handled by the existing sequence gate. A supplied binding
    # without a current flow is an old/terminal observation and must never be redirected into a new
    # flow.
    return true if current_flow.nil? && binding.nil?

    unless binding
      return refuse_sign_in_phase_request!(reason_code: "missing_binding")
    end

    return refuse_sign_in_binding!("surface_mismatch", current_flow) unless
      binding.surface == sign_in_phase_binding_surface

    bound_flow = sign_in_binding_flow_class.find_by(public_id: binding.flow_public_id)
    return refuse_sign_in_binding!("flow_not_found", current_flow) unless bound_flow
    return refuse_sign_in_binding!("flow_mismatch", current_flow) unless
      current_flow&.public_id.to_s == bound_flow.public_id.to_s
    return refuse_sign_in_binding!("actor_mismatch", current_flow) unless
      sign_in_binding_actor_matches?(current_flow)

    unless Array(expected_phase).map(&:to_s).include?(binding.phase)
      return refuse_sign_in_binding_mismatch!(current_flow, binding)
    end

    return true if sign_in_binding_current?(current_flow, binding)

    refuse_sign_in_binding_mismatch!(current_flow, binding)
  end

  def refuse_sign_in_binding!(reason_code, flow)
    _ = flow
    refuse_sign_in_phase_request!(reason_code:)
  end

  def sign_in_binding_current?(flow, binding)
    flow.class.state_name_for(flow.state_id) == binding.phase &&
      flow.issued_at.utc.iso8601(6) == binding.generation &&
      flow.expires_at.to_i == binding.expires_at &&
      !flow.expired?(flow.class.database_now)
  end

  def refuse_sign_in_binding_mismatch!(flow, binding)
    if request.get? || request.head?
      return refuse_sign_in_binding!("phase_mismatch", flow)
    end

    SignInPhaseViolationEnforcer.call(
      flow: flow,
      surface: sign_in_phase_binding_surface,
      reason_code: sign_in_binding_reason_code(flow, binding),
      requested_phase: binding.phase,
      request_id: request.request_id,
    )
    refuse_sign_in_phase_request!(reason_code: sign_in_binding_reason_code(flow, binding))
  end

  def sign_in_binding_reason_code(flow, binding)
    current_phase = flow.class.state_name_for(flow.state_id)
    return "phase_violation" if current_phase == binding.phase

    current_state_id = flow.class.state_id_for(current_phase)
    requested_state_id = flow.class.state_id_for(binding.phase)
    return "phase_regression" if requested_state_id < current_state_id

    "phase_violation"
  rescue KeyError
    "phase_violation"
  end

  def refuse_sign_in_phase_request!(reason_code: "wrong_binding")
    response.headers["Cache-Control"] = "private, no-store"
    refuse_sign_in_path!(
      reason_code,
      body: I18n.t("errors.messages.phase_violation_refused"),
      status: :conflict,
      clear_continuity: false,
    )
    false
  end

  def sign_in_binding_flow_class
    SignInCycleLocator::CYCLE_CLASSES.fetch(sign_in_phase_binding_surface.to_sym)
  end

  def sign_in_primary_binding_params
    sign_in_flow_binding_params(sign_in_phase_binding_current_flow, phase: "PRIMARY_PENDING")
  end

  def sign_in_phase_binding_current_flow
    return current_db_sign_in_flow_for_sequence if auth_sign_in_phase_binding_controller?

    SignInCycleLocator.new(
      session,
      surface: sign_in_phase_binding_surface,
      actor: current_actor,
      token: current_session,
    ).current(include_terminal: true)
  end

  def sign_in_binding_actor_matches?(flow)
    return true if flow.principal_id.blank?

    # The MFA passkey/TOTP controllers prepend this guard before the normal
    # admission callbacks establish an actor object.  The pending-MFA record
    # is already the authoritative actor binding at that boundary, so compare
    # its persisted id directly instead of treating a nil pending_mfa_user as
    # a successful match after the flow principal has changed.
    if auth_sign_in_phase_binding_controller?
      pending_actor_id = pending_mfa&.[](:user_id)
      if pending_actor_id.present?
        return pending_actor_id.to_s == flow.principal_id.to_s
      end
    end

    actor = current_actor
    subject = actor.is_a?(ActorValuesContext) ? actor.subject : actor
    return false unless subject

    subject.id == flow.principal_id
  end

  def auth_sign_in_phase_binding_controller?
    is_a?(Auth::App::ApplicationController) ||
      is_a?(Auth::Com::ApplicationController) ||
      is_a?(Auth::Org::ApplicationController)
  end
end

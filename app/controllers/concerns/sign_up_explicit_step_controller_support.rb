# typed: false
# frozen_string_literal: true

module SignUpExplicitStepControllerSupport
  extend ActiveSupport::Concern

  included do
    include SignUpSequenceControllerSupport
  end

  private

  def gate_for_show
    SignUpStepGate.for_show(
      controller: self, surface: sign_up_surface, family: sign_up_family,
      step: sign_up_step,
    )
  end

  def gate_for_create
    SignUpStepGate.for_create(
      controller: self, surface: sign_up_surface, family: sign_up_family,
      step: sign_up_step,
    )
  end

  def gate_for_update
    SignUpStepGate.for_update(
      controller: self, surface: sign_up_surface, family: sign_up_family,
      step: sign_up_step,
    )
  end

  def gate_for_destroy
    SignUpStepGate.for_destroy(
      controller: self, surface: sign_up_surface, family: sign_up_family,
      step: sign_up_step,
    )
  end

  def load_gate_context!(gate)
    return refuse_sign_up_phase_request(gate) if gate.refused?

    unless gate.success?
      render_step_gate_failure(gate)
      return false
    end

    @sign_up_ticket = gate.ticket
    @sign_up_step_gate = gate
    true
  end

  # A request that contradicts the authoritative flow instance or phase is refused in place: no
  # redirect to the current step, and no side effect of the step it asked for. A safe request
  # never changes the flow. A state-changing request that this browser's current flow can be held
  # to (its binding matched; only the phase is wrong) ends that flow as HALTED. A request that
  # could not be bound to the current flow is refused without touching any flow, so a page left
  # over from an earlier flow can never halt the one that replaced it.
  def refuse_sign_up_phase_request(gate)
    if gate.phase_violation? && !request.get? && !request.head?
      SignUpPhaseViolationEnforcer.call(
        flow: gate.ticket, surface: sign_up_surface, reason_code: sign_up_phase_reason_code(gate),
        requested_step: gate.step, request_id: request.request_id,
      )
      sign_up_session_state.clear_all!
    else
      Rails.logger.info(
        JitLogEvent.format(
          "sign.signup.phase_request_refused",
          surface: sign_up_surface, refusal: gate.refusal, request_method: request.request_method,
          request_id: request.request_id,
        ),
      )
    end
    if gate.refusal == :no_active_flow && sign_up_session_state.age_restricted?
      render_sign_up_age_restricted
    else
      render_sign_flow_phase_refusal
    end
    false
  end

  # `phase_regression` when the request named a step the flow already left behind, and
  # `phase_violation` for every other mismatch (a later step, or a flow that serves no step now).
  def sign_up_phase_reason_code(gate)
    cleared = gate.registry.requirement?(gate.step) &&
      gate.registry.requirement_cleared?(gate.ticket.completed_requirements, gate.step)
    cleared ? "phase_regression" : "phase_violation"
  end

  def render_step_gate_failure(gate)
    render plain: gate.errors.to_sentence.presence || "invalid_sign_up_step", status: :unprocessable_content
  end

  def cancel_from_explicit_step
    return unless load_gate_context!(gate_for_destroy)

    result =
      if @sign_up_ticket.social_entry_method?
        SignAppUpSocialCancellation.call(cycle: @sign_up_ticket)
      else
        SignUpCancellation.call(cycle: @sign_up_ticket, actor_context: Actor.authn)
      end
    return render_sign_up_result(result) unless result.success?

    sign_up_session_state.clear_all!
    return head :no_content if request.format.json?

    redirect_to(sign_up_restart_path, status: :see_other)
  end

  def clear_current_requirement!
    result = perform_sign_up_event(
      :clear_requirement,
      payload: { requirement: sign_up_step, checkpoint_version: sign_up_checkpoint_version_param },
    )
    return finalize_sign_up_from_checkpoint! if result.success? && result.next_event == :finalize
    return render_sign_up_result(result) unless result.success?

    redirect_to(next_explicit_step_path)
  end

  def next_explicit_step_path
    next_step = @sign_up_step_gate&.registry&.next_requirement(@sign_up_ticket.completed_requirements)
    return sign_up_restart_path unless next_step

    helper = SignUpStepGate::STEP_ROUTES.fetch(sign_up_surface).fetch(sign_up_family).fetch(next_step)
    public_send(helper, **sign_up_flow_binding_params, ri: params[:ri], pt: sign_up_handoff_pt)
  end
end

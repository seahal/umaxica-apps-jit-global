# typed: false
# frozen_string_literal: true

# Shared post-OTP progression for the four contact sign-up entry points
# (app x email/telephone). Once the contact OTP is verified, the ticket
# has to travel CONTACT_PENDING -> CONTACT_VERIFIED -> GUARDRAIL_PENDING ->
# CHECKPOINT_PENDING and then clear the :otp requirement before any later
# checkpoint step (passkey, passcode, birthdate) is reachable.
#
# The requirement clearing goes through the state machine rather than writing
# `completed_requirements` directly, so the registry membership/order checks,
# the row-level lock and the `checkpoint_version` increment all apply.
module SignUpContactOtpControllerSupport
  extend ActiveSupport::Concern

  private

  def otp_resend_json_request? = request.format.json?

  def valid_otp_resend_state?
    state = params[:state]
    binding = params[AuthIoKeys::Params::FLOW_BINDING]
    state.is_a?(String) && binding.is_a?(String) && state == binding
  end

  def reject_invalid_otp_resend_state?
    return false unless otp_resend_json_request? && !valid_otp_resend_state?

    render_otp_resend_json(status: :bad_request, retry_after: 0)
    true
  end

  def render_otp_resend_json(status:, retry_after:)
    retry_after = [retry_after.ceil, 0].max
    response.headers["Retry-After"] = retry_after.to_s if status == :too_many_requests
    render json: { resendable: status == :ok, retry_after: retry_after }, status: status
  end

  def render_otp_resend_success
    render_otp_resend_json(status: :ok, retry_after: 0)
  end

  def render_otp_resend_failure
    render_otp_resend_json(status: :service_unavailable, retry_after: 0)
  end

  def render_otp_resend_issue_failure(result, cooldown_remaining:)
    return render_otp_resend_failure unless result.status == :rate_limited

    render_otp_resend_rate_limited(cooldown_remaining)
  end

  def render_otp_resend_rate_limited(cooldown_remaining)
    render_otp_resend_json(status: :too_many_requests, retry_after: [cooldown_remaining.ceil, 1].max)
  end

  def render_otp_issue_failure(result)
    if otp_resend_json_request?
      render_otp_resend_issue_failure(result, cooldown_remaining: otp_resend_cooldown_remaining_for_json)
    else
      render_otp_ceremony_result(result)
    end
  end

  def otp_resend_cooldown_remaining_for_json
    raise NotImplementedError, "OTP resend cooldown must be owned by the channel controller"
  end

  # Returns a SignUpResult. The caller owns the response: on success it should
  # finalize when `next_event == :finalize`, otherwise continue to its own next
  # step. Failures carry the state-machine status for `render_sign_up_result`.
  def advance_sign_up_after_contact_otp!
    outcome =
      @sign_up_ticket.with_cycle_lock do
        result = perform_sign_up_event(:verify_contact)
        return unexpected_sign_up_otp_transition(result, :enter_guardrail) unless result.success? &&
          result.next_event == :enter_guardrail

        result = perform_sign_up_event(:enter_guardrail)
        return unexpected_sign_up_otp_transition(result, :enter_checkpoint) unless result.success? &&
          result.next_event == :enter_checkpoint

        result = perform_sign_up_event(:enter_checkpoint)
        return unexpected_sign_up_otp_transition(result, :clear_requirement) unless result.success? &&
          result.next_event == :clear_requirement

        clear_sign_up_otp_requirement!
      end
    return outcome unless outcome.is_a?(FlowTransitionResult)

    SignUpResult.build(status: :expired, ticket: @sign_up_ticket, errors: ["ticket is expired"])
  end

  def clear_sign_up_otp_requirement!
    # The checkpoint version comes from the ticket rather than from a request
    # parameter. The stale-checkpoint guard exists to reject a clear submitted
    # from a page rendered against an older checkpoint, and this checkpoint was
    # created microseconds ago inside this same request -- there is no earlier
    # rendering for a client to replay, and the OTP itself is single-use. The
    # guard still has teeth for the concurrency case: `clear_requirement`
    # reloads the row under `with_cycle_lock` before comparing, so a version
    # bumped by a peer between our `enter_checkpoint` and this call is caught.
    perform_sign_up_event(
      :clear_requirement,
      payload: {
        requirement: :otp,
        checkpoint_version: @sign_up_ticket.checkpoint_version,
      },
    )
  end

  def unexpected_sign_up_otp_transition(result, expected_next_event)
    Rails.logger.warn(
      JitLogEvent.format(
        "sign.signup.#{sign_up_family}.otp.transition_unexpected",
        surface: sign_up_surface,
        status: result.status,
        next_event: result.next_event,
        expected_next_event: expected_next_event,
      ),
    )
    SignUpResult.build(
      status: :invalid_transition,
      ticket: @sign_up_ticket,
      errors: ["unexpected #{sign_up_family} OTP sign-up transition"],
    )
  end
end

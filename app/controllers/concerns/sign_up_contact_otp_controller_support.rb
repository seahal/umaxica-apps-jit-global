# typed: false
# frozen_string_literal: true

# Shared post-OTP progression for the four contact sign-up entry points
# (app/com x email/telephone). Once the contact OTP is verified, the ticket
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

  # Returns a SignUpResult. The caller owns the response: on success it should
  # finalize when `next_event == :finalize`, otherwise continue to its own next
  # step. Failures carry the state-machine status for `render_sign_up_result`.
  def advance_sign_up_after_contact_otp!
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

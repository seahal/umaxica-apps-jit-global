# typed: false
# frozen_string_literal: true

module BaseStepUpCancellation
  extend ActiveSupport::Concern

  private

  def cancel_step_up_ceremony!(surface:, actor:, token:, destination:)
    now = Time.current
    transaction = latest_pending_step_up_transaction(surface:, actor:, token:, now:)
    transaction&.cancel!(canceled_at: now)

    Rails.logger.info(
      JitLogEvent.format(
        "auth.step_up.canceled",
        surface: surface,
        actor_type: actor.class.name,
        canceled: transaction.present?,
      ),
    )

    # The cancellation destination is this surface's Base entry point, resolved here. A posted
    # return_to is not an authority: it was the success continuation (the page the Step-Up guards),
    # and returning there would only start the ceremony again.
    redirect_to(destination, status: :see_other)
  end

  def latest_pending_step_up_transaction(surface:, actor:, token:, now:)
    IdentityStepUpCeremonyReplayStore.for(surface).latest_pending_for(
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      required_scope: step_up_scope_for(surface),
      now: now,
    )
  end

  def step_up_scope_for(_surface)
    params[:scope].presence
  end
end

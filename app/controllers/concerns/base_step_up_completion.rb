# typed: false
# frozen_string_literal: true

module BaseStepUpCompletion
  extend ActiveSupport::Concern

  private

  def complete_step_up_ceremony!(surface:, actor:, token:, fallback:)
    now = Time.current
    result_token = params.require(:step_up_ceremony_result)
    transaction = verified_step_up_transaction!(result_token, surface: surface, actor: actor, token: token, now: now)

    consumption = IdentityStepUpCeremonyResultConsumer.new(transaction: transaction, now: now).call(result_token)
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      result_token: result_token,
      token: token,
      expected_scope: consumption.transaction.required_scope,
      expected_aal: consumption.transaction.required_aal,
      expected_method: consumption.transaction.method,
      expected_phishing_resistant: consumption.transaction.phishing_resistant_required,
      audience: step_up_audience,
      surface: surface,
      now: now,
    )

    Actor.install_context!(
      step_up: StepUpResolver.call(
        token: token,
        requirement: step_up_requirement(scope: consumption.transaction.required_scope),
        now: now,
      ),
    ) if defined?(Actor)

    return_to = consumption.transaction.return_to.presence
    flash[:notice] = I18n.t("auth.step_up.completed")
    safe_redirect_to(return_to, fallback: fallback, status: :see_other)
  rescue KeyError, ActiveRecord::RecordNotFound, IdentityStepUpCeremonyContract::Error => e
    Rails.logger.info(
      JitLogEvent.format(
        "auth.step_up.completion_failed",
        surface: surface,
        reason: e.class.name,
      ),
    )
    raise ActionController::BadRequest, "invalid step-up completion"
  end

  # Verify against the surface this controller serves before any claim reaches the database, so
  # the transaction lookup only ever sees a signed transaction_id.
  def verified_step_up_transaction!(result_token, surface:, actor:, token:, now:)
    verified = IdentityStepUpCeremonyResult.decode(
      result_token,
      issuer_id: IdentityStepUpCeremonyContract.sign_issuer_id(surface), now: now,
    )
    raise ActionController::BadRequest, "surface mismatch" unless verified["surface"].to_s == surface.to_s

    transaction =
      IdentityStepUpCeremonyReplayStore
        .for(surface)
        .find_transaction!(verified["transaction_id"].to_s)
    raise IdentityStepUpCeremonyContract::Error,
          "transaction actor mismatch" unless transaction.actor_ref == actor.public_id
    raise IdentityStepUpCeremonyContract::Error,
          "transaction session mismatch" unless transaction.session_ref == token.public_id

    transaction
  end
end

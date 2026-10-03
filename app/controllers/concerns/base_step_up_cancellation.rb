# frozen_string_literal: true

# Concrete controllers load their actor-specific transaction and choose a fixed safe destination.
# Cancellation uses the Base browser's stored reference, never a latest-pending search or scope param.
module BaseStepUpCancellation
  private

  def cancel_step_up_ceremony!(surface:, actor:, token:, destination:)
    reference = session[:base_step_up_transaction_ref]
    unless reference.is_a?(String) && reference.present?
      raise IdentityStepUpCeremonyContract::Error, "Base cancellation binding missing"
    end

    transaction = cancellation_step_up_transaction(reference)
    unless transaction.surface == surface
      raise IdentityStepUpCeremonyContract::Error, "Base cancellation surface mismatch"
    end

    canceled = IdentityStepUpCeremonyCancellationCommitter.call!(actor: actor, token: token, transaction: transaction)
    unless canceled || transaction.status == "expired"
      raise IdentityStepUpCeremonyContract::Error, "Base cancellation unavailable"
    end

    session.delete(:base_step_up_transaction_ref)
    Rails.logger.info(
      JitLogEvent.format(
        "auth.step_up.canceled", surface: surface, actor_type: actor.class.name, canceled: canceled,
      ),
    )
    redirect_to(destination, status: :see_other, allow_other_host: false)
  rescue IdentityStepUpCeremonyContract::Error, ActiveRecord::RecordNotFound
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  end
end

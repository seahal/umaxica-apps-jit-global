# frozen_string_literal: true

# Concrete controllers load their actor-specific transaction and choose a fixed safe destination.
# Cancellation uses the Base browser's stored reference, never a latest-pending search or scope param.
module BaseStepUpCancellation
  include StepUpCeremonyLogging

  private

  def cancel_step_up_ceremony!(surface:, actor:, token:, destination:)
    transaction = nil
    reference = session[:base_step_up_transaction_ref]
    unless reference.is_a?(String) && reference.present?
      raise IdentityStepUpCeremonyContract::Error.new(
        "Base cancellation binding missing",
        code: "return_binding_mismatch",
      )
    end

    transaction = cancellation_step_up_transaction(reference)
    unless transaction.surface == surface
      raise IdentityStepUpCeremonyContract::Error.new(
        "Base cancellation surface mismatch",
        code: "session_binding_mismatch",
      )
    end

    state_before = transaction.status
    canceled = IdentityStepUpCeremonyCancellationCommitter.call!(actor: actor, token: token, transaction: transaction)
    unless canceled || transaction.status == "expired"
      raise IdentityStepUpCeremonyContract::Error.new("Base cancellation unavailable", code: "transaction_unavailable")
    end

    session.delete(:base_step_up_transaction_ref)
    log_step_up_ceremony(
      "canceled", transaction: transaction, outcome: canceled ? "canceled" : "expired", surface: surface,
                  actor_type: actor.class.name, canceled: canceled, stage: "base_cancellation",
                  state_before: state_before, state_after: transaction.status,
    )
    log_step_up_return_target(
      destination, reason: "cancellation_default", protected_flow: false, transaction: transaction,
    )
    redirect_to(destination, status: :see_other, allow_other_host: false)
  rescue IdentityStepUpCeremonyContract::Error, ActiveRecord::RecordNotFound => e
    log_step_up_refusal(e, transaction: transaction, session_public_id: token.public_id, stage: "base_cancellation")
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  end
end

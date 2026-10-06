# frozen_string_literal: true

# Cancellation is initiated on Auth but is committed only by Base's same-origin POST. The
# encrypted handoff is bound to the Base browser marker and to the server-held transaction marker.
module BaseStepUpCancellation
  include StepUpCeremonyLogging
  include BaseStepUpTransactionMarker

  public

  def show
    apply_base_browser_continuation_headers!
    authorize!(cancellation_actor, to: :show?)
    handoff = cancellation_handoff_param
    lookup_reference = cancellation_lookup_reference_param
    reference = transaction_reference_param
    transaction, = BaseAuthAdmissionCoordinator.validate_cancellation_handoff!(
      handoff:, surface: cancellation_surface, transaction_ref: reference,
    )
    unless base_step_up_transaction_marker(
      reference:, surface: cancellation_surface, actor: cancellation_actor,
      token: cancellation_token,
    )
      raise BaseAuthAdmissionCoordinator::Denied.new(
        "Base cancellation marker missing",
        code: "return_binding_mismatch",
      )
    end
    unless transaction.cancellation_handoff_ref == lookup_reference
      raise BaseAuthAdmissionCoordinator::Denied.new("cancellation lookup mismatch", code: "return_binding_mismatch")
    end
    unless transaction.actor_ref == cancellation_actor.public_id && transaction.session_ref == cancellation_token.public_id
      raise BaseAuthAdmissionCoordinator::Denied.new(
        "Base cancellation session mismatch",
        code: "session_binding_mismatch",
      )
    end

    render "base/shared/cancellation_continuation", layout: false,
                                                    locals: { action_url: request.path,
                                                              cancellation_handoff: handoff,
                                                              transaction_ref: reference,
                                                              cancellation_ref: lookup_reference,
                                                              ri: params[:ri], }
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound, ArgumentError, KeyError
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  end

  private

  def cancel_step_up_ceremony!(surface:, actor:, token:, destination:)
    transaction = nil
    handoff = cancellation_handoff_param
    lookup_reference = cancellation_lookup_reference_param
    reference = transaction_reference_param
    marker = base_step_up_transaction_marker(reference:, surface:, actor:, token:)
    unless marker
      raise BaseAuthAdmissionCoordinator::Denied.new(
        "Base cancellation marker missing", code: "return_binding_mismatch",
      )
    end

    transaction = cancellation_step_up_transaction(reference)
    unless transaction.cancellation_handoff_ref == lookup_reference
      raise IdentityStepUpCeremonyContract::Error.new(
        "Base cancellation lookup mismatch", code: "return_binding_mismatch",
      )
    end
    unless transaction.surface == surface && transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id
      raise IdentityStepUpCeremonyContract::Error.new(
        "Base cancellation binding mismatch", code: "session_binding_mismatch",
      )
    end

    BaseAuthAdmissionCoordinator.read_cancellation_handoff!(
      handoff:, surface:, transaction_ref: reference,
    )
    state_before = transaction.status
    canceled = IdentityStepUpCeremonyCancellationCommitter.call!(
      actor:, token:, transaction:,
      cancellation_handoff_digest: BaseAuthAdmissionCoordinator.cancellation_handoff_digest(handoff),
    )
    unless canceled || transaction.status == "expired"
      raise IdentityStepUpCeremonyContract::Error.new("Base cancellation unavailable", code: "transaction_unavailable")
    end

    log_step_up_ceremony(
      "canceled", transaction:, outcome: canceled ? "canceled" : "expired", surface: surface,
                  actor_type: actor.class.name, canceled:, stage: "base_cancellation",
                  state_before:, state_after: transaction.status,
    )
    log_step_up_return_target(
      destination, reason: "cancellation_default", protected_flow: false, transaction: transaction,
    )
    redirect_to(destination, status: :see_other, allow_other_host: false)
  rescue BaseAuthAdmissionCoordinator::Denied, IdentityStepUpCeremonyContract::Error,
         ActiveRecord::RecordNotFound, ArgumentError, KeyError => e
    log_step_up_refusal(e, transaction:, session_public_id: token.public_id, stage: "base_cancellation")
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
    render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
  end

  def cancellation_handoff_param
    value = params[:cancellation_handoff]
    raise ActionController::BadRequest unless value.is_a?(String) && value.present?

    value
  end

  def transaction_reference_param
    value = params[:transaction_ref]
    raise ActionController::BadRequest unless value.is_a?(String) && value.present?

    value
  end

  def cancellation_lookup_reference_param
    value = params[:cancellation_ref]
    raise ActionController::BadRequest unless value.is_a?(String) && value.present?

    value
  end

  def cancellation_surface
    raise NotImplementedError
  end

  def cancellation_actor
    raise NotImplementedError
  end

  def cancellation_token
    raise NotImplementedError
  end
end

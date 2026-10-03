# frozen_string_literal: true

# Concrete Base controllers supply transaction loading and protect the exact Auth origin.
# The Base browser's stored transaction reference is required independently of the bearer result.
module BaseStepUpCompletion
  private

  def complete_step_up_ceremony!(surface:, actor:, token:)
    reference = params[:transaction_ref]
    unless reference.is_a?(String) && reference.present? &&
        session[:base_step_up_transaction_ref] == reference
      raise BaseAuthAdmissionCoordinator::Denied, "Base browser binding missing"
    end

    transaction = completion_step_up_transaction(reference)
    unless transaction.surface == surface && transaction.return_to.present?
      raise BaseAuthAdmissionCoordinator::Denied, "step-up destination missing"
    end

    requirement = step_up_requirement(
      scope: transaction.required_scope,
      allowed_methods: transaction.allowed_methods_array,
    )
    finalized = IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: actor, token: token, transaction: transaction, requirement: requirement, raw_result: params[:result],
    )
    redirect_to(finalized.return_to, status: :see_other, allow_other_host: false)
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound, IdentityStepUpCeremonyContract::Error,
         KeyError, ArgumentError
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
    render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
  end
end

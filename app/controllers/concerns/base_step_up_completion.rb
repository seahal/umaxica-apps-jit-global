# frozen_string_literal: true

# Concrete Base controllers supply transaction loading and protect the exact Auth origin.
# The Base browser's stored transaction reference is required independently of the bearer result.
module BaseStepUpCompletion
  include StepUpCeremonyLogging

  private

  def complete_step_up_ceremony!(surface:, actor:, token:)
    transaction = nil
    reference = params[:transaction_ref]
    unless reference.is_a?(String) && reference.present? &&
        session[:base_step_up_transaction_ref] == reference
      raise BaseAuthAdmissionCoordinator::Denied.new("Base browser binding missing", code: "return_binding_mismatch")
    end

    transaction = completion_step_up_transaction(reference)
    # The destination is checked before the result is consumed: an invalid target must not leave
    # the transaction terminal.
    unless transaction.surface == surface && completion_return_target_valid?(transaction)
      raise BaseAuthAdmissionCoordinator::Denied.new("step-up destination invalid", code: "return_binding_mismatch")
    end

    state_before = transaction.status
    finalized = finalize_completion_transaction!(actor: actor, token: token, transaction: transaction)
    log_step_up_ceremony(
      "completed", transaction: finalized, outcome: "completed", method: finalized.method,
                   state_before: state_before, state_after: finalized.status,
    )
    log_step_up_return_target(
      finalized.return_to, reason: "transaction_return_to", protected_flow: true, transaction: finalized,
    )
    redirect_to(finalized.return_to, status: :see_other, allow_other_host: false)
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound, IdentityStepUpCeremonyContract::Error,
         KeyError, ArgumentError => e
    log_step_up_refusal(e, transaction: transaction, session_public_id: token.public_id, stage: "base_completion")
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
    render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
  end

  # The same rule the issuer applied when it stored the target: a path of the transaction's scope.
  def completion_return_target_valid?(transaction)
    catalog =
      case transaction.surface
      when "app" then StepUpScopeCatalog::APP
      when "com" then StepUpScopeCatalog::COM
      when "org" then StepUpScopeCatalog::ORG
      else raise ArgumentError, "unsupported step-up surface: #{transaction.surface.inspect}"
      end
    pattern = catalog[transaction.required_scope]
    return_to = transaction.return_to
    pattern.present? && return_to.is_a?(String) && !return_to.match?(/[\x00-\x1F\x7F]/) && pattern.match?(return_to)
  end

  def finalize_completion_transaction!(actor:, token:, transaction:)
    requirement = step_up_requirement(
      scope: transaction.required_scope,
      allowed_methods: transaction.allowed_methods_array,
    )
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: actor, token: token, transaction: transaction, requirement: requirement, raw_result: params[:result],
    )
  end
end

# frozen_string_literal: true

# Concrete controllers provide layout, same-origin continuation and Base completion routes.
module AuthStepUpResultHandoff
  public

  def show
    return unless load_step_up_ceremony_context!
    return render_invalid_step_up_context! unless @step_up_ceremony_transaction.verified?

    render "auth/shared/oidc_authorization_handoff", layout: ceremony_result_layout,
                                                     locals: { completion_url: ceremony_result_create_path, ri: params[:ri] }
  end

  def create
    return unless load_step_up_ceremony_context!
    return render_invalid_step_up_context! unless @step_up_ceremony_transaction.verified?

    issuance = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @step_up_ceremony_transaction,
      ceremony_session_ref: current_auth_ceremony_session.id.to_s,
    )
    render "auth/shared/oidc_authorization_result", layout: ceremony_result_layout,
                                                    locals: { completion_url: ceremony_result_completion_url,
                                                              result_token: issuance.code,
                                                              transaction_ref: issuance.transaction.transaction_id,
                                                              ri: params[:ri], }
  rescue BaseAuthAdmissionCoordinator::Denied, IdentityStepUpCeremonyContract::Error
    render_invalid_step_up_context!
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
    render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
  end
end

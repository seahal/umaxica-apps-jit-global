# frozen_string_literal: true

class Auth::Org::Verification::CancellationsController < Auth::Org::ApplicationController
  include AuthStepUpCeremonyContext

  AUTHENTICATION_MODE = :open
  sign_entry_classification! :excluded, reason: "not a sign entry: ticket/re-verification ceremony or sign-out"
  declare_authentication_mode! :open

  public

  def create
    return unless load_cancellation_ceremony_context!

    issuance = BaseAuthAdmissionCoordinator.issue_cancellation!(
      transaction: @step_up_ceremony_transaction,
      ceremony_session_ref: @step_up_ceremony_session.id.to_s,
    )
    log_step_up_ceremony(
      "cancellation_handoff_issued", transaction: @step_up_ceremony_transaction, outcome: "issued",
                                     stage: "auth_cancellation", state_before: @step_up_ceremony_transaction.status,
    )
    destination =
      if issuance.transaction.required_scope == OidcAuthorizeRequestResolver::STEP_UP_SCOPE
        query = {
          step_up_cancellation_ref: issuance.reference,
          step_up_ticket_ref: issuance.transaction.transaction_id,
          step_up_context_ref: issuance.transaction.resource_ref,
          ri: params[:ri],
        }.compact.to_query
        "#{OidcIssuer.authorization_endpoint("operator")}?#{query}"
      else
        base_org_verification_cancellation_url(
          cancellation_ref: issuance.reference,
          transaction_ref: @step_up_ceremony_transaction.transaction_id, ri: params[:ri],
          host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), protocol: "https",
        )
      end
    redirect_to(destination, status: :see_other, allow_other_host: true)
  rescue BaseAuthAdmissionCoordinator::Denied, IdentityStepUpCeremonyContract::Error,
         ActiveRecord::RecordNotFound, ArgumentError => e
    log_step_up_refusal(e, transaction: @step_up_ceremony_transaction, stage: "auth_cancellation")
    render_invalid_step_up_context!
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
    render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
  end

  private

  def ceremony_actor_model = Operator

  def ceremony_step_up_session_model = OperatorStepUpSession

  def ceremony_session_token(record) = OperatorToken.find(record.staff_token_id)

  def ceremony_token_owned_by?(token, actor) = token.staff_id == actor.id && !token.standby_authentication_context?

  def ceremony_supported_methods = %i(passkey)

  def authorize_step_up_ceremony_actor!(actor)
    authorize!(actor, to: :show?, context: { user: actor })
  end
end

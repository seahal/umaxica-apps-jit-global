# frozen_string_literal: true

class Auth::Org::Verification::CancellationsController < Auth::Org::ApplicationController
  include AuthStepUpCeremonyContext

  AUTHENTICATION_MODE = :open
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
    redirect_to(
      base_org_verification_cancellation_url(
        cancellation_handoff: issuance.handoff, cancellation_ref: issuance.reference,
        transaction_ref: @step_up_ceremony_transaction.transaction_id, ri: params[:ri],
        host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), protocol: "https",
      ), status: :see_other, allow_other_host: true,
    )
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

  def ceremony_session_token(record) = record.staff_token

  def ceremony_token_owned_by?(token, actor) = token.staff_id == actor.id && !token.emergency_authentication_context?

  def ceremony_supported_methods = %i(passkey)

  def authorize_step_up_ceremony_actor!(actor)
    authorize!(actor, to: :show?, context: { user: actor })
  end
end

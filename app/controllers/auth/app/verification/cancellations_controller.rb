# frozen_string_literal: true

class Auth::App::Verification::CancellationsController < Auth::App::ApplicationController
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
      base_app_verification_cancellation_url(
        cancellation_handoff: issuance.handoff, cancellation_ref: issuance.reference,
        transaction_ref: @step_up_ceremony_transaction.transaction_id, ri: params[:ri],
        host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), protocol: "https",
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

  def ceremony_actor_model = Client

  def ceremony_step_up_session_model = ClientStepUpSession

  def ceremony_session_token(record) = record.user_token

  def ceremony_token_owned_by?(token, actor) = token.user_id == actor.id

  def ceremony_supported_methods = %i(passkey totp email_otp)

  def authorize_step_up_ceremony_actor!(actor)
    authorize!(actor, to: :show?, context: { user: actor })
  end
end

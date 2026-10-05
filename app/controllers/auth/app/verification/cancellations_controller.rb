# frozen_string_literal: true

class Auth::App::Verification::CancellationsController < Auth::App::ApplicationController
  include AuthStepUpCeremonyContext

  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  public

  def create
    return unless load_cancellation_ceremony_context!

    state_before = @step_up_ceremony_transaction.status
    canceled = IdentityStepUpCeremonyCancellationCommitter.call!(
      actor: @step_up_ceremony_actor, token: ceremony_session_token(@step_up_ceremony_session),
      transaction: @step_up_ceremony_transaction,
    )
    unless canceled
      log_step_up_ceremony(
        "refused", transaction: @step_up_ceremony_transaction, outcome: "refused", stage: "auth_cancellation",
                   error_code: "transaction_unavailable", state_before: state_before,
      )
      return render_invalid_step_up_context!
    end

    log_step_up_ceremony(
      "canceled", transaction: @step_up_ceremony_transaction, outcome: "canceled", stage: "auth_cancellation",
                  state_before: state_before, state_after: @step_up_ceremony_transaction.status,
    )
    cookies.delete(auth_ceremony_sid_cookie_name, path: "/")
    reset_session
    redirect_to_surface_url(
      base_app_dashboard_url(
        host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), ri: params[:ri],
        protocol: "https",
      ), status: :see_other,
    )
  rescue IdentityStepUpCeremonyContract::Error, ActiveRecord::RecordNotFound => e
    log_step_up_refusal(e, transaction: @step_up_ceremony_transaction, stage: "auth_cancellation")
    render_invalid_step_up_context!
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

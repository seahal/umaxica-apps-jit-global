# frozen_string_literal: true

class Auth::Org::Verification::CancellationsController < Auth::Org::ApplicationController
  include AuthStepUpCeremonyContext

  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  public

  def create
    return unless load_step_up_ceremony_context!

    canceled = IdentityStepUpCeremonyCancellationCommitter.call!(
      actor: @step_up_ceremony_actor, token: ceremony_session_token(@step_up_ceremony_session),
      transaction: @step_up_ceremony_transaction,
    )
    return render_invalid_step_up_context! unless canceled

    cookies.delete(auth_ceremony_sid_cookie_name, path: "/")
    reset_session
    redirect_to_surface_url(
      base_org_dashboard_url(
        host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), ri: params[:ri],
        protocol: "https",
      ), status: :see_other,
    )
  rescue IdentityStepUpCeremonyContract::Error, ActiveRecord::RecordNotFound
    render_invalid_step_up_context!
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

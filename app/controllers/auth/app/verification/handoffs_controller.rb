# frozen_string_literal: true

class Auth::App::Verification::HandoffsController < ::Auth::App::ApplicationController
  include AuthStepUpCeremonyContext
  include AuthStepUpResultHandoff

  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  private

  def ceremony_actor_model = Client

  def ceremony_step_up_session_model = ClientStepUpSession

  def ceremony_session_token(record) = record.user_token

  def ceremony_token_owned_by?(token, actor) = token.user_id == actor.id

  def ceremony_supported_methods = %i(passkey totp email_otp)

  def authorize_step_up_ceremony_actor!(actor)
    authorize!(actor, to: :show?, context: { user: actor })
  end

  def ceremony_result_create_path = auth_app_verification_handoff_path(ri: params[:ri])

  def ceremony_result_layout = "auth/app/application"

  def ceremony_result_completion_url
    base_app_verification_completion_url(ri: params[:ri], host: base_authority_host, protocol: "https")
  end
end

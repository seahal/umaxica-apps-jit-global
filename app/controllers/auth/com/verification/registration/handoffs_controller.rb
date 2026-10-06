# frozen_string_literal: true

class Auth::Com::Verification::Registration::HandoffsController < ::Auth::Com::ApplicationController
  include ::AuthStepUpCeremonyContext
  include ::AuthStepUpResultHandoff

  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  private

  def ceremony_actor_model = Visitor

  def ceremony_step_up_session_model = VisitorStepUpSession

  def ceremony_session_token(record) = record.visitor_token

  def ceremony_token_owned_by?(token, actor) = token.visitor_id == actor.id

  def ceremony_supported_methods = %i(passkey email_otp)

  def authorize_step_up_ceremony_actor!(actor)
    authorize!(actor, to: :show?, context: { user: actor })
  end

  def load_result_ceremony_context! = load_registration_ceremony_context!

  def ceremony_result_create_path = auth_com_verification_registration_handoff_path(ri: params[:ri])

  def ceremony_result_layout = "auth/com/application"

  def ceremony_result_completion_url(**)
    base_com_verification_completion_url(**, host: base_authority_host, protocol: "https")
  end
end

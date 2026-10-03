# frozen_string_literal: true

class Auth::Org::Verification::HandoffsController < ::Auth::Org::ApplicationController
  include AuthStepUpCeremonyContext
  include AuthStepUpResultHandoff

  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  private

  def ceremony_actor_model = Operator

  def ceremony_step_up_session_model = OperatorStepUpSession

  def ceremony_session_token(record) = record.staff_token

  def ceremony_token_owned_by?(token, actor) = token.staff_id == actor.id && !token.emergency_authentication_context?

  def ceremony_supported_methods = %i(passkey)

  def authorize_step_up_ceremony_actor!(actor)
    authorize!(actor, to: :show?, context: { user: actor })
  end

  def ceremony_result_create_path = auth_org_verification_handoff_path(ri: params[:ri])

  def ceremony_result_layout = "auth/org/application"

  def ceremony_result_completion_url
    base_org_verification_completion_url(ri: params[:ri], host: base_authority_host, protocol: "https")
  end
end

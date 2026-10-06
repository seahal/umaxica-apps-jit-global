# frozen_string_literal: true

class Auth::Org::Verification::Registration::PasskeysController < ::Auth::Org::ApplicationController
  include ::AuthPasskeyRegistrationCeremony

  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  private

  def auth_step_up_ceremony_clean_url = new_auth_org_verification_registration_passkey_path(ri: params[:ri])

  def ceremony_actor_model = Operator

  def ceremony_step_up_session_model = OperatorStepUpSession

  def ceremony_session_token(record) = record.staff_token

  def ceremony_token_owned_by?(token, actor) = token.staff_id == actor.id && !token.emergency_authentication_context?

  def ceremony_supported_methods = %i(passkey)

  def registration_passkey_association = :staff_passkeys

  def registration_component = "auth/org/verification/registration/passkeys/new"

  def registration_options_path = auth_org_verification_registration_passkey_options_path(ri: params[:ri])

  def registration_create_path = auth_org_verification_registration_passkey_path(ri: params[:ri])

  def registration_handoff_path = auth_org_verification_registration_handoff_path(ri: params[:ri])

  def registration_cancellation_path = auth_org_verification_cancellation_path(ri: params[:ri])

  def authorize_step_up_ceremony_actor!(actor)
    authorize!(actor, to: :show?, context: { user: actor })
  end
end

# frozen_string_literal: true

class Auth::Com::Verification::Registration::PasskeysController < ::Auth::Com::ApplicationController
  include ::AuthPasskeyRegistrationCeremony

  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  private

  def auth_step_up_ceremony_clean_url = new_auth_com_verification_registration_passkey_path(ri: params[:ri])

  def ceremony_actor_model = Visitor

  def ceremony_step_up_session_model = VisitorStepUpSession

  def ceremony_session_token(record) = record.visitor_token

  def ceremony_token_owned_by?(token, actor) = token.visitor_id == actor.id

  def ceremony_supported_methods = %i(passkey email_otp)

  def registration_passkey_association = :visitor_passkeys

  def registration_component = "auth/com/verification/registration/passkeys/new"

  def registration_options_path = auth_com_verification_registration_passkey_options_path(ri: params[:ri])

  def registration_create_path = auth_com_verification_registration_passkey_path(ri: params[:ri])

  def registration_handoff_path = auth_com_verification_registration_handoff_path(ri: params[:ri])

  def registration_cancellation_path = auth_com_verification_cancellation_path(ri: params[:ri])

  def authorize_step_up_ceremony_actor!(actor)
    authorize!(actor, to: :show?, context: { user: actor })
  end
end

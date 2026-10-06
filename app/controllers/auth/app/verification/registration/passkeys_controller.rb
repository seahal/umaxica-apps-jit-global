# frozen_string_literal: true

class Auth::App::Verification::Registration::PasskeysController < ::Auth::App::ApplicationController
  include ::AuthPasskeyRegistrationCeremony

  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  private

  def auth_step_up_ceremony_clean_url = new_auth_app_verification_registration_passkey_path(ri: params[:ri])

  def ceremony_actor_model = Client

  def ceremony_step_up_session_model = ClientStepUpSession

  def ceremony_session_token(record) = record.user_token

  def ceremony_token_owned_by?(token, actor) = token.user_id == actor.id

  def ceremony_supported_methods = %i(passkey totp email_otp)

  def registration_passkey_association = :client_passkeys

  def registration_component = "auth/app/verification/registration/passkeys/new"

  def registration_options_path = auth_app_verification_registration_passkey_options_path(ri: params[:ri])

  def registration_create_path = auth_app_verification_registration_passkey_path(ri: params[:ri])

  def registration_handoff_path = auth_app_verification_registration_handoff_path(ri: params[:ri])

  def registration_cancellation_path = auth_app_verification_cancellation_path(ri: params[:ri])

  def authorize_step_up_ceremony_actor!(actor)
    authorize!(actor, to: :show?, context: { user: actor })
  end
end

# typed: false
# frozen_string_literal: true

class Auth::App::Settings::Passkeys::VerificationsController < ::Auth::App::ApplicationController
  include ::VerificationClient
  include SignSettingsPasskeyRegistration
  include ::PasskeyRegistrationFlow

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  before_action :authenticate_client!
  step_up only: :create, bootstrap: true

  def create = (authorize!(ClientPasskey, to: :create?); verify_passkey_registration)

  private

  def passkey_registration_actor = current_client

  def passkey_registration_passkeys = current_client.client_passkeys

  def passkey_registration_redirect_url
    auth_app_settings_passkeys_url(ri: params[:ri], host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
  end

  def passkey_registration_log_prefix = "sign.webauthn.registration"

  def render_verification_success(passkey)
    render json: {
      status: "ok",
      passkey_id: passkey.id,
      redirect_url: bootstrap_return_path(passkey_registration_redirect_url),
    }, status: :created
  end
end

# typed: false
# frozen_string_literal: true

class Auth::App::Settings::Passkeys::OptionsController < ::Auth::App::ApplicationController
  include ::VerificationClient
  include SignSettingsPasskeyRegistration
  include ::CloudflareTurnstile
  include ::PasskeyRegistrationFlow

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  before_action :authenticate_client!
  step_up only: :create, bootstrap: true
  before_action :verify_settings_passkey_turnstile!, only: :create

  def create = (authorize!(ClientPasskey, to: :create?); render_passkey_registration_options)

  private

  def verify_settings_passkey_turnstile!
    return true if cloudflare_turnstile_stealth_validation["success"]

    respond_to do |format|
      format.html do
        redirect_to(auth_app_settings_passkeys_path(ri: params[:ri]), status: :see_other)
      end
      format.json { render json: { error: t("turnstile_error") }, status: :unprocessable_content }
    end
    false
  end

  def passkey_registration_actor = current_client

  def passkey_registration_passkeys = current_client.client_passkeys

  def passkey_registration_redirect_url
    auth_app_settings_passkeys_url(ri: params[:ri], host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
  end

  def passkey_registration_log_prefix = "sign.webauthn.registration"
end

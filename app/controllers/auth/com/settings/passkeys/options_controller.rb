# typed: false
# frozen_string_literal: true

class Auth::Com::Settings::Passkeys::OptionsController < ::Auth::Com::ApplicationController
  include ::VerificationVisitor
  include SignSettingsPasskeyRegistration
  include ::SignRequiresRecoveryPasscodes
  include ::CloudflareTurnstile
  include ::PasskeyRegistrationFlow

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  before_action :authenticate_visitor!
  step_up only: :create, bootstrap: true
  before_action :require_recovery_passcodes_for_mfa_registration!, only: :create
  before_action :verify_settings_passkey_turnstile!, only: :create

  def create = (authorize!(VisitorPasskey, to: :create?); render_passkey_registration_options)

  private

  def verify_settings_passkey_turnstile!
    return true if cloudflare_turnstile_stealth_validation["success"]

    respond_to do |format|
      format.html do
        redirect_to(auth_com_settings_passkeys_path(ri: params[:ri]), status: :see_other)
      end
      format.json { render json: { error: t("turnstile_error") }, status: :unprocessable_content }
    end
    false
  end

  def passkey_registration_actor = current_visitor

  def passkey_registration_passkeys = current_visitor.visitor_passkeys

  def passkey_registration_redirect_url
    auth_com_settings_passkeys_url(ri: params[:ri], host: ENV.fetch("PRIVATE_AUTH_CORPORATE_URL"))
  end

  def recovery_passcode_requirement_active_strong_credential_count
    current_visitor.visitor_passkeys.active.count
  end

  def recovery_passcode_requirement_actor = current_visitor

  def recovery_passcode_requirement_credential_class = VisitorSecretCredential

  def recovery_passcode_setup_url
    base_com_identity_url(
      ri: params[:ri],
      host: base_authority_host,
    )
  end

  def recovery_passcode_top_up_actor = current_visitor

  def recovery_passcode_top_up_credential_class = VisitorSecretCredential

  def recovery_passcode_reveal_redirect_url(token)
    base_com_identity_url(
      ri: params[:ri],
      token: token,
      host: base_authority_host,
    )
  end
end

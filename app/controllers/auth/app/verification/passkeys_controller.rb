# frozen_string_literal: true

class Auth::App::Verification::PasskeysController < ::Auth::App::ApplicationController
  include CloudflareTurnstile
  include SurfaceInertiaPage
  include AuthStepUpCeremonyContext
  include AuthStepUpPasskeyCeremony

  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  rate_limit to: 5, within: 1.minute, by: -> { request.remote_ip },
             scope: "auth_app_step_up", name: "passkey_options_ip_burst", only: :options,
             store: rate_limit_store, with: -> { render_rate_limited(retry_after: 60) }
  rate_limit to: 20, within: 15.minutes, by: -> { request.remote_ip },
             scope: "auth_app_step_up", name: "passkey_options_ip_sustained", only: :options,
             store: rate_limit_store, with: -> { render_rate_limited(retry_after: 900) }

  private

  def ceremony_actor_model = Client

  def ceremony_step_up_session_model = ClientStepUpSession

  def ceremony_session_token(record) = record.user_token

  def ceremony_token_owned_by?(token, actor) = token.user_id == actor.id

  def ceremony_supported_methods = %i(passkey totp email_otp)

  def ceremony_passkey_scope = @step_up_ceremony_actor.client_passkeys.active

  def ceremony_passkey_handoff_path = auth_app_verification_handoff_path(ri: params[:ri])

  def authorize_step_up_ceremony_actor!(actor)
    authorize!(actor, to: :show?, context: { user: actor })
  end

  def render_step_up_passkey_page
    render inertia: "auth/app/verification/passkeys/new", props: {
      title: t("sign.app.verification.edit.title"),
      heading: t("sign.app.verification.edit.title"),
      description: t("sign.app.verification.edit.description"),
      errors: [],
      panel: {
        options_url: auth_app_verification_passkey_options_path(ri: params[:ri]),
        verification_url: auth_app_verification_passkey_path(ri: params[:ri]),
        region: current_region_identifier.to_s,
        identifier_param: nil,
        field: nil,
        turnstile_site_key: JitSecurityTurnstileConfig.stealth_site_key.to_s,
        turnstile_error_message: t("turnstile_error"),
        submit_label: t("sign.app.verification.edit.authenticate_with_passkey"),
      },
      back: { label: t("sign.app.verification.edit.back"), href: auth_app_verification_path(ri: params[:ri]) },
      cancel: { label: t("actions.cancel"),
                action: auth_app_verification_cancellation_path(ri: params[:ri]),
                method: "post", },
    }
  end
end

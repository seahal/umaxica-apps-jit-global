# frozen_string_literal: true

class Auth::Com::Verification::PasskeysController < ::Auth::Com::ApplicationController
  include CloudflareTurnstile
  include SurfaceInertiaPage
  include AuthStepUpCeremonyContext
  include AuthStepUpPasskeyCeremony

  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  rate_limit to: 5, within: 1.minute, by: -> { request.remote_ip },
             scope: "auth_com_step_up", name: "passkey_options_ip_burst", only: :options,
             store: rate_limit_store, with: -> { render_rate_limited(retry_after: 60) }
  rate_limit to: 20, within: 15.minutes, by: -> { request.remote_ip },
             scope: "auth_com_step_up", name: "passkey_options_ip_sustained", only: :options,
             store: rate_limit_store, with: -> { render_rate_limited(retry_after: 900) }

  private

  def ceremony_actor_model = Visitor

  def ceremony_step_up_session_model = VisitorStepUpSession

  def ceremony_session_token(record) = record.visitor_token

  def ceremony_token_owned_by?(token, actor) = token.visitor_id == actor.id

  def ceremony_supported_methods = %i(passkey email_otp)

  def ceremony_passkey_scope = @step_up_ceremony_actor.visitor_passkeys.active.where("discard_at > clock_timestamp()")

  def ceremony_passkey_handoff_path = auth_com_verification_handoff_path(ri: params[:ri])

  def authorize_step_up_ceremony_actor!(actor)
    authorize!(actor, to: :show?, context: { user: actor })
  end

  def render_step_up_passkey_page
    render inertia: "auth/com/verification/passkeys/new", props: {
      title: t("sign.com.verification.edit.title"),
      heading: t("sign.com.verification.edit.title"),
      description: t("sign.com.verification.edit.description"),
      errors: [],
      panel: {
        options_url: auth_com_verification_passkey_options_path(ri: params[:ri]),
        verification_url: auth_com_verification_passkey_path(ri: params[:ri]),
        region: current_region_identifier.to_s,
        identifier_param: nil,
        field: nil,
        turnstile_site_key: JitSecurityTurnstileConfig.stealth_site_key.to_s,
        turnstile_error_message: t("turnstile_error"),
        submit_label: t("sign.com.verification.edit.authenticate_with_passkey"),
      },
      back: { label: t("sign.com.verification.edit.back"), href: auth_com_verification_path(ri: params[:ri]) },
      cancel: { label: t("actions.cancel"),
                action: auth_com_verification_cancellation_path(ri: params[:ri]),
                method: "post", },
    }
  end
end

# typed: false
# frozen_string_literal: true

class Auth::App::Verification::TotpsController < ::Auth::App::Verification::BaseController
  include ::SurfaceInertiaPage
  include ::TurnstilePageProps
  include SignVerificationTotpActions

  AUTHENTICATION_MODE = :private

  NEW_COMPONENT = "auth/app/verification/totps/new"

  # The two actions repeat SignVerificationTotpActions guard for guard, Turnstile check included.
  # Only the render differs: this surface answers with an Inertia page instead of the ERB template,
  # and the code is still posted back as a document submission, so the failure path keeps its 422.
  def new
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_get!
    return unless require_method_available!(:totp)

    render inertia: NEW_COMPONENT, props: new_page_props
  end

  def create
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_post!
    return unless require_method_available!(:totp)

    unless cloudflare_turnstile_stealth_validation["success"]
      @verification_errors = [t("turnstile_error")]
      render inertia: NEW_COMPONENT, props: new_page_props, status: :unprocessable_content
      return
    end

    if verify_totp!
      consume_step_up_session!(method: :totp)
    else
      record_failed_step_up_attempt!(:totp)
      render inertia: NEW_COMPONENT, props: new_page_props, status: :unprocessable_content
    end
  end

  private

  def new_page_props
    scope = incoming_scope.presence
    pt = incoming_pt.presence

    {
      title: t("sign.app.verification.edit.title"),
      heading: t("sign.app.verification.edit.title"),
      description: t("sign.app.verification.edit.description"),
      totp_help: t("sign.app.verification.edit.totp_help"),
      errors: Array(@verification_errors),
      form: {
        action: auth_app_verification_totp_path(ri: params[:ri]),
        csrf_token: form_authenticity_token,
        scope: scope,
        pt: pt,
        credential_selector: totp_credential_selector_props,
        code_label: t("sign.app.verification.edit.code_label"),
        code_placeholder: t("sign.app.verification.edit.code_placeholder"),
        submit_label: t("sign.app.verification.edit.submit"),
      },
      turnstile: turnstile_stealth_props,
      back: {
        label: t("sign.app.verification.edit.back"),
        href: auth_app_verification_path(ri: params[:ri], scope: scope, pt: pt),
      },
    }
  end

  def totp_credential_selector_props
    credentials = active_totp_credentials.to_a
    return unless credentials.length > 1

    {
      name: "verification[credential_public_id]",
      label: t("messages.totp_credential_label"),
      options: credentials.each_with_index.map do |credential, index|
        {
          value: credential.public_id,
          label: credential.title.presence || t("messages.totp_credential_default_label", count: index + 1),
        }
      end,
    }
  end
end

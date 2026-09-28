# typed: false
# frozen_string_literal: true

class Auth::Org::Verification::PasskeysController < ::Auth::Org::Verification::BaseController
  include SignVerificationPasskeyActions
  include ::SurfaceInertiaPage

  AUTHENTICATION_MODE = :private

  private

  # This controller's own layout is the Inertia shell, but the step-up completion page is a
  # cross-host handoff form rendered from ERB, so it keeps the surface document layout.
  def step_up_handoff_layout
    "auth/org/application"
  end

  def render_verification_passkey_page(status: :ok)
    render inertia: "auth/org/verification/passkeys/new", props: verification_passkey_props, status: status
  end

  def verification_passkey_props
    {
      title: t("sign.org.verification.edit.title"),
      description: t("sign.org.verification.edit.description"),
      errors_sentence: Array(@verification_errors).presence&.to_sentence,
      form: {
        action: auth_org_verification_passkey_path(ri: params[:ri]),
        param_scope: "verification",
        challenge_id: @passkey_challenge_id.to_s,
        request_options: @passkey_request_options.as_json,
        submit_label: t("sign.org.verification.edit.authenticate_with_passkey"),
      },
      cancel: step_up_cancellation_props,
      back_link: {
        label: t("sign.org.verification.edit.back"),
        href: auth_org_verification_path(ri: params[:ri]),
      },
    }
  end
end

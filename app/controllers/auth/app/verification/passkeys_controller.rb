# typed: false
# frozen_string_literal: true

class Auth::App::Verification::PasskeysController < ::Auth::App::Verification::BaseController
  include ::SurfaceInertiaPage
  include SignVerificationPasskeyActions

  AUTHENTICATION_MODE = :private

  NEW_COMPONENT = "auth/app/verification/passkeys/new"

  # The two actions repeat SignVerificationPasskeyActions guard for guard. Only the render differs:
  # this surface answers with an Inertia page instead of the ERB template, and the assertion is
  # still posted back as a document submission, so the failure path keeps its 422.
  def new
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_get!
    return unless require_method_available!(:passkey)

    prepare_passkey_challenge!

    render inertia: NEW_COMPONENT, props: new_page_props
  end

  def create
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_post!
    return unless require_method_available!(:passkey)

    if verify_passkey!
      consume_step_up_session!(method: :passkey)
    else
      record_failed_step_up_attempt!(:passkey)
      prepare_passkey_challenge!
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
      errors: Array(@verification_errors),
      form: {
        action: auth_app_verification_passkey_path(ri: params[:ri]),
        csrf_token: form_authenticity_token,
        scope: scope,
        pt: pt,
        challenge_id: @passkey_challenge_id.to_s,
        # The challenge the server just issued for this actor. The ERB embedded the same payload;
        # it is what `navigator.credentials.get` consumes and it carries no secret of its own.
        request_options: passkey_request_options_payload,
        submit_label: t("sign.app.verification.edit.authenticate_with_passkey"),
      },
      cancel: step_up_cancellation_props,
      back: {
        label: t("sign.app.verification.edit.back"),
        href: auth_app_verification_path(ri: params[:ri], scope: scope, pt: pt),
      },
    }
  end

  def passkey_request_options_payload
    return nil if @passkey_request_options.blank?

    JSON.parse(@passkey_request_options.to_json)
  end
end

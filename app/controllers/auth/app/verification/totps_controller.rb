# typed: false
# frozen_string_literal: true

class Auth::App::Verification::TotpsController < ::Auth::App::ApplicationController
  include ::SurfaceInertiaPage
  include ::TurnstilePageProps
  include CloudflareTurnstile
  include AuthStepUpCeremonyContext

  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  NEW_COMPONENT = "auth/app/verification/totps/new"

  public

  def new
    return unless load_totp_ceremony!

    render inertia: NEW_COMPONENT, props: new_page_props
  end

  def create
    return unless load_totp_ceremony!

    unless cloudflare_turnstile_stealth_validation["success"]
      @verification_errors = [t("turnstile_error")]
      render inertia: NEW_COMPONENT, props: new_page_props, status: :unprocessable_content
      return
    end

    input = params.expect(verification: %i(code credential_public_id))
    if IdentityStepUpTotpVerificationCommitter.call!(
      actor: @step_up_ceremony_actor, transaction: @step_up_ceremony_transaction,
      session_record: @step_up_ceremony_session, code: input[:code], credential_public_id: input[:credential_public_id],
    )
      redirect_to(auth_app_verification_handoff_path(ri: params[:ri]))
    else
      @verification_errors = [t("sign.app.verification.errors.incorrect_code")]
      render inertia: NEW_COMPONENT, props: new_page_props, status: :unprocessable_content
    end
  rescue IdentityStepUpCeremonyContract::Error
    @verification_errors = [t("sign.app.verification.errors.incorrect_code")]
    render inertia: NEW_COMPONENT, props: new_page_props, status: :unprocessable_content
  end

  private

  def new_page_props
    scope = @step_up_ceremony_transaction.required_scope
    pt = nil

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
      cancel: step_up_cancellation_props,
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

  def load_totp_ceremony!
    return false unless load_step_up_ceremony_context!
    return render_invalid_step_up_context! unless admitted_step_up_methods.include?(:totp)

    true
  end

  def active_totp_credentials
    @step_up_ceremony_actor.client_totp_credentials.where(
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
  end

  def ceremony_actor_model = Client

  def ceremony_step_up_session_model = ClientStepUpSession

  def ceremony_session_token(record) = record.user_token

  def ceremony_token_owned_by?(token, actor) = token.user_id == actor.id

  def ceremony_supported_methods = %i(passkey totp email_otp)

  def authorize_step_up_ceremony_actor!(actor)
    authorize!(actor, to: :show?, context: { user: actor })
  end

  def step_up_cancellation_props
    { label: t("actions.cancel"), action: auth_app_verification_cancellation_path(ri: params[:ri]), method: "post" }
  end
end

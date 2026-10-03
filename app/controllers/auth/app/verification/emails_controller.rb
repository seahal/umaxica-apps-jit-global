# typed: false
# frozen_string_literal: true

class Auth::App::Verification::EmailsController < ::Auth::App::ApplicationController
  include ::SurfaceInertiaPage

  include AuthStepUpCeremonyContext

  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  NEW_COMPONENT = "auth/app/verification/emails/new"
  EDIT_COMPONENT = "auth/app/verification/emails/edit"

  public

  def new
    return unless load_email_ceremony!

    render inertia: NEW_COMPONENT, props: new_page_props
  end

  def edit
    return unless load_email_ceremony!
    return render_invalid_step_up_context! unless params[:id] == @step_up_ceremony_transaction.transaction_id

    if @step_up_ceremony_session.email_delivery_state == "failed"
      @verification_errors = [t("otp.resend.failed")]
    end
    render inertia: EDIT_COMPONENT, props: edit_page_props
  end

  def create
    return unless load_email_ceremony!

    IdentityStepUpEmailCodeIssuer.call!(
      actor: @step_up_ceremony_actor, credential: ceremony_email_credential,
      transaction: @step_up_ceremony_transaction, session_record: @step_up_ceremony_session,
    )
    redirect_to(edit_auth_app_verification_email_path(@step_up_ceremony_transaction.transaction_id, ri: params[:ri]))
  rescue IdentityStepUpEmailCodeIssuer::Unavailable, IdentityStepUpCeremonyContract::Error
    @verification_errors = [t("otp.resend.failed")]
    render inertia: NEW_COMPONENT, props: new_page_props, status: :unprocessable_content
  end

  def update
    return unless load_email_ceremony!
    return render_invalid_step_up_context! unless params[:id] == @step_up_ceremony_transaction.transaction_id

    if IdentityStepUpEmailVerificationCommitter.call!(
      actor: @step_up_ceremony_actor, credential: ceremony_email_credential,
      transaction: @step_up_ceremony_transaction, session_record: @step_up_ceremony_session,
      code: email_verification_code,
    )
      redirect_to(auth_app_verification_handoff_path(ri: params[:ri]))
    else
      @verification_errors = [t("sign.app.verification.errors.incorrect_code")]
      render inertia: EDIT_COMPONENT, props: edit_page_props, status: :unprocessable_content
    end
  end

  private

  # The OTP forms stay document submissions, exactly as the ERB forms were: the server answers them
  # with either the completion hand-off document or this page re-rendered with 422, neither of which
  # is an Inertia visit. Only the rendering of the page itself moved to React.
  def new_page_props
    scope = @step_up_ceremony_transaction.required_scope
    pt = nil

    {
      title: t("sign.app.verification.new.title"),
      heading: t("sign.app.verification.new.title"),
      description: t("sign.app.verification.new.description"),
      errors: Array(@verification_errors),
      form: {
        action: auth_app_verification_emails_path(ri: params[:ri]),
        csrf_token: form_authenticity_token,
        scope: scope,
        pt: pt,
        submit_label: t("sign.app.verification.new.methods.email_otp"),
      },
      cancel: step_up_cancellation_props,
      back: {
        label: t("sign.app.verification.edit.back"),
        href: auth_app_verification_path(ri: params[:ri], scope: scope, pt: pt),
      },
    }
  end

  def edit_page_props
    {
      title: t("sign.app.verification.edit.title"),
      heading: t("sign.app.verification.edit.title"),
      description: t("sign.app.verification.edit.email_description"),
      delivery_help: t("sign.app.verification.edit.email_delivery_help"),
      errors: Array(@verification_errors),
      form: {
        action: auth_app_verification_email_path(@step_up_ceremony_transaction.transaction_id, ri: params[:ri]),
        csrf_token: form_authenticity_token,
        scope: @step_up_ceremony_transaction.required_scope,
        pt: nil,
        code_label: t("sign.app.verification.edit.code_label"),
        code_placeholder: t("sign.app.verification.edit.code_placeholder"),
        submit_label: t("sign.app.verification.edit.submit"),
      },
      resend: {
        action: auth_app_verification_email_redelivery_path(
          @step_up_ceremony_transaction.transaction_id,
          ri: params[:ri],
          scope: @step_up_ceremony_transaction.required_scope,
          pt: nil,
        ),
        csrf_token: form_authenticity_token,
        label: t("otp.resend.button"),
      },
      cancel: step_up_cancellation_props,
      back: {
        label: t("sign.app.verification.edit.back"),
        href: auth_app_verification_path(
          ri: params[:ri],
          scope: @step_up_ceremony_transaction.required_scope,
          pt: nil,
        ),
      },
    }
  end

  def load_email_ceremony!
    return false unless load_step_up_ceremony_context!
    return render_invalid_step_up_context! unless admitted_step_up_methods.include?(:email_otp)

    true
  end

  def email_verification_code
    input = params[:verification]
    input.permit(:code)[:code] if input.is_a?(ActionController::Parameters)
  end

  def ceremony_email_credential
    scope = @step_up_ceremony_actor.client_emails.where(
      user_email_status_id: [ClientEmailStatus::VERIFIED, ClientEmailStatus::VERIFIED_WITH_SIGN_UP],
    ).where("discard_at > clock_timestamp()")
    reference = @step_up_ceremony_session.email_credential_ref
    reference ? scope.find_by!(public_id: reference) : scope.order(:id).first!
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

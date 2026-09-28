# typed: false
# frozen_string_literal: true

class Auth::App::Verification::EmailsController < ::Auth::App::Verification::BaseController
  include ::SurfaceInertiaPage

  AUTHENTICATION_MODE = :private

  NEW_COMPONENT = "auth/app/verification/emails/new"
  EDIT_COMPONENT = "auth/app/verification/emails/edit"

  skip_before_action :enforce_step_up_prereqs!, only: %i(edit update)
  before_action :set_verification_navigation_context, only: %i(edit update)

  def new
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_get!
    return unless require_method_available!(:email_otp)

    unless send_email_otp!
      render inertia: NEW_COMPONENT, props: new_page_props, status: :unprocessable_content
      return
    end

    nonce = ensure_email_nonce!
    redirect_to(
      edit_auth_app_verification_email_path(
        nonce,
        ri: params[:ri],
        scope: current_step_up_scope,
        pt: current_step_up_pt_param,
      ),
    )
  end

  def edit
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_get!
    return unless require_email_nonce!

    if email_otp_session_active?
      render inertia: EDIT_COMPONENT, props: edit_page_props
      return
    end

    unless send_email_otp!
      render inertia: NEW_COMPONENT, props: new_page_props, status: :unprocessable_content
      return
    end

    render inertia: EDIT_COMPONENT, props: edit_page_props
  end

  def create
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_post!
    return unless require_method_available!(:email_otp)

    unless send_email_otp!
      render inertia: NEW_COMPONENT, props: new_page_props, status: :unprocessable_content
      return
    end

    nonce = ensure_email_nonce!
    redirect_to(
      edit_auth_app_verification_email_path(
        nonce,
        ri: params[:ri],
        scope: current_step_up_scope,
        pt: current_step_up_pt_param,
      ),
    )
  end

  def update
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_post!
    return unless require_email_nonce!
    return unless require_method_available!(:email_otp)

    if verify_email_otp!
      consume_step_up_session!(method: :email_otp)
    else
      record_failed_step_up_attempt!(:email_otp)
      render inertia: EDIT_COMPONENT, props: edit_page_props, status: :unprocessable_content
    end
  end

  private

  # The OTP forms stay document submissions, exactly as the ERB forms were: the server answers them
  # with either the completion hand-off document or this page re-rendered with 422, neither of which
  # is an Inertia visit. Only the rendering of the page itself moved to React.
  def new_page_props
    scope = incoming_scope.presence
    pt = incoming_pt.presence

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
        action: auth_app_verification_email_path(params[:id], ri: params[:ri]),
        csrf_token: form_authenticity_token,
        scope: @verification_scope,
        pt: @verification_pt,
        code_label: t("sign.app.verification.edit.code_label"),
        code_placeholder: t("sign.app.verification.edit.code_placeholder"),
        submit_label: t("sign.app.verification.edit.submit"),
      },
      resend: {
        action: auth_app_verification_email_redelivery_path(
          params[:id],
          ri: params[:ri],
          scope: @verification_scope,
          pt: @verification_pt,
        ),
        csrf_token: form_authenticity_token,
        label: t("otp.resend.button"),
      },
      cancel: step_up_cancellation_props,
      back: {
        label: t("sign.app.verification.edit.back"),
        href: auth_app_verification_path(
          ri: params[:ri],
          scope: @verification_scope,
          pt: @verification_pt,
        ),
      },
    }
  end

  def require_email_nonce!
    rs = current_step_up_session
    expected_nonce = current_email_otp_session_data&.fetch("nonce", nil)
    if rs.present? && expected_nonce.present? && params[:id] == expected_nonce
      return true
    end

    safe_redirect_to(
      auth_app_verification_path(verification_recovery_redirect_params),
      fallback: auth_app_verification_path(ri: params[:ri]),
    )
    false
  end

  def set_verification_navigation_context
    @verification_scope = incoming_scope.presence || current_step_up_scope
    @verification_pt = incoming_pt.presence || current_step_up_pt_param
  end

  def verification_email_edit_path
    edit_auth_app_verification_email_path(
      params[:id],
      ri: params[:ri],
      scope: @verification_scope,
      pt: @verification_pt,
    )
  end
end

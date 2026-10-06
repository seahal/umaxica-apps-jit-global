# typed: false
# frozen_string_literal: true

module SignEmailRegistrationFlow
  extend ActiveSupport::Concern

  # The return-target helpers (`preserve_pt`, `retrieve_pt`, `path_from_signed_pt`) are a direct
  # dependency of this flow. Base controllers authenticate through BrowserRpAuthentication, which
  # does not bring them in.
  include AuthenticationRedirects

  def new
    @user_email = ClientEmail.new
    reset_email_registration_flow!
    render_email_registration_new
  end

  def edit
    @user_email = current_registration_email
    @verification_token = params[:token]
    return render_email_registration_edit if valid_registration_email_session?

    reset_email_registration_flow!
    redirect_to(new_registration_path_with_notice)
  end

  def create
    preference_keys = email_registration_preference_keys
    email_params = email_registration_params(:raw_address, :address, :confirm_policy, *preference_keys)
    confirm_policy = email_params[:confirm_policy]
    email_address = email_params[:raw_address] || email_params[:address]

    # adr/unified-enforcement.md, Identifier attachment enforcement: an in-force
    # Identifier Effect with attachment_blocked rejects attaching this identifier to
    # an existing account, at the same enumeration-resistance discipline as the
    # ordinary validation failure.
    if email_address.present? && enforcement_blocks_email_attachment?(
      effect_class: AppEnforcementIdentifierEffect, realm: "app", email: email_address,
    )
      @user_email = ClientEmail.new
      @user_email.errors.add(:address, :blank)
      render_email_registration_new(status: :unprocessable_content)
      return
    end

    unless initiate_email_verification!(
      email_address,
      confirm_policy: confirm_policy || "1",
      email_preferences: email_params.slice(*preference_keys),
    )
      render_email_registration_new(status: :unprocessable_content)
      return
    end

    session[registration_email_session_key] = @user_email.public_id
    start_email_ceremony!(
      surface: "app",
      actor: email_registration_target_user,
      session_ref: current_session_public_id,
      candidate: @user_email,
    )

    redirect_params = build_notice_params(
      t("sign.app.registration.email.create.verification_code_sent"),
      email_registration_pt_session_key,
    )
    flash[:notice] = redirect_params.delete(:notice)
    sanitize_redirect_params!(redirect_params)
    redirect_to(after_email_registration_started_path(redirect_params))
  end

  def update
    @user_email = current_registration_email

    unless valid_registration_email_session?
      reset_email_registration_flow!
      redirect_to(new_registration_path_with_notice)
      return
    end

    unless cloudflare_turnstile_stealth_validation["success"]
      @user_email.errors.add(:base, t("turnstile_error"))
      flash.now[:alert] = t("turnstile_error")
      render_email_registration_edit(status: :unprocessable_content)
      return
    end

    submitted_code = params.dig(:user_email, :pass_code)
    submitted_code ||= params.dig(:client_email, :pass_code)
    if submitted_code.blank?
      @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.code_required"))
      render_email_registration_edit(status: :unprocessable_content)
      return
    end

    return unless complete_registration_verification!(submitted_code)

    session.delete(registration_email_session_key)
    finish_email_ceremony!(
      surface: "app",
      actor: email_registration_target_user,
      session_ref: current_session_public_id,
      candidate: @user_email,
    )
    redirect_to_surface_url(
      after_email_registration_verified_path,
      notice: t("sign.app.registration.email.update.success"),
    )
  end

  def resend
    @user_email = current_registration_email

    unless resendable_registration_email?
      reset_email_registration_flow!
      redirect_to(new_registration_path_with_notice)
      return
    end

    if @user_email.otp_cooldown_active?
      redirect_to(
        email_registration_edit_path_with_flash(:alert, t("otp.resend.too_soon")),
      )
      return
    end

    otp_code = generate_otp_for(@user_email)
    send_verification_email(otp_code)

    redirect_to(
      email_registration_edit_path_with_flash(:notice, t("otp.resend.sent")),
    )
  end

  private

  # The registration screens, as the including surface renders them. A surface that has moved them
  # to Inertia overrides these two methods and every path above follows.
  def render_email_registration_new(status: :ok)
    render :new, status: status
  end

  def render_email_registration_edit(status: :ok)
    render :edit, status: status
  end

  def build_user_email(email_address, confirm_policy, email_preferences = {})
    super
    target_user = email_registration_target_user
    @user_email.user = target_user if target_user
  end

  def email_registration_params(*permitted_keys)
    raw_params = params[:user_email].presence || params[:client_email].presence || {}
    raw_params = ActionController::Parameters.new(raw_params) unless raw_params.respond_to?(:permit)
    # `slice` first: the caller names the keys it wants and everything else in the payload
    # is deliberately ignored, so narrowing keeps those extras from reading as unpermitted.
    raw_params.slice(*permitted_keys).permit(*permitted_keys)
  end

  def email_registration_verification_token
    params.dig(:user_email, :token) || params.dig(:client_email, :token)
  end

  def email_registration_preference_keys
    %i(promotional notifiable)
  end

  def create_pending_user!
    target_user = email_registration_target_user
    return super unless target_user

    @user_email.user = target_user
  end

  def current_registration_email
    user_email = ClientEmail.find_by(public_id: session[registration_email_session_key])
    return user_email if user_email.present?

    target_user = email_registration_target_user
    return nil unless target_user

    user_email =
      target_user
        .client_emails
        .where(user_email_status_id: pending_email_status_ids)
        .order(created_at: :desc)
        .first

    if user_email
      session[registration_email_session_key] = user_email.public_id
    end

    user_email
  end

  def valid_registration_email_session?
    @user_email.present? &&
      !@user_email.otp_expired? &&
      pending_email_status?(@user_email)
  end

  def resendable_registration_email?
    @user_email.present? &&
      !@user_email.locked? &&
      pending_email_status?(@user_email)
  end

  def complete_registration_verification!(submitted_code)
    result =
      complete_email_verification!(
        @user_email.public_id, submitted_code,
        email_registration_verification_token,
        commit_verified_status: false,
      )

    if result == :locked
      reset_email_registration_flow!
      flash[:alert] = t("sign.app.registration.email.update.attempts_exceeded")
      redirect_to(new_email_registration_path)
      return false
    elsif !result
      render_email_registration_edit(status: :unprocessable_content)
      return false
    end

    true
  end

  def registration_email_session_key
    :email_registration_public_id
  end

  def reset_email_registration_flow!
    session.delete(registration_email_session_key)
    reset_email_ceremony_session! if respond_to?(:reset_email_ceremony_session!, true)
    reset_email_flow!
  end

  def new_registration_path_with_notice
    redirect_params = build_notice_params(
      t("sign.app.registration.email.edit.session_expired"),
      email_registration_pt_session_key,
    )
    flash[:notice] = redirect_params.delete(:notice)
    new_email_registration_path(redirect_params)
  end

  def email_registration_return_path(default_path)
    encoded = retrieve_pt(email_registration_pt_session_key)
    return default_path if encoded.blank?

    path_from_signed_pt(encoded) || default_path
  end

  def preserve_email_registration_redirect_parameter
    preserve_pt(email_registration_pt_session_key)
  end

  def email_registration_pt_session_key
    :email_registration_pt
  end

  def sanitize_redirect_params!(redirect_params)
    return if redirect_params[:pt].blank?

    redirect_params[:pt] = sanitize_encoded_redirect(redirect_params[:pt])
    redirect_params.delete(:pt) if redirect_params[:pt].blank?
  end

  def email_registration_edit_path_with_flash(message_key, message)
    redirect_params = build_redirect_params(message_key, message, email_registration_pt_session_key)
    flash[message_key] = redirect_params.delete(message_key)
    sanitize_redirect_params!(redirect_params)
    after_email_registration_started_path(redirect_params)
  end

  def sanitize_encoded_redirect(encoded_url)
    signed_pt_token(encoded_url)
  end

  def on_email_registration_verified!(*)
    nil
  end

  def email_registration_target_user
    raise NotImplementedError, "#{self.class} must implement #email_registration_target_user"
  end

  def after_email_registration_started_path(_params = {})
    raise NotImplementedError, "#{self.class} must implement #after_email_registration_started_path"
  end

  def new_email_registration_path(_params = {})
    raise NotImplementedError, "#{self.class} must implement #new_email_registration_path"
  end

  def after_email_registration_verified_path
    raise NotImplementedError, "#{self.class} must implement #after_email_registration_verified_path"
  end
end

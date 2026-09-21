# typed: false
# frozen_string_literal: true

module SignEmailOtpVerificationSupport
  extend ActiveSupport::Concern

  EMAIL_OTP_RESEND_COOLDOWN = StepUpCooldowns::WINDOWS.fetch(:email_otp)

  private

  def verification_params
    params.fetch(:verification, {}).permit(
      :code, :challenge_id, :credential_json, :scope, :pt,
    )
  end

  def email_otp_session_active?
    current_email_otp_session_data.present?
  end

  def ensure_email_nonce!
    data = current_email_otp_session_data || {}
    nonce = data["nonce"].presence || SecureRandom.urlsafe_base64(16)
    write_email_otp_session_data!(data.merge("nonce" => nonce))
    nonce
  end

  def current_step_up_scope
    current_step_up_session&.scope
  end

  def current_step_up_pt_param
    return_to = current_step_up_session&.return_to
    return if return_to.blank?

    issue_step_up_pt(return_to)
  end

  def verification_recovery_redirect_params
    attrs = { ri: params[:ri] }

    scope = incoming_scope
    attrs[:scope] = scope if scope.present?

    pt = incoming_pt
    attrs[:pt] = pt if pt.present?

    attrs
  end

  def restore_step_up_session_from_params!
    scope = incoming_scope
    pt = incoming_pt
    return false if scope.blank? || pt.blank?

    start_step_up_session!(scope: scope, pt_param: pt)
    true
  rescue ActionController::BadRequest
    false
  end

  def incoming_scope
    verification_params[:scope].to_s.presence ||
      request_parameters["scope"].to_s.presence
  end

  def incoming_pt
    verification_params[:pt].to_s.presence ||
      request_parameters["pt"].to_s.presence
  end

  def request_parameters
    return request.parameters if respond_to?(:request, true) && request.respond_to?(:parameters)
    return params if respond_to?(:params, true)

    {}
  end

  def clear_step_up_state!
    session.delete(email_otp_session_key) if step_up_session_storage_available?
  end

  def verify_email_otp!
    code = verification_params[:code].to_s
    unless code.match?(/\A\d{6}\z/)
      @verification_errors = [I18n.t("sign.app.verification.errors.invalid_code")]
      return false
    end

    data = raw_email_otp_session_data
    unless data
      @verification_errors = [I18n.t("sign.app.verification.errors.resend_required")]
      return false
    end

    if current_step_up_session.discard_at <= Time.current
      @verification_errors = [I18n.t("sign.app.verification.errors.code_expired")]
      return false
    end

    unless secure_email_otp_match?(data["otp_digest"], code)
      @verification_errors = [I18n.t("sign.app.verification.errors.incorrect_code")]
      return false
    end

    true
  end

  def write_email_otp_session_data!(data)
    return unless current_step_up_session && step_up_session_storage_available?

    session[email_otp_session_key] = data.merge(
      "step_up_session_id" => current_step_up_session.id,
      "expires_at" => current_step_up_session.discard_at.to_i,
    )
  end

  def current_email_otp_session_data
    data = raw_email_otp_session_data
    return nil unless data
    return clear_and_return_nil_email_otp_session unless data["expires_at"].to_i > Time.current.to_i

    data
  end

  def raw_email_otp_session_data
    rs = current_step_up_session
    return nil unless rs && step_up_session_storage_available?

    data = session[email_otp_session_key]
    return nil unless data.is_a?(Hash)
    return clear_and_return_nil_email_otp_session unless data["step_up_session_id"] == rs.id

    data
  end

  def clear_and_return_nil_email_otp_session
    clear_step_up_state!
    nil
  end

  def step_up_session_storage_available?
    respond_to?(:session, true) && !session.nil?
  end

  def email_otp_session_key
    :sign_step_up_email_otp
  end

  def email_otp_digest(code)
    OpenSSL::HMAC.hexdigest(
      "SHA256",
      Rails.application.secret_key_base,
      "#{current_step_up_session.id}:#{code}",
    )
  end

  def secure_email_otp_match?(expected_digest, code)
    return false if expected_digest.blank?

    ActiveSupport::SecurityUtils.secure_compare(expected_digest, email_otp_digest(code))
  end

  def email_otp_resend_rate_limited?
    data = current_email_otp_session_data
    data.present? && data["resend_available_at"].to_i > Time.current.to_i
  end

  def stamp_email_otp_resend!
    write_email_otp_session_data!(
      (current_email_otp_session_data || {}).merge(
        "resend_available_at" => EMAIL_OTP_RESEND_COOLDOWN.from_now.to_i,
      ),
    )
  end
end

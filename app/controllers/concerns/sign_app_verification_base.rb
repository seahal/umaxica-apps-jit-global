# typed: false
# frozen_string_literal: true

module SignAppVerificationBase
  extend ActiveSupport::Concern

  STEP_UP_TTL = 15.minutes
  EMAIL_OTP_RESEND_COOLDOWN = StepUpCooldowns::WINDOWS.fetch(:email_otp)

  ALLOWED_SCOPES = StepUpScopeCatalog::APP

  private

  def verification_params
    # `slice` first: this reads a fixed set of keys out of the verification payload and
    # ignores anything else it carries. Permitting without narrowing would report those
    # extras as unpermitted, which they are not - they are simply not ours.
    keys = %i(code challenge_id credential_json credential_public_id scope pt)
    params.fetch(:verification, {}).slice(*keys).permit(*keys)
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

  def valid_step_up_session?(rs)
    rs.present? &&
      rs.discard_at > Time.current &&
      rs.user_token_id == actor_token.id &&
      rs.status == "PENDING" &&
      rs.scope.present? &&
      rs.return_to.present?
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

  def step_up_session_model = ClientStepUpSession

  def step_up_session_token_foreign_key = :user_token_id

  def handle_invalid_step_up_session!
    clear_step_up_state!
    destroy_current_step_up_session!

    if restore_step_up_session_from_params! && valid_step_up_session?(current_step_up_session)
      return true
    end

    safe_redirect_to(
      auth_app_settings_path(ri: params[:ri]),
      fallback: auth_app_root_path(ri: params[:ri]),
      alert: I18n.t("auth.step_up.session_expired"),
    )
    false
  end

  def verification_unavailable_redirect_path
    auth_app_verification_path(ri: params[:ri])
  end

  def clear_step_up_state!
    session.delete(email_otp_session_key) if step_up_session_storage_available?
  end

  def verification_model
    ClientVerification
  end

  def verification_success_event_id
    ClientChronicleEvent::STEP_UP_VERIFIED
  end

  def verification_success_notice_key
    "sign.app.verification.success.complete"
  end

  def verification_success_fallback_path
    auth_app_verification_path(ri: params[:ri])
  end

  def verification_audit_event_class = ClientChronicleEvent

  def verification_audit_level_class = ClientChronicleLevel

  def verification_default_activity_level_id = ClientChronicleLevel::NOTHING

  def verification_activity_model = ClientChronicle

  def current_verification_actor = current_client

  def verification_actor_type = "Client"

  def verification_passkeys_scope
    current_client.client_passkeys
  end

  def verification_passkey_model
    ClientPasskey
  end

  def passkey_actor_matches?(passkey)
    passkey.user_id == current_client.id
  end

  def verification_no_passkey_i18n_key
    "sign.app.verification.errors.no_passkey"
  end

  def active_totp_credentials
    current_client.client_totp_credentials
      .where(user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
      .order(created_at: :desc)
  end

  def send_email_otp!
    user_email =
      current_client.client_emails.where(
        user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES,
      ).order(created_at: :desc).first
    unless user_email
      @verification_errors = [I18n.t("sign.app.verification.errors.email_not_verified")]
      return false
    end

    _secret_credential, _counter, pass_code = generate_hotp_code
    write_email_otp_session_data!(
      (current_email_otp_session_data || {}).merge(
        "otp_digest" => email_otp_digest(pass_code),
      ),
    )

    enqueue_step_up_email_otp!(
      hotp_token: pass_code,
      record: user_email,
      public_id: current_client.public_id,
    )

    true
  end

  def enqueue_step_up_email_otp!(hotp_token:, record:, public_id:)
    SolidQueue::Record.connected_to(role: :writing) do
      OtpAdapter.for(surface: :app, channel: :email).deliver(
        record: record,
        otp_code: hotp_token,
        public_id: public_id,
        verification_token: nil,
      )
    end
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

  def email_otp_session_key
    :sign_app_step_up_email_otp
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

  def write_email_otp_session_data!(data)
    return unless current_step_up_session && step_up_session_storage_available?

    session[email_otp_session_key] = data.merge(
      "step_up_session_id" => current_step_up_session.id,
      "expires_at" => current_step_up_session.discard_at.to_i,
    )
  end

  def clear_and_return_nil_email_otp_session
    clear_step_up_state!
    nil
  end

  def step_up_session_storage_available?
    respond_to?(:session, true) && !session.nil?
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

# typed: false
# frozen_string_literal: true

module SignTelephoneRegistrable
  extend ActiveSupport::Concern

  TELEPHONE_VERIFICATION_RATE_LIMIT = 5
  TELEPHONE_VERIFICATION_RATE_WINDOW = 60

  # Initiates SMS OTP verification for a telephone number.
  # Returns true on success, false on failure (user blank or validation error).
  # Raises ActionController::TooManyRequests if rate limit is exceeded.
  def initiate_telephone_verification(user, number, auto_accept_confirmations: false)
    return false if user.blank?

    check_telephone_verification_rate_limit!(number)

    # Compute digest once and reuse for both lookup and stale-record cleanup.
    digest = IdentifierBlindIndex.bidx_for_telephone(number)
    existing_user_telephone = digest.present? ? user.client_telephones.find_by(number_digest: digest) : nil

    @user_telephone = existing_user_telephone || user.client_telephones.build(raw_number: number)
    @user_telephone.raw_number = number if existing_user_telephone
    @user_telephone.user_telephone_status_id = ClientTelephoneStatus::UNVERIFIED
    if auto_accept_confirmations
      @user_telephone.confirm_policy = true
      @user_telephone.confirm_using_mfa = true
    end

    # Delete any stale unverified records for this number before creating a new one.
    if digest.present? && existing_user_telephone.blank?
      ClientTelephone.where(
        number_digest: digest,
        user_id: user.id,
        user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
      ).destroy_all
    end

    otp_number = generate_otp_attributes(@user_telephone)

    unless @user_telephone.valid?
      return false
    end

    @user_telephone.save!

    send_telephone_verification_sms(@user_telephone, otp_number)

    true
  end

  # complete_telephone_verification returns one of: :success, :session_expired, :invalid_code, :locked
  def complete_telephone_verification(id, submitted_code)
    @user_telephone = ClientTelephone.find_by(id: id)
    if @user_telephone.blank? ||
        @user_telephone.otp_expired? ||
        @user_telephone.user_telephone_status_id != ClientTelephoneStatus::UNVERIFIED
      return :session_expired
    end

    result = verify_otp_code_and_consume(@user_telephone, submitted_code)

    unless result[:success]
      if @user_telephone.locked?
        @user_telephone.destroy!
        return :locked
      end
      # NOTE: This key is scoped to the registration flow. If this concern is
      # ever reused in recovery/MFA contexts, add a per-caller i18n key instead.
      @user_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.invalid_code"))
      return :invalid_code
    end

    # sign/id verifies the OTP; acme/www performs the final account commit.
    :success
  end

  def send_telephone_verification_sms(user_telephone, otp_number)
    OtpAdapter.for(surface: :app, channel: :telephone).deliver(
      record: user_telephone,
      otp_code: otp_number,
      message_style: :localized_verification,
    )
  end

  private

  def check_telephone_verification_rate_limit!(number = nil)
    phone_digest = IdentifierBlindIndex.bidx_for_telephone(number).presence || "unknown"
    cache_key = "rate-limit:telephone_verification:ip:#{request.remote_ip}:phone:#{phone_digest}"
    count = Rails.configuration.x.rate_limit.fetch(:store).increment(
      cache_key,
      1,
      expires_in: TELEPHONE_VERIFICATION_RATE_WINDOW.seconds,
    )
    return unless count && count > TELEPHONE_VERIFICATION_RATE_LIMIT

    AuthenticationSecurityEventEmitter.emit(
      "rate_limit.exceeded",
      severity: "warning",
      reason_code: "telephone_verification_rate_limit",
      ip: request.remote_ip,
      phone_digest: phone_digest,
      retry_after: TELEPHONE_VERIFICATION_RATE_WINDOW,
    )
    raise ActionController::TooManyRequests
  end
end

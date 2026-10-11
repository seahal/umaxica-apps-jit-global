# typed: false
# frozen_string_literal: true

module SignOperatorTelephoneRegistrable
  extend ActiveSupport::Concern

  TELEPHONE_VERIFICATION_RATE_LIMIT = 5
  TELEPHONE_VERIFICATION_RATE_WINDOW = 60
  VERIFIED_STAFF_TELEPHONE_STATUSES = [
    OperatorTelephoneStatus::ACTIVE,
    OperatorTelephoneStatus::VERIFIED,
  ].freeze

  private

  def initiate_staff_telephone_verification(staff, number)
    return false if staff.blank?

    check_staff_telephone_verification_rate_limit!

    probe = staff.staff_telephones.build(raw_number: number, confirm_policy: true, confirm_using_mfa: true)
    normalized_number = TelephoneNormalization.normalize_to_e164(number)
    if normalized_number.blank?
      probe.validate
      @staff_telephone = probe
      return false
    end

    existing = staff.staff_telephones.detect { |telephone| telephone.number == normalized_number }
    if existing && existing.staff_telephone_status_id != OperatorTelephoneStatus::UNVERIFIED
      probe.errors.add(:raw_number, :taken)
      @staff_telephone = probe
      return false
    end

    probe.validate unless existing
    @staff_telephone = probe
    return false if probe.errors.any?

    @staff_telephone = existing || probe
    @staff_telephone.raw_number = number
    @staff_telephone.confirm_policy = true
    @staff_telephone.confirm_using_mfa = true
    return false unless @staff_telephone.valid?

    @staff_telephone.save!
    issued = TelephoneCredentialRegistrationOtpIssuer.call(
      actor: staff, token: current_session_token, telephone: @staff_telephone,
      browser_nonce: ensure_base_admission_browser_nonce!,
    )
    return false unless issued.success?

    session[:settings_telephone_registration_transaction_ref] = issued.transaction.transaction_id
    send_staff_telephone_verification_sms(@staff_telephone, issued)

    true
  end

  def complete_staff_telephone_verification(id, submitted_code)
    return :session_expired unless @staff_telephone && @staff_telephone.id == id && registration_otp_transaction

    result = TelephoneCredentialRegistrationOtpVerificationCommitter.call(
      actor: current_operator, token: current_session_token, telephone: @staff_telephone,
      transaction: registration_otp_transaction, browser_nonce: base_admission_browser_nonce, code: submitted_code,
    )
    return :success if result.verified_evidence?
    return :session_expired if %i(unavailable result_expired session_mismatch locked).include?(result.status)

    @staff_telephone.errors.add(:pass_code, I18n.t("sign.org.registration.telephone.update.invalid_code"))
    :invalid_code
  end

  private

  def send_staff_telephone_verification_sms(staff_telephone, issued)
    OtpAdapter.for(surface: :org, channel: :telephone).deliver(
      record: staff_telephone,
      otp_code: issued.code, purpose: "credential_registration", public_id: staff_telephone.public_id,
      contact_ceremony_transaction_ref: issued.transaction.transaction_id,
      contact_otp_generation: issued.transaction.otp_generation,
      message_style: :localized_verification,
    )
  end

  def check_staff_telephone_verification_rate_limit!
    cache_key = "rate-limit:staff_telephone_verification:#{request.remote_ip}"
    count = Rails.configuration.x.rate_limit.fetch(:store).increment(
      cache_key,
      1,
      expires_in: TELEPHONE_VERIFICATION_RATE_WINDOW.seconds,
    )
    return unless count && count > TELEPHONE_VERIFICATION_RATE_LIMIT

    raise ActionController::TooManyRequests
  end
end

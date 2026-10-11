# typed: false
# frozen_string_literal: true

module SignOperatorTelephoneRegistrable
  extend ActiveSupport::Concern

  include CommonOtp

  TELEPHONE_VERIFICATION_RATE_LIMIT = 5
  TELEPHONE_VERIFICATION_RATE_WINDOW = 60
  VERIFIED_STAFF_TELEPHONE_STATUSES = [
    OperatorTelephoneStatus::ACTIVE,
    OperatorTelephoneStatus::VERIFIED,
  ].freeze

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

    probe.validate unless existing
    @staff_telephone = probe
    return false if probe.errors.any?

    @staff_telephone = existing || staff.staff_telephones.build
    @staff_telephone.raw_number = number
    @staff_telephone.confirm_policy = true
    @staff_telephone.confirm_using_mfa = true
    @staff_telephone.staff_telephone_status_id = OperatorTelephoneStatus::UNVERIFIED

    otp_number = generate_otp_attributes(@staff_telephone)
    return false unless @staff_telephone.valid?

    @staff_telephone.save!
    send_staff_telephone_verification_sms(@staff_telephone, otp_number)

    true
  end

  def complete_staff_telephone_verification(id, submitted_code)
    @staff_telephone = OperatorTelephone.find_by(id: id)
    if @staff_telephone.blank? ||
        @staff_telephone.otp_expired? ||
        @staff_telephone.staff_telephone_status_id != OperatorTelephoneStatus::UNVERIFIED
      return :session_expired
    end

    result = verify_otp_code_and_consume(@staff_telephone, submitted_code)
    unless result[:success]
      if @staff_telephone.locked?
        @staff_telephone.destroy!
        return :locked
      end

      @staff_telephone.errors.add(:pass_code, I18n.t("sign.org.registration.telephone.update.invalid_code"))
      return :invalid_code
    end

    # sign/id verifies the OTP; acme/www performs the final account commit.
    :success
  end

  def verified_staff_telephones_for(staff)
    staff.staff_telephones.where(staff_identity_telephone_status_id: VERIFIED_STAFF_TELEPHONE_STATUSES)
  end

  private

  def send_staff_telephone_verification_sms(staff_telephone, otp_number)
    OtpAdapter.for(surface: :org, channel: :telephone).deliver(
      record: staff_telephone,
      otp_code: otp_number,
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

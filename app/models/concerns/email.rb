# typed: false
# frozen_string_literal: true

module Email
  extend ActiveSupport::Concern
  include EmailOtpPolicy

  # Requires:
  # - address
  # - address_digest
  # - otp_counter
  # - otp_private_key
  # - otp_attempts_count
  # - otp_last_sent_at
  #
  # Optional:
  # - address_bidx
  #
  # Registers:
  # - before_validation :normalize_address_from_raw
  # - before_validation :set_address_digests
  # - scope :with_address
  # - encrypts :address
  # - validate :validate_email_address
  # - validates :confirm_policy
  # - validates :pass_code
  #
  MAX_OTP_ATTEMPTS = EmailOtpPolicy::MAX_OTP_ATTEMPTS
  OTP_ATTEMPT_WINDOW = EmailOtpPolicy::OTP_ATTEMPT_WINDOW
  OTP_LOCKOUT_DURATION = EmailOtpPolicy::OTP_LOCKOUT_DURATION

  OTP_COOLDOWN_PERIOD = EmailOtpPolicy::SEND_COOLDOWN

  attr_accessor :confirm_policy, :pass_code
  attr_writer :raw_address

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    before_validation :normalize_address_from_raw
    before_validation :set_address_digests
    scope :with_address, ->(value) do
      digest = IdentifierBlindIndex.bidx_for_email(value, realm: identifier_hmac_realm)
      digest.present? ? where(address_digest: digest) : none
    end

    validate :validate_email_address
    validates :confirm_policy, acceptance: true, on: :create,
                               unless: proc { |a| a.raw_address.blank? && a.pass_code.present? }
    validates :pass_code, numericality: { only_integer: true },
                          length: { is: 6 },
                          presence: true,
                          unless: proc { |a| a.pass_code.blank? && a.raw_address.present? }
  end

  class_methods do
    public

    def identifier_hmac_realm
      self::IDENTIFIER_REALM
    end

    def find_by_address(value)
      digest = IdentifierBlindIndex.bidx_for_email(value, realm: identifier_hmac_realm)
      return nil if digest.blank?

      find_by(address_digest: digest)
    end
  end

  # Telephone issuance does not select this email-specific cooldown policy.
  def otp_cooldown_active?(now: nil)
    return false if otp_last_sent_at.blank?
    return false if otp_last_sent_at == -Float::INFINITY

    otp_last_sent_at > (now || self.class.database_now) - OTP_COOLDOWN_PERIOD
  end

  def otp_cooldown_remaining(now: nil)
    decision_time = now || self.class.database_now
    return 0 unless otp_cooldown_active?(now: decision_time)

    (otp_last_sent_at + OTP_COOLDOWN_PERIOD) - decision_time
  end

  def raw_address
    @raw_address.presence || address
  end

  private

  def normalize_address_from_raw
    value = raw_address
    return if value.blank?

    normalized = JitUtilsEmailValidator.normalize(value)
    self.address = normalized if normalized.present?
  end

  def set_address_digests
    digest = IdentifierBlindIndex.bidx_for_email(raw_address, realm: self.class.identifier_hmac_realm)
    self.address_bidx = digest if respond_to?(:address_bidx=)
    self.address_digest = digest if respond_to?(:address_digest=)
  end

  def validate_email_address
    return if raw_address.blank? && pass_code.present?

    if raw_address.blank?
      errors.add(:address, :blank)
      return
    end

    normalized = JitUtilsEmailValidator.normalize(raw_address)
    return if normalized

    errors.add(:address, :invalid)
    nil
  end
end

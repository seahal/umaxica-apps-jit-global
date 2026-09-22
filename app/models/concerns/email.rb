# typed: false
# frozen_string_literal: true

module Email
  extend ActiveSupport::Concern
  include OtpLockable

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
  # Registers (in addition to OtpLockable):
  # - before_validation :normalize_address_from_raw
  # - before_validation :set_address_digests
  # - scope :with_address
  # - encrypts :address
  # - validate :validate_email_address
  # - validates :confirm_policy
  # - validates :pass_code
  #
  # OTP attempt/lock/expiry mechanics live in OtpLockable. Cooldown
  # (otp_cooldown_active?/otp_cooldown_remaining) is email-specific because it
  # depends on otp_last_sent_at, which telephone tables do not carry.

  # Re-published from OtpLockable so existing Email::CONST references keep working.
  MAX_OTP_ATTEMPTS = OtpLockable::MAX_OTP_ATTEMPTS
  OTP_ATTEMPT_WINDOW = OtpLockable::OTP_ATTEMPT_WINDOW
  OTP_LOCKOUT_DURATION = OtpLockable::OTP_LOCKOUT_DURATION

  OTP_COOLDOWN_PERIOD = CommonOtpPolicy::SEND_COOLDOWN

  attr_accessor :confirm_policy, :pass_code
  attr_writer :raw_address

  included do
    before_validation :normalize_address_from_raw
    before_validation :set_address_digests
    scope :with_address, ->(value) do
      digest = IdentifierBlindIndex.bidx_for_email(value)
      digest.present? ? where(address_digest: digest) : none
    end

    encrypts :address, downcase: true
    encrypts :otp_private_key

    validate :validate_email_address
    validates :confirm_policy, acceptance: true, on: :create,
                               unless: Proc.new { |a| a.raw_address.blank? && a.pass_code.present? }
    validates :pass_code, numericality: { only_integer: true },
                          length: { is: 6 },
                          presence: true,
                          unless: Proc.new { |a| a.pass_code.blank? && a.raw_address.present? }
  end

  class_methods do
    def find_by_address(value)
      digest = IdentifierBlindIndex.bidx_for_email(value)
      return nil if digest.blank?

      find_by(address_digest: digest)
    end
  end

  # Cooldown gates how often an OTP may be re-sent. Email-only: see OtpLockable.
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
    digest = IdentifierBlindIndex.bidx_for_email(raw_address)
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

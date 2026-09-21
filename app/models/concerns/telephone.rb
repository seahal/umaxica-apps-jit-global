# typed: false
# frozen_string_literal: true

module Telephone
  extend ActiveSupport::Concern
  include TelephoneNormalization
  include OtpLockable

  # Requires:
  # - number
  # - number_digest
  # - otp_counter
  # - otp_private_key
  # - otp_attempts_count
  #
  # Optional:
  # - number_bidx        (set only when the column exists)
  #
  # Registers (in addition to OtpLockable):
  # - before_validation :normalize_number_from_raw
  # - before_validation :set_number_digests
  # - scope :with_number
  # - encrypts :number
  # - validate :validate_telephone_number
  # - validates :confirm_policy
  # - validates :confirm_using_mfa
  # - validates :pass_code
  #
  # OTP attempt/lock/expiry mechanics live in OtpLockable. Telephone tables do
  # not carry otp_last_sent_at, so OtpLockable anchors its time windows on
  # created_at for these records, and cooldown is intentionally not provided.

  # Re-published from OtpLockable so existing Telephone::CONST references keep working.
  MAX_OTP_ATTEMPTS = OtpLockable::MAX_OTP_ATTEMPTS
  OTP_ATTEMPT_WINDOW = OtpLockable::OTP_ATTEMPT_WINDOW
  OTP_LOCKOUT_DURATION = OtpLockable::OTP_LOCKOUT_DURATION

  attr_accessor :confirm_policy, :confirm_using_mfa, :pass_code
  attr_writer :raw_number

  included do
    before_validation :normalize_number_from_raw
    before_validation :set_number_digests
    scope :with_number, ->(value) do
      digest = IdentifierBlindIndex.bidx_for_telephone(value)
      digest.present? ? where(number_digest: digest) : none
    end

    encrypts :number
    encrypts :otp_private_key

    validate :validate_telephone_number

    validates :confirm_policy, acceptance: true,
                               unless: Proc.new { |a| a.raw_number.blank? && a.pass_code.present? }
    validates :confirm_using_mfa, acceptance: true,
                                  unless: Proc.new { |a| a.raw_number.blank? && a.pass_code.present? }
    validates :pass_code, numericality: { only_integer: true },
                          length: { is: 6 },
                          presence: true,
                          unless: Proc.new { |a| a.pass_code.blank? && a.raw_number.present? }
  end

  class_methods do
    def find_by_number(value)
      digest = IdentifierBlindIndex.bidx_for_telephone(value)
      return nil if digest.blank?

      find_by(number_digest: digest)
    end
  end

  def raw_number
    @raw_number.presence || number
  end

  private

  def normalize_number_from_raw
    value = raw_number
    return if value.blank?

    normalized = TelephoneNormalization.normalize_to_e164(value)
    self.number = normalized if normalized.present?
  end

  def set_number_digests
    digest = IdentifierBlindIndex.bidx_for_telephone(raw_number)
    self.number_bidx = digest if respond_to?(:number_bidx=)
    self.number_digest = digest if respond_to?(:number_digest=)
  end

  def validate_telephone_number
    return if raw_number.blank? && pass_code.present?

    if raw_number.blank?
      errors.add(:number, :blank)
      return
    end

    normalized = TelephoneNormalization.normalize_to_e164(raw_number)
    unless normalized
      errors.add(:number, :invalid_e164_format)
      return
    end

    if normalized.start_with?("+0")
      errors.add(:number, :country_code_cannot_start_with_zero)
      return
    end

    return if normalized.match?(TelephoneNormalization::E164_FORMAT)

    errors.add(:number, :invalid_e164_format)
    nil
  end
end

# typed: false
# frozen_string_literal: true

class SignOtpCeremony
  Result = Struct.new(:success?, :status, :record, :code, :error, keyword_init: true)

  OTP_EXPIRATION_MINUTES = 12

  def self.issue!(...)
    new(...).issue!
  end

  def self.verify!(...)
    new(...).verify!
  end

  def initialize(purpose:, surface:, channel:, subject:, destination: nil, code: nil,
                 session_nonce: nil, request_context: nil)
    @purpose = purpose.to_sym
    @surface = surface.to_sym
    @channel = channel.to_sym
    @subject = subject
    @destination = destination
    @code = code
    @session_nonce = session_nonce
    @request_context = request_context
  end

  def issue!
    validate_scope!

    record = bound_record
    return result(false, :missing_destination, error: :missing_destination) unless record
    unless destination_matches?(record)
      return result(false, :destination_mismatch, record: record, error: :destination_mismatch)
    end
    return result(false, :rate_limited, record: record, error: :rate_limited) if cooldown_active?(record)
    return result(false, :locked, record: record, error: :locked) if record.locked?

    otp_code = nil
    record.with_lock do
      return result(false, :locked, record: record, error: :locked) if record.locked?
      return result(false, :rate_limited, record: record, error: :rate_limited) if cooldown_active?(record)

      otp_code = generate_and_store_otp!(record)
    end
    deliver!(record, otp_code)
    result(true, :issued, record: record, code: otp_code)
  end

  def verify!
    validate_scope!

    record = bound_record
    return result(false, :missing_destination, error: :missing_destination) unless record
    unless destination_matches?(record)
      return result(false, :destination_mismatch, record: record, error: :destination_mismatch)
    end
    return result(false, :blank_code, record: record, error: :blank_code) if code.blank?

    record.with_lock do
      otp_data = record.get_otp
      return result(false, :missing_otp, record: record, error: :missing_otp) unless otp_data

      hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
      expected_code = hotp.at(otp_data[:otp_counter]).to_s
      if otp_code_matches?(expected_code, code)
        record.clear_otp
        return result(true, :verified, record: record)
      end

      record.increment_attempts!
      return result(false, :locked, record: record, error: :locked) if record.locked?

      result(false, :invalid_code, record: record, error: :invalid_code)
    end
  end

  private

  attr_reader :purpose, :surface, :channel, :subject, :destination, :code, :session_nonce, :request_context

  def validate_scope!
    raise ArgumentError, "unsupported OTP purpose" unless purpose == :sign_up
    raise ArgumentError, "unsupported OTP surface" unless %i(app com).include?(surface)
    raise ArgumentError, "unsupported OTP channel" unless %i(email telephone).include?(channel)
    raise ArgumentError, "OTP subject does not match surface" unless subject_matches_surface?
    return if subject.pending_contact_type == channel.to_s

    raise ArgumentError, "OTP channel does not match sign-up ticket"
  end

  def subject_matches_surface?
    case surface
    when :app then subject.is_a?(ClientSignUpFlow)
    when :com then subject.is_a?(VisitorSignUpFlow)
    else false
    end
  end

  def bound_record
    return if subject.pending_contact_id.blank?

    expected_record_class.find_by(id: subject.pending_contact_id)
  end

  def expected_record_class
    case [surface, channel]
    when [:app, :email] then ClientEmail
    when [:app, :telephone] then ClientTelephone
    when [:com, :email] then VisitorEmail
    when [:com, :telephone] then VisitorTelephone
    else raise ArgumentError, "unsupported OTP record scope"
    end
  end

  def destination_matches?(record)
    expected_digest = destination_digest(record)
    return true if destination.blank? || expected_digest.blank?

    normalized_digest(destination) == expected_digest
  end

  def destination_digest(record)
    case channel
    when :email then record.address_digest
    when :telephone then record.number_digest
    end
  end

  def normalized_digest(value)
    case channel
    when :email then IdentifierBlindIndex.bidx_for_email(value)
    when :telephone then IdentifierBlindIndex.bidx_for_telephone(value)
    end
  end

  def cooldown_active?(record)
    return record.otp_cooldown_active? if record.respond_to?(:otp_cooldown_active?)
    return false unless record.respond_to?(:otp_last_sent_at)
    return false if record.otp_last_sent_at.blank?
    return false if record.otp_last_sent_at == -Float::INFINITY

    record.otp_last_sent_at > CommonOtpPolicy::SEND_COOLDOWN.ago
  end

  def generate_and_store_otp!(record)
    otp_private_key = ROTP::Base32.random_base32
    otp_counter = Integer([Time.current.to_i, SecureRandom.random_number(1 << 64)].join, 10)
    otp_code = ROTP::HOTP.new(otp_private_key).at(otp_counter).to_s
    record.store_otp(otp_private_key, otp_counter, OTP_EXPIRATION_MINUTES.minutes.from_now.to_i)
    record.update!(otp_last_sent_at: Time.current) if record.respond_to?(:otp_last_sent_at=)
    otp_code
  end

  def otp_code_matches?(expected, submitted)
    expected_value = expected.to_s
    submitted_value = submitted.to_s
    return false unless submitted_value.match?(/\A\d{#{expected_value.length}}\z/)

    ActiveSupport::SecurityUtils.secure_compare(expected_value, submitted_value)
  end

  def deliver!(record, otp_code)
    OtpAdapter
      .for(surface: surface, channel: channel)
      .deliver(record: record, otp_code: otp_code, purpose: purpose)
  end

  def result(success, status, record: nil, code: nil, error: nil)
    Result.new(success?: success, status: status, record: record, code: code, error: error)
  end
end

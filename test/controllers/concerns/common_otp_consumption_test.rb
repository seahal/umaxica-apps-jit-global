# typed: false
# frozen_string_literal: true

require "test_helper"

class CommonOtpConsumptionTest < ActiveSupport::TestCase
  class Harness
    include CommonOtp

    def verify(record, code, &)
      send(:verify_otp_code_and_consume, record, code, &)
    end

    def issue(record)
      send(:generate_otp_for, record)
    end
  end

  class Record
    attr_reader :attempts, :clear_count, :lock_count, :code, :stored_otp

    def initialize
      @otp_private_key = ROTP::Base32.random_base32
      @otp_counter = 17
      @code = ROTP::HOTP.new(@otp_private_key).at(@otp_counter).to_s
      @attempts = 0
      @clear_count = 0
      @lock_count = 0
      @consumed = false
    end

    def with_lock
      @lock_count += 1
      yield
    end

    def get_otp
      return if @consumed

      {
        otp_private_key: @otp_private_key,
        otp_counter: @otp_counter,
        otp_expires_at: 1.minute.from_now.to_i,
      }
    end

    def clear_otp
      @consumed = true
      @clear_count += 1
    end

    def store_otp(otp_private_key, otp_counter, expires_at)
      @stored_otp = { otp_private_key:, otp_counter:, expires_at: }
    end

    def increment_attempts!
      @attempts += 1
    end

    def locked?
      @attempts >= OtpLockable::MAX_OTP_ATTEMPTS
    end
  end

  test "a successful verification consumes the code before a second verifier can accept it" do
    record = Record.new
    harness = Harness.new

    first = harness.verify(record, record.code)
    second = harness.verify(record, record.code)

    assert first[:success]
    assert_not second[:success]
    assert_equal 1, record.clear_count
    assert_equal 1, record.attempts
    assert_equal 2, record.lock_count
  end

  test "OTP generation stores the new credential under the record lock" do
    record = Record.new

    code = Harness.new.issue(record)

    assert_match(/\A\d{6}\z/, code)
    assert_equal 1, record.lock_count
    assert_equal code, ROTP::HOTP.new(record.stored_otp.fetch(:otp_private_key)).at(
      record.stored_otp.fetch(:otp_counter),
    ).to_s
  end

  test "an invalid verification increments attempts while holding the record boundary" do
    record = Record.new

    result = Harness.new.verify(record, "000000")

    assert_not result[:success]
    assert_equal 1, record.attempts
    assert_equal 0, record.clear_count
    assert_equal 1, record.lock_count
  end

  test "a malformed verification code is rejected without a comparison length exception" do
    record = Record.new

    result = Harness.new.verify(record, "12345")

    assert_not result[:success]
    assert_equal 1, record.attempts
    assert_equal 0, record.clear_count
  end

  test "an oversized dummy code is rejected without a comparison length exception" do
    result = Harness.new.send(:verify_dummy_otp, "0" * 7)

    assert_not result[:success]
    assert_equal "Invalid OTP code", result[:error]
  end

  test "the basic HOTP verifier rejects a non-string or malformed code" do
    harness = Harness.new
    secret = ROTP::Base32.random_base32
    counter = 17
    code = ROTP::HOTP.new(secret).at(counter)

    assert harness.send(
      :verify_hotp_code, secret_credential: secret, counter: counter, pass_code: code,
    )
    assert_not harness.send(
      :verify_hotp_code, secret_credential: secret, counter: counter, pass_code: nil,
    )
    assert_not harness.send(
      :verify_hotp_code, secret_credential: secret, counter: counter, pass_code: "12345",
    )
  end

  test "a caller can reject a verified code before consumption without counting an attempt" do
    record = Record.new

    result = Harness.new.verify(record, record.code) { false }

    assert_not result[:success]
    assert_equal :consumption_rejected, result[:error]
    assert_equal 0, record.clear_count
    assert_equal 0, record.attempts
    assert_equal 1, record.lock_count
  end
end

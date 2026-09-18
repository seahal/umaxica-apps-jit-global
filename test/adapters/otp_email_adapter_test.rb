# typed: false
# frozen_string_literal: true

require "test_helper"

class OtpEmailAdapterTest < ActiveSupport::TestCase
  test "deliver encrypts otp and queues mail via the injected mailer" do
    calls = []
    record = Object.new
    record.define_singleton_method(:address) { "user@example.com" }
    fake_mail = Object.new
    fake_mail.define_singleton_method(:deliver_later) { calls << :delivered }

    fake_message = Object.new
    fake_message.define_singleton_method(:create) { fake_mail }

    fake_mailer = Object.new
    fake_mailer.define_singleton_method(:with) do |params|
      calls << params
      fake_message
    end

    adapter = OtpEmailAdapter.new(fake_mailer)
    adapter.deliver(record: record, otp_code: "123456")

    encrypted_token = calls.first.fetch(:encrypted_hotp_token)

    assert_equal(
      {
        encrypted_hotp_token: encrypted_token,
        email_address: "user@example.com",
        encrypted_verification_token: nil,
        public_id: nil,
      },
      calls.first,
    )
    assert_equal "123456", OutboundSensitivePayload.decrypt_email_otp(encrypted_token)
    assert_includes calls, :delivered
  end

  test "deliver forwards optional verification params" do
    calls = []
    record = Object.new
    record.define_singleton_method(:address) { "user@example.com" }
    fake_mail = Object.new
    fake_mail.define_singleton_method(:deliver_later) { calls << :delivered }

    fake_message = Object.new
    fake_message.define_singleton_method(:create) { fake_mail }

    fake_mailer = Object.new
    fake_mailer.define_singleton_method(:with) do |params|
      calls << params
      fake_message
    end

    adapter = OtpEmailAdapter.new(fake_mailer)
    adapter.deliver(
      record: record,
      otp_code: "654321",
      verification_token: "verify-token",
      public_id: "email-public-id",
    )

    encrypted_token = calls.first.fetch(:encrypted_hotp_token)

    assert_equal(
      {
        encrypted_hotp_token: encrypted_token,
        email_address: "user@example.com",
        encrypted_verification_token: calls.first.fetch(:encrypted_verification_token),
        public_id: "email-public-id",
      },
      calls.first,
    )
    assert_equal "654321", OutboundSensitivePayload.decrypt_email_otp(encrypted_token)
    assert_equal(
      "verify-token",
      OutboundSensitivePayload.decrypt_email_verification_token(calls.first.fetch(:encrypted_verification_token)),
    )
    assert_not_includes calls.first.inspect, "verify-token"
    assert_includes calls, :delivered
  end

  test "deliver forwards a non-secret purpose to the mailer" do
    calls = []
    record = Object.new
    record.define_singleton_method(:address) { "user@example.com" }
    fake_mail = Object.new
    fake_mail.define_singleton_method(:deliver_later) { calls << :delivered }

    fake_message = Object.new
    fake_message.define_singleton_method(:create) { fake_mail }

    fake_mailer = Object.new
    fake_mailer.define_singleton_method(:with) do |params|
      calls << params
      fake_message
    end

    OtpEmailAdapter.new(fake_mailer).deliver(record: record, otp_code: "654321", purpose: :sign_in)

    assert_equal :sign_in, calls.first.fetch(:purpose).to_sym
    assert_includes calls, :delivered
  end

  test "deliver forwards a non-secret purpose to the mailer" do
    calls = []
    record = Object.new
    record.define_singleton_method(:address) { "user@example.com" }
    fake_mail = Object.new
    fake_mail.define_singleton_method(:deliver_later) { calls << :delivered }

    fake_message = Object.new
    fake_message.define_singleton_method(:create) { fake_mail }

    fake_mailer = Object.new
    fake_mailer.define_singleton_method(:with) do |params|
      calls << params
      fake_message
    end

    OtpEmailAdapter.new(fake_mailer).deliver(record: record, otp_code: "654321", purpose: :sign_in)

    assert_equal :sign_in, calls.first.fetch(:purpose).to_sym
    assert_includes calls, :delivered
  end

  test "deliver ignores unexpected keyword arguments" do
    calls = []
    fake_mail = Object.new
    fake_mail.define_singleton_method(:deliver_later) { calls << :delivered }

    fake_message = Object.new
    fake_message.define_singleton_method(:create) { fake_mail }

    fake_mailer = Object.new
    fake_mailer.define_singleton_method(:with) { |_| fake_message }

    adapter = OtpEmailAdapter.new(fake_mailer)
    record = Object.new
    record.define_singleton_method(:address) { "addr@example.com" }
    adapter.deliver(
      record: record,
      otp_code: "123456",
      ignored: "value",
    )

    assert_includes calls, :delivered
  end
end

# frozen_string_literal: true

require "test_helper"

class OtpVerificationTokenStorageTest < ActiveSupport::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
  end

  [Email::App::OtpMailer, Email::Com::OtpMailer, Email::Org::OtpMailer].each do |mailer|
    test "#{mailer.name} refuses plaintext-only legacy verification tokens before transport" do
      payload = {
        encrypted_hotp_token: OutboundSensitivePayload.encrypt_email_otp("123456"),
        email_address: "token-storage@example.test",
        verification_token: "synthetic-legacy-token",
      }

      assert_no_difference "ActionMailer::Base.deliveries.count" do
        error = assert_raises(ArgumentError) { mailer.with(payload).create.deliver_now }

        assert_equal "plaintext verification tokens are unsupported", error.message
      end
    end

    test "#{mailer.name} refuses simultaneous encrypted and plaintext verification token fields" do
      payload = {
        encrypted_hotp_token: OutboundSensitivePayload.encrypt_email_otp("123456"),
        email_address: "token-storage@example.test",
        verification_token: "synthetic-legacy-token",
        encrypted_verification_token: OutboundSensitivePayload.encrypt_email_verification_token("synthetic-token"),
      }

      assert_no_difference "ActionMailer::Base.deliveries.count" do
        error = assert_raises(ArgumentError) { mailer.with(payload).create.deliver_now }

        assert_equal "plaintext verification tokens are unsupported", error.message
      end
    end
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Outbound
  class SensitivePayloadTest < ActiveSupport::TestCase
    test "encrypts and decrypts complete sms envelopes without embedding plaintext" do
      token = OutboundSensitivePayload.encrypt_sms_delivery(
        to: "+819012345678", title: "Verification", body: "Your code is 123456",
      )

      assert_not_includes token, "123456"
      assert_equal "Your code is 123456", OutboundSensitivePayload.decrypt_sms_delivery(token).fetch(:body)
    end

    test "email otp tokens cannot be decrypted with sms purpose" do
      token = OutboundSensitivePayload.encrypt_email_otp("123456")

      assert_raises(ActiveSupport::MessageEncryptor::InvalidMessage) do
        OutboundSensitivePayload.decrypt_sms_delivery(token)
      end
    end

    test "blank payloads are rejected" do
      assert_raises(ArgumentError) { OutboundSensitivePayload.encrypt_email_otp("") }
      assert_raises(ArgumentError) { OutboundSensitivePayload.decrypt_email_otp("") }
    end
  end
end

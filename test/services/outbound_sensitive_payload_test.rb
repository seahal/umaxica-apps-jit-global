# typed: false
# frozen_string_literal: true

require "test_helper"

# Outbound payloads are decrypted from values that reached the queue, so a body
# that decrypts to something that is not the expected envelope has to fail as a
# rejected argument rather than as a parser crash inside the delivery job.
class OutboundSensitivePayloadTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a token whose plaintext is not JSON is refused as an invalid payload" do
    token = OutboundSensitivePayload.encrypt(
      "not json at all",
      purpose: OutboundSensitivePayload::SMS_DELIVERY_PURPOSE,
    )

    error =
      assert_raises(ArgumentError) do
        OutboundSensitivePayload.decrypt_envelope(
          token,
          purpose: OutboundSensitivePayload::SMS_DELIVERY_PURPOSE,
          required_keys: %w(version to title body),
        )
      end

    assert_equal "Invalid encrypted sensitive payload", error.message
  end

  test "a well-formed envelope round-trips through encrypt and decrypt" do
    token = OutboundSensitivePayload.encrypt_sms_delivery(to: "+10000000000", title: "t", body: "b")

    assert_equal(
      { version: 1, to: "+10000000000", title: "t", body: "b" },
      OutboundSensitivePayload.decrypt_sms_delivery(token),
    )
  end

  test "an email verification token round-trips through its dedicated encryption boundary" do
    token = OutboundSensitivePayload.encrypt_email_verification_token("verification-token")

    assert_equal "verification-token", OutboundSensitivePayload.decrypt_email_verification_token(token)
    assert_not_equal "verification-token", token
  end

  test "registration OTP SMS uses version four and preserves its original ceremony tuple" do
    %w(app com).each do |surface|
      binding = [surface, "credential_registration", SecureRandom.uuid, "contact", SecureRandom.uuid]
      token = OutboundSensitivePayload.encrypt_sms_delivery(
        to: "+819012345678",
        title: "Verification code",
        body: "Your verification code: 123456",
        otp_binding: binding,
        otp_code: "123456",
      )
      payload = OutboundSensitivePayload.decrypt_sms_delivery(token)

      assert_equal 4, payload.fetch(:version)
      assert_equal binding, payload.fetch(:otp_binding)
      assert_equal "+819012345678", payload.fetch(:to)
      assert_equal "Your verification code: 123456", payload.fetch(:body)
      assert_equal "123456", payload.fetch(:otp_code)
    end
  end

  test "registration OTP SMS rejects missing malformed and mixed original ceremony bindings" do
    valid = ["app", "credential_registration", SecureRandom.uuid, "contact", SecureRandom.uuid]

    [valid.take(4), valid + ["extra"], valid.dup.tap { |tuple| tuple[2] = "other" },
     valid.dup.tap { |tuple| tuple[1] = "unknown" }, valid.dup.tap { |tuple| tuple[4] = "01" },].each do |binding|
      assert_raises(ArgumentError) do
        OutboundSensitivePayload.encrypt_sms_delivery(
          to: "+819012345678",
          title: "Verification code",
          body: "Your verification code: 123456",
          otp_binding: binding,
          otp_code: "123456",
        )
      end
    end
  end
end

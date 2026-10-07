# frozen_string_literal: true

require "test_helper"

class SignupSmsEnvelopeTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "bound SMS preserves exactly version two and the original five field binding" do
    tuple = %w(app sign_up flow contact 0)
    token = OutboundSensitivePayload.encrypt_sms_delivery(
      to: "+819012345670", title: "Verification code", body: "001234", otp_binding: tuple,
    )
    payload = OutboundSensitivePayload.decrypt_sms_delivery(token)

    assert_equal 2, payload.fetch(:version)
    assert_equal tuple, payload.fetch(:otp_binding)
    assert_equal %i(body otp_binding title to version), payload.keys.sort
    assert_not token.include?("001234")
  end

  test "bound SMS refuses missing extra and neighboring tuple sizes before enqueue encryption" do
    tuple = %w(app sign_up flow contact 1)

    [[], tuple.take(4), tuple + ["extra"], "tuple", {}].each do |invalid|
      assert_raises(ArgumentError) do
        OutboundSensitivePayload.encrypt_sms_delivery(
          to: "+819012345670", title: "Verification code", body: "001234", otp_binding: invalid,
        )
      end
    end
  end

  test "queued ciphertext refuses unsupported versions absent binding and extra fields without reconstruction" do
    valid = {
      "version" => 2,
      "to" => "+819012345670",
      "title" => "Verification code",
      "body" => "001234",
      "otp_binding" => %w(com sign_up flow contact 1),
    }
    invalid_payloads = [
      valid.merge("version" => 1), valid.merge("version" => 3), valid.merge("version" => nil),
      valid.except("otp_binding"), valid.merge("extra" => "field"),
      valid.merge("otp_binding" => nil), valid.merge("otp_binding" => valid.fetch("otp_binding").take(4)),
      valid.merge("to" => ""), valid.merge("title" => 1), valid.merge("body" => nil),
    ]
    invalid_payloads.each do |payload|
      token = OutboundSensitivePayload.encrypt(
        JSON.generate(payload), purpose: OutboundSensitivePayload::SMS_DELIVERY_PURPOSE,
      )
      assert_raises(ArgumentError) { OutboundSensitivePayload.decrypt_sms_delivery(token) }
    end
  end

  test "other purpose SMS retains version one without a binding and rejects invalid JSON" do
    token = OutboundSensitivePayload.encrypt_sms_delivery(to: "+819012345670", title: "Notice", body: "Notice")
    payload = OutboundSensitivePayload.decrypt_sms_delivery(token)

    assert_equal 1, payload.fetch(:version)
    assert_not payload.key?(:otp_binding)
    invalid = OutboundSensitivePayload.encrypt("not-json", purpose: OutboundSensitivePayload::SMS_DELIVERY_PURPOSE)
    assert_raises(ArgumentError) { OutboundSensitivePayload.decrypt_sms_delivery(invalid) }
  end
end

# frozen_string_literal: true

require "test_helper"

class TelephoneCredentialRegistrationSmsPayloadTest < ActiveSupport::TestCase
  test "a queued version two credential counter envelope is rejected and reported without transport or disclosure" do
    legacy = OutboundSensitivePayload.encrypt(
      JSON.generate(
        version: 2, to: "+12025550195", title: "Verification code", body: "Your verification code: 123456",
        otp_binding: ["app", "credential_registration", SecureRandom.uuid, "candidate", 1],
      ),
      purpose: OutboundSensitivePayload::SMS_DELIVERY_PURPOSE,
    )
    reported = []
    transported = []
    OutboundSms.stub(:deliver_now, ->(**message) { transported << message }) do
      ActiveSupport.error_reporter.stub(:report, ->(error, **) { reported << error }) do
        Outbound::SmsDeliveryJob.perform_now(encrypted_payload: legacy)
      end
    end

    assert_empty transported
    assert_equal 1, reported.length
    assert_instance_of ArgumentError, reported.fetch(0)
    assert_not_includes reported.fetch(0).message, "123456"
    assert_not_includes reported.fetch(0).message, "+12025550195"
  end

  test "registration SMS verifies localized code consistency independently of worker locale" do
    binding = ["app", "credential_registration", SecureRandom.uuid, "candidate", SecureRandom.uuid]
    encrypted =
      I18n.with_locale(:ja) do
        OutboundSensitivePayload.encrypt_sms_delivery(
          to: "+12025550196", title: "Verification code",
          body: I18n.t("sign.telephone_verification.sms_message", code: "123456"),
          otp_binding: binding, otp_code: "123456",
        )
      end
    payload = I18n.with_locale(:en) { OutboundSensitivePayload.decrypt_sms_delivery(encrypted) }

    assert_equal 4, payload.fetch(:version)
    assert_equal "123456", payload.fetch(:otp_code)
    assert_equal binding, payload.fetch(:otp_binding)
    assert_raises(ArgumentError) do
      OutboundSensitivePayload.encrypt_sms_delivery(
        to: "+12025550196", title: "Verification code", body: "Your verification code: 654321",
        otp_binding: binding, otp_code: "123456",
      )
    end
  end
end

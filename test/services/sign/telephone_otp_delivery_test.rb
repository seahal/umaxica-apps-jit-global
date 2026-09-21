# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Sign
  class TelephoneOtpDeliveryTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper
    include ActiveSupport::Testing::TimeHelpers

    test "assign sets one time password fields on telephone" do
      telephone = ClientTelephone.new(number: "+819012399999")

      freeze_time do
        otp_code = SignTelephoneOtpDelivery.assign(telephone, now: Time.current)

        assert_match(/\A\d{6}\z/, otp_code)
        assert_predicate telephone.otp_private_key, :present?
        assert_predicate telephone.otp_counter.to_s, :present?
        assert_operator telephone.otp_counter.to_i, :<, 1 << 64
        assert_in_delta 10.minutes.from_now.to_i, telephone.otp_expires_at.to_i, 1
        if telephone.respond_to?(:otp_last_sent_at)
          assert_equal Time.current.to_i, telephone.otp_last_sent_at.to_i
        end
      end
    end

    test "deliver enqueues sms delivery job" do
      telephone = Struct.new(:number).new("+819012399998")

      assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
        SignTelephoneOtpDelivery.deliver!(telephone, "123456")
      end

      job_args = enqueued_jobs.last[:args].first

      payload = OutboundSensitivePayload.decrypt_sms_delivery(job_args.fetch("encrypted_payload"))

      assert_equal "+819012399998", payload.fetch(:to)
      assert_equal "Verification code", payload.fetch(:title)
      assert_equal "Your verification code: 123456", payload.fetch(:body)
      assert_not_includes job_args.inspect, "+819012399998"
      assert_not_includes job_args.inspect, "123456"
    end
  end
end

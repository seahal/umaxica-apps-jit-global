# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Outbound
  class SmsDeliveryJobTest < ActiveSupport::TestCase
    test "perform calls outbound sms immediate delivery" do
      called = false
      OutboundSms.stub(
        :deliver_now, ->(to:, title:, body:) {
                        called = true

                        assert_equal "+819012345678", to
                        assert_equal "Verification", title
                        assert_equal "Your code is 123456", body
                      },
      ) do
        SmsDeliveryJob.perform_now(
          encrypted_payload: OutboundSensitivePayload.encrypt_sms_delivery(
            to: "+819012345678", title: "Verification", body: "Your code is 123456",
          ),
        )
      end

      assert called
    end

    test "a legacy encrypted-body payload is refused without delivery or plaintext disclosure" do
      delivered = []
      reported = []

      OutboundSms.stub(:deliver_now, ->(**payload) { delivered << payload }) do
        ActiveSupport.error_reporter.stub(:report, ->(error, **) { reported << error }) do
          SmsDeliveryJob.perform_now(
            to: "+819012345678",
            title: "Verification",
            encrypted_body: OutboundSensitivePayload.encrypt("Your code is 123456", purpose: "outbound.sms.body"),
          )
        end
      end

      assert_empty delivered
      assert_equal 1, reported.length
      assert_instance_of ArgumentError, reported.fetch(0)
      assert_not_includes reported.fetch(0).message, "123456"
      assert_not_includes reported.fetch(0).message, "+819012345678"
    end

    test "a legacy encrypted-body payload without a recipient is discarded and reported" do
      reported = []

      OutboundSms.stub(:deliver_now, ->(**) { flunk("must not deliver") }) do
        ActiveSupport.error_reporter.stub(:report, ->(error, **) { reported << error }) do
          SmsDeliveryJob.perform_now(
            to: "",
            title: "Verification",
            encrypted_body: OutboundSensitivePayload.encrypt("Your code is 123456", purpose: "outbound.sms.body"),
          )
        end
      end

      assert_equal 1, reported.length
      assert_match(/unknown keywords?/, reported.fetch(0).message)
    end

    test "an envelope mixed with legacy fields is discarded and reported" do
      reported = []

      OutboundSms.stub(:deliver_now, ->(**) { flunk("must not deliver") }) do
        ActiveSupport.error_reporter.stub(:report, ->(error, **) { reported << error }) do
          SmsDeliveryJob.perform_now(
            encrypted_payload: OutboundSensitivePayload.encrypt_sms_delivery(
              to: "+819012345678", title: "Verification", body: "Your code is 123456",
            ),
            to: "+819000000000",
          )
        end
      end

      assert_equal 1, reported.length
      assert_match(/unknown keywords?/, reported.fetch(0).message)
    end

    test "queue name is default" do
      assert_equal "default", SmsDeliveryJob.queue_name
    end

    test "legacy plaintext payload is discarded" do
      called = false

      OutboundSms.stub(:deliver_now, ->(**) { called = true }) do
        SmsDeliveryJob.perform_now(to: "+819012345678", title: "Verification", body: "Your code is 123456")
      end

      assert_not called
    end

    test "permanent malformed payloads are reported when discarded" do
      reported = []

      ActiveSupport.error_reporter.stub(
        :report,
        ->(error, **context) { reported << [error, context] },
      ) do
        SmsDeliveryJob.perform_now(to: "+819012345678", title: "Verification", body: "Your code is 123456")
      end

      error, context = reported.fetch(0)

      assert_instance_of ArgumentError, error
      assert_equal "application.active_job", context.fetch(:source)
      assert_match(/unknown keywords?/, error.message)
      assert_not_includes error.message, "123456"
    end
  end
end

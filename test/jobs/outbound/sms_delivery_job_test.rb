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
      assert_match(/Plaintext SMS job payload is no longer accepted/, error.message)
      assert_not_includes error.message, "123456"
    end
  end
end

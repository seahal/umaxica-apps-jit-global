# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Outbound
  class SmsTest < ActiveSupport::TestCase
    test "a nonpositive or nonfinite transport budget is refused before resolving the provider" do
      OutboundSms.stub(:provider, -> { flunk("must not resolve provider") }) do
        [0, -1, Float::INFINITY].each do |timeout|
          assert_raises(ArgumentError) do
            OutboundSms.deliver_now(to: "+819012345678", title: "Verification", body: "code", timeout: timeout)
          end
        end
      end
    end

    test "immediate delivery stops waiting when its transport budget expires" do
      provider = Object.new
      provider.define_singleton_method(:send_message) { |**| sleep 1 }

      OutboundSms.stub(:provider, provider) do
        assert_raises(Net::ReadTimeout) do
          OutboundSms.deliver_now(to: "+819012345678", title: "Verification", body: "code", timeout: 0.05)
        end
      end
    end

    include ActiveJob::TestHelper

    test "accepts a common outbound message payload" do
      assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
        result = OutboundSms.deliver_later(to: "+819012345678", title: "Title", body: "Body")

        assert_predicate result, :accepted?
        assert_equal :sms, result.channel
        assert_nil result.delivery_id
        assert_nil result.error
      end

      job = enqueued_jobs.last

      assert_equal Outbound::SmsDeliveryJob, job[:job]
      payload = OutboundSensitivePayload.decrypt_sms_delivery(job[:args].first.fetch("encrypted_payload"))

      assert_equal "+819012345678", payload.fetch(:to)
      assert_equal "Title", payload.fetch(:title)
      assert_equal "Body", payload.fetch(:body)
      assert_not_includes job[:args].inspect, "+819012345678"
      assert_not_includes job[:args].inspect, "Body"
    end

    test "service call delegates to delayed delivery" do
      assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
        result = OutboundSms.call(to: "+819012345679", title: "Call Title", body: "Call Body")

        assert_predicate result, :accepted?
        assert_equal :sms, result.channel
      end

      job = enqueued_jobs.last

      payload = OutboundSensitivePayload.decrypt_sms_delivery(job[:args].first.fetch("encrypted_payload"))

      assert_equal "+819012345679", payload.fetch(:to)
      assert_equal "Call Title", payload.fetch(:title)
      assert_equal "Call Body", payload.fetch(:body)
      assert_not_includes job[:args].inspect, "+819012345679"
      assert_not_includes job[:args].inspect, "Call Body"
    end

    test "rejects unknown provider configuration before enqueue" do
      previous_provider = Rails.application.config.sms_provider
      Rails.application.config.sms_provider = "unknown"

      assert_no_enqueued_jobs only: Outbound::SmsDeliveryJob do
        assert_raises(ArgumentError) do
          OutboundSms.deliver_later(to: "+819012345678", title: "Title", body: "Body")
        end
      end
    ensure
      Rails.application.config.sms_provider = previous_provider
    end

    test "deliver_now sends message immediately using provider" do
      provider_double = Object.new

      def provider_double.send_message(to:, title:, body:)
        @called_with = { to: to, title: title, body: body }
        true
      end

      def provider_double.called_with
        @called_with
      end

      OutboundSms.stub(:provider, provider_double) do
        result = OutboundSms.deliver_now(to: "+819012345678", title: "Immediate", body: "Now")

        assert result
        assert_equal({ to: "+819012345678", title: "Immediate", body: "Now" }, provider_double.called_with)
      end
    end
  end
end

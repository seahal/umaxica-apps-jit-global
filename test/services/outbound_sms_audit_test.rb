# typed: false
# frozen_string_literal: true

require "test_helper"

class OutboundSmsAuditTest < ActiveSupport::TestCase
  setup do
    ChronicleRecord.connected_to(role: :writing) do
      ChronicleRetentionPolicy.find_or_create_by!(code: "security") do |policy|
        policy.name = "Security"
        policy.duration_days = 365
        policy.permanent = false
      end
    end
  end

  test "records provider acceptance without recipient or message content" do
    response = OutboundProviderResponse.accepted(
      provider: :test,
      provider_reference: "provider-message-123",
      accepted_at: Time.utc(2026, 9, 21, 12, 0, 0),
    )
    provider = Object.new
    delivered_arguments = {}
    provider.define_singleton_method(:send_message) do |to:, title:, body:|
      delivered_arguments.merge!(to:, title:, body:)
      response
    end

    assert_difference -> { Chronicle.where(action: "notification.delivery.sms.provider_accepted").count }, 1 do
      OutboundSms.stub(:provider, provider) do
        result = OutboundSms.deliver_now(
          to: "+819012345678",
          title: "Verification",
          body: "Your code is 123456",
        )

        assert_same response, result
      end
    end

    assert_equal(
      { to: "+819012345678", title: "Verification", body: "Your code is 123456" },
      delivered_arguments,
    )

    chronicle = Chronicle.where(action: "notification.delivery.sms.provider_accepted").order(:created_at).last

    assert_equal "test", chronicle.metadata.fetch("provider")
    assert_equal "provider-message-123", chronicle.metadata.fetch("provider_reference")
    assert_not chronicle.metadata.key?("to")
    assert_not chronicle.metadata.key?("title")
    assert_not chronicle.metadata.key?("body")
  end

  test "records provider failure and preserves the provider exception" do
    provider = Object.new
    provider.define_singleton_method(:send_message) do |**|
      raise Net::ReadTimeout, "provider timed out"
    end

    assert_difference -> { Chronicle.where(action: "notification.delivery.sms.delivery_failed").count }, 1 do
      assert_raises(Net::ReadTimeout) do
        OutboundSms.stub(:provider, provider) do
          OutboundSms.deliver_now(to: "+819012345678", title: "Verification", body: "Your code is 123456")
        end
      end
    end

    chronicle = Chronicle.where(action: "notification.delivery.sms.delivery_failed").order(:created_at).last

    assert_equal "Net::ReadTimeout", chronicle.reason
    assert_not_includes chronicle.reason, "provider timed out"
    assert_not chronicle.metadata.key?("to")
    assert_not chronicle.metadata.key?("body")
  end

  test "records successful enqueue without treating it as provider delivery" do
    enqueued = nil
    provider = Object.new

    OutboundSms.stub(:provider, provider) do
      Outbound::SmsDeliveryJob.stub(
        :perform_later,
        ->(**arguments) { enqueued = arguments },
      ) do
        result = OutboundSms.deliver_later(
          to: "+819012345678",
          title: "Verification",
          body: "Your code is 123456",
        )

        assert_predicate result, :accepted?
      end
    end

    assert_predicate enqueued, :present?
    assert_equal 1, Chronicle.where(action: "notification.delivery.sms.enqueued").count
    assert_equal 0, Chronicle.where(action: "notification.delivery.sms.provider_accepted").count
  end

  test "does not turn an audit persistence failure into a duplicate delivery" do
    response = OutboundProviderResponse.accepted(provider: :test, provider_reference: "provider-message-456")
    provider = Object.new
    provider.define_singleton_method(:send_message) { |**| response }

    Chronicle.stub(:capture, ->(**) { raise ActiveRecord::ConnectionNotEstablished, "audit unavailable" }) do
      OutboundSms.stub(:provider, provider) do
        assert_same response, OutboundSms.deliver_now(
          to: "+819012345678",
          title: "Verification",
          body: "Your code is 123456",
        )
      end
    end
  end
end

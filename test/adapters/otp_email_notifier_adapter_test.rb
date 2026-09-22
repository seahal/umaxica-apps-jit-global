# typed: false
# frozen_string_literal: true

require "test_helper"

class OtpEmailNotifierAdapterTest < ActiveSupport::TestCase
  test "deliver forwards the record and otp to the injected notifier" do
    calls = []
    record = Object.new
    fake_notifier = Object.new
    fake_notifier.define_singleton_method(:issue) { |**kwargs| calls << kwargs }

    OtpEmailNotifierAdapter.new(fake_notifier).deliver(record: record, otp_code: "123456")

    assert_equal(
      [{ record: record, otp_code: "123456", verification_token: nil, public_id: nil }],
      calls,
    )
  end

  test "deliver forwards optional verification params" do
    calls = []
    record = Object.new
    fake_notifier = Object.new
    fake_notifier.define_singleton_method(:issue) { |**kwargs| calls << kwargs }

    OtpEmailNotifierAdapter.new(fake_notifier).deliver(
      record: record,
      otp_code: "654321",
      verification_token: "verify-token",
      public_id: "email-public-id",
    )

    assert_equal(
      [{
        record: record,
        otp_code: "654321",
        verification_token: "verify-token",
        public_id: "email-public-id",
      }],
      calls,
    )
  end

  # Parity with OtpEmailAdapter, whose `**` sink lets call sites pass channel
  # specific options such as message_style without knowing which adapter they got.
  test "deliver ignores unexpected keyword arguments" do
    calls = []
    fake_notifier = Object.new
    fake_notifier.define_singleton_method(:issue) { |**kwargs| calls << kwargs }

    OtpEmailNotifierAdapter.new(fake_notifier).deliver(
      record: Object.new,
      otp_code: "123456",
      message_style: :localized_verification,
    )

    assert_equal 1, calls.length
    assert_not calls.first.key?(:message_style)
  end

  test "records enqueue failure and re-raises the notifier exception" do
    audit_events = []
    record = Object.new
    notifier = Object.new
    notifier.define_singleton_method(:issue) do |**|
      raise Net::ReadTimeout, "provider timeout"
    end

    Chronicle.stub(:capture, ->(**event) { audit_events << event }) do
      assert_raises(Net::ReadTimeout) do
        OtpEmailNotifierAdapter.new(notifier).deliver(
          record: record,
          otp_code: "246810",
          purpose: :step_up,
        )
      end
    end

    assert_equal "notification.delivery.email.enqueue_failed", audit_events.first.fetch(:action)
    assert_equal "Net::ReadTimeout", audit_events.first.fetch(:reason)
    assert_equal({ purpose: "step_up" }, audit_events.first.fetch(:metadata))
    assert_not_includes audit_events.first.inspect, "246810"
    assert_not_includes audit_events.first.inspect, "provider timeout"
  end

  test "audit failure after notifier issue does not turn one issue into a delivery failure" do
    issues = 0
    notifier = Object.new
    notifier.define_singleton_method(:issue) { |**| issues += 1 }

    Chronicle.stub(:capture, ->(**) { raise ActiveRecord::ConnectionNotEstablished, "audit unavailable" }) do
      OtpEmailNotifierAdapter.new(notifier).deliver(record: Object.new, otp_code: "135790")
    end

    assert_equal 1, issues
  end
end

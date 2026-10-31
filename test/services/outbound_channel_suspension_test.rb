# typed: false
# frozen_string_literal: true

require "test_helper"

class OutboundChannelSuspensionTest < ActiveSupport::TestCase
  # Stands in for Flipper so each test states its own flag values.
  class StubFlipper
    def initialize(features)
      @features = features
    end

    def enabled?(feature)
      @features.fetch(feature, false)
    end
  end

  test "an unset feature leaves the channel running" do
    assert_not OutboundChannelSuspension.new(flipper: StubFlipper.new({})).suspended?(:sms)
    assert_not OutboundChannelSuspension.new(flipper: StubFlipper.new({})).suspended?(:email)
    assert_not OutboundChannelSuspension.new(flipper: StubFlipper.new({})).suspended?(:promotional_email)
  end

  test "an enabled feature suspends only its own channel" do
    suspension = OutboundChannelSuspension.new(flipper: StubFlipper.new(outbound_sms_suspended: true))

    assert suspension.suspended?(:sms)
    assert_not suspension.suspended?(:email)
  end

  test "suspending email also suspends promotional email" do
    suspension = OutboundChannelSuspension.new(flipper: StubFlipper.new(outbound_email_suspended: true))

    assert suspension.suspended?(:email)
    assert suspension.suspended?(:promotional_email)
  end

  test "suspending promotional email leaves transactional email running" do
    suspension =
      OutboundChannelSuspension.new(flipper: StubFlipper.new(outbound_promotional_email_suspended: true))

    assert suspension.suspended?(:promotional_email)
    assert_not suspension.suspended?(:email)
  end

  test "an unknown channel is rejected rather than treated as running" do
    error =
      assert_raises(ArgumentError) do
        OutboundChannelSuspension.new(flipper: StubFlipper.new({})).suspended?(:carrier_pigeon)
      end

    assert_match(/unsupported outbound channel/, error.message)
  end
end

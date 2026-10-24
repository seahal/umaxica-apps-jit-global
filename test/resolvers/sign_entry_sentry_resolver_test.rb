# typed: false
# frozen_string_literal: true

require "test_helper"

class SignEntrySentryResolverTest < ActiveSupport::TestCase
  class StubFlipper
    def initialize(values)
      @values = values
    end

    def enabled?(feature)
      @values.fetch(feature, false)
    end
  end

  test "every registered pair maps explicit true to ALLOWED" do
    SignEntrySentryResolver::ENTRY_FLAGS.each do |(surface, flow), feature|
      state = SignEntrySentryResolver.call(
        surface:, flow:, flipper: StubFlipper.new(feature => true),
      )

      assert_equal SignEntrySentryStateValue::ALLOWED, state.state
      assert_predicate state, :allowed?
    end
  end

  test "false and unwritten availability are BLOCKED" do
    %w(app com org).product(%w(sign_in sign_up)).each do |surface, flow|
      state = SignEntrySentryResolver.call(
        surface:, flow:, flipper: StubFlipper.new({}),
      )

      assert_equal SignEntrySentryStateValue::BLOCKED, state.state
      assert_predicate state, :blocked?
    end
  end

  test "an unknown surface or flow is rejected" do
    assert_raises(ArgumentError) do
      SignEntrySentryResolver.call(surface: "net", flow: "sign_in", flipper: StubFlipper.new({}))
    end

    assert_raises(ArgumentError) do
      SignEntrySentryResolver.call(surface: "app", flow: "ticket", flipper: StubFlipper.new({}))
    end
  end

  test "a flag store database failure fails closed" do
    state =
      FeatureFlags.stub(:enabled?, ->(*) { raise ActiveRecord::ConnectionNotEstablished }) do
        SignEntrySentryResolver.call(surface: "app", flow: "sign_in")
      end

    assert_predicate state, :blocked?
  end
end

# frozen_string_literal: true

require_relative "../../../../config/environment"
require "minitest/autorun"

class ExplicitContextAccessorsTest < ActiveSupport::TestCase
  def test_context_accessors_remain_private_zero_argument_methods_on_consumers_and_subclasses
    controller = Auth::Com::ApplicationController.new
    child = Class.new(Auth::Com::ApplicationController).new

    RequestContextContract.public_keys.each do |key|
      name = :"request_context_#{key}"
      [controller, child].each do |consumer|
        assert_equal [false, true], [consumer.respond_to?(name), consumer.respond_to?(name, true)]
        assert_includes consumer.private_methods, name
        assert_empty consumer.method(name).parameters
        assert_equal 0, consumer.method(name).arity
      end
    end
  end

  def test_public_context_preserves_all_keys_normalization_and_case_sensitive_return_targets
    controller = Class.new(ApplicationController) { include PreferenceGlobal }.new
    controller.params = ActionController::Parameters.new(
      ri: "US", pt: "/CaseSensitive", nt: "Dashboard", lx: "EN", ct: "DR", tz: "UTC",
      cu: "USD", df: "US", tf: "hour_12", mo: "reduced", dn: "compact", ps: "50",
    )

    assert_equal(
      {
        ri: "us",
        pt: "/CaseSensitive",
        nt: "Dashboard",
        lx: "en",
        ct: "dr",
        tz: "utc",
        cu: "usd",
        df: "us",
        tf: "12",
        mo: "rd",
        dn: "cp",
        ps: "50",
      }, controller.request_context,
    )
    assert_not controller.requested_context.key?(:pt)
    assert_not controller.requested_context.key?(:nt)
  end

  def test_public_context_omits_missing_empty_and_invalid_values
    controller = Class.new(ApplicationController) { include PreferenceGlobal }.new
    controller.params = ActionController::Parameters.new(
      ri: "invalid", lx: "kr", ct: "purple", tz: "Mars/Base",
      pt: "", nt: nil,
    )

    assert_empty controller.request_context
  end
end

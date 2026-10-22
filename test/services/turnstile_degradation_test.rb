# typed: false
# frozen_string_literal: true

require "test_helper"

class TurnstileDegradationTest < ActiveSupport::TestCase
  # Stands in for Flipper so each test states its own flag values.
  class StubFlipper
    def initialize(enabled)
      @enabled = enabled
    end

    def enabled?(_feature)
      @enabled
    end
  end

  { missing: nil, empty: "", whitespace: " " }.each do |label, token|
    test "degraded mode rejects a #{label} token through the real verifier" do
      verification = JitSecurityTurnstileVerifier.verify(
        token: token, remote_ip: "127.0.0.1", secret_key: "test-only-secret", mode: :visible,
      )
      result = TurnstileDegradation.apply(verification, flipper: StubFlipper.new(true))

      assert_not result.fetch("success")
      assert_not result.fetch("unavailable")
      assert_equal "missing cf-turnstile-response", result.fetch("error")
      assert_nil result["degraded"]
    end
  end

  test "an upstream outage passes while degraded mode is on" do
    result = apply({ "success" => false, "error" => "timeout", "unavailable" => true }, degraded: true)

    assert result["success"]
    assert result["degraded"]
  end

  test "an upstream outage still fails while degraded mode is off" do
    result = apply({ "success" => false, "error" => "timeout", "unavailable" => true }, degraded: false)

    assert_not result["success"]
    assert_not result["degraded"]
  end

  test "a failed challenge is not degraded" do
    result = apply({ "success" => false, "error" => "invalid-input-response", "unavailable" => false }, degraded: true)

    assert_not result["success"]
  end

  test "a missing secret is configuration and is not degraded" do
    result = apply(
      { "success" => false, "error" => "missing turnstile secret", "unavailable" => false },
      degraded: true,
    )

    assert_not result["success"]
  end

  test "a successful verification is returned untouched" do
    result = apply({ "success" => true, "hostname" => "umaxica.app" }, degraded: true)

    assert result["success"]
    assert_nil result["degraded"]
  end

  private

  def apply(result, degraded:)
    TurnstileDegradation.new(flipper: StubFlipper.new(degraded)).apply(result)
  end
end

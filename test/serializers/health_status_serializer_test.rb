# typed: false
# frozen_string_literal: true

require "test_helper"

# HealthStatusSerializer maps the internal Health status vocabulary onto the pass/warn/fail wire
# vocabulary for GET /api/v0/health.json, aggregates the three probe verdicts, and owns the HTTP
# status (fail -> 503, otherwise 200).
class HealthStatusSerializerTest < ActiveSupport::TestCase
  def result(check, status)
    Health::CheckResult.new(check: check, status: status, surface: "test")
  end

  test "all probes ok is status pass and HTTP 200" do
    serialized = HealthStatusSerializer.call(
      liveness: result(:liveness, :ok),
      readiness: result(:readiness, :ok),
      startup: result(:startup, :ok),
    )

    assert_equal(
      { status: "pass",
        checks: { startup: { status: "pass" }, liveness: { status: "pass" }, readiness: { status: "pass" } }, },
      serialized.body,
    )
    assert_equal 200, serialized.http_status
  end

  test "an unready readiness is fail overall and HTTP 503, and does not change liveness" do
    serialized = HealthStatusSerializer.call(
      liveness: result(:liveness, :ok),
      readiness: result(:readiness, :unready),
      startup: result(:startup, :ok),
    )

    assert_equal "fail", serialized.body.fetch(:status)
    assert_equal "fail", serialized.body.dig(:checks, :readiness, :status)
    assert_equal "pass", serialized.body.dig(:checks, :liveness, :status)
    assert_equal 503, serialized.http_status
  end

  test "degraded but acceptable is warn overall and still HTTP 200" do
    serialized = HealthStatusSerializer.call(
      liveness: result(:liveness, :ok),
      readiness: result(:readiness, :degraded_acceptable),
      startup: result(:startup, :ok),
    )

    assert_equal "warn", serialized.body.fetch(:status)
    assert_equal "warn", serialized.body.dig(:checks, :readiness, :status)
    assert_equal 200, serialized.http_status
  end

  test "a starting process warns on liveness but fails on startup" do
    liveness_starting = HealthStatusSerializer.call(
      liveness: result(:liveness, :starting),
      readiness: result(:readiness, :ok),
      startup: result(:startup, :ok),
    )
    # Liveness tolerates a starting process: HTTP 200, warn.
    assert_equal "warn", liveness_starting.body.dig(:checks, :liveness, :status)
    assert_equal "warn", liveness_starting.body.fetch(:status)
    assert_equal 200, liveness_starting.http_status

    startup_starting = HealthStatusSerializer.call(
      liveness: result(:liveness, :ok),
      readiness: result(:readiness, :ok),
      startup: result(:startup, :starting),
    )
    # Startup does not: HTTP 503, fail.
    assert_equal "fail", startup_starting.body.dig(:checks, :startup, :status)
    assert_equal "fail", startup_starting.body.fetch(:status)
    assert_equal 503, startup_starting.http_status
  end

  test "checks are emitted in startup, liveness, readiness order" do
    serialized = HealthStatusSerializer.call(
      liveness: result(:liveness, :ok),
      readiness: result(:readiness, :ok),
      startup: result(:startup, :ok),
    )

    assert_equal %i(startup liveness readiness), serialized.body.fetch(:checks).keys
  end
end

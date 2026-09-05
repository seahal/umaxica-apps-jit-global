# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Probe and aggregate behaviour on a single surface (auth/app). The wire contract is text/plain:
# a probe is "ok\n" / 200 or "unavailable\n" / 503, and GET /health is the four-line aggregate.
class HealthCheckTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")
  end

  test "readiness returns ok as text/plain when dependencies are healthy" do
    result = Health::CheckResult.new(
      check: :readiness,
      status: :ok,
      surface: "sign app",
      dependencies: { "database" => "ok" },
    )

    Health::ReadinessCheck.stub(:call, result) do
      get "/health/readiness?ri=jp"
    end

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_not_equal "application/json", response.media_type
    assert_equal "ok\n", response.body
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "readiness returns unavailable as text/plain 503 when dependencies fail" do
    result = Health::CheckResult.new(
      check: :readiness,
      status: :unready,
      surface: "sign app",
      dependencies: { "database" => "failed" },
    )

    Health::ReadinessCheck.stub(:call, result) do
      get "/health/readiness?ri=jp"
    end

    assert_response :service_unavailable
    assert_equal "text/plain", response.media_type
    assert_equal "unavailable\n", response.body
    assert_not_includes response.body, "database"
    assert_not_includes response.body, "failed"
  end

  test "startup reports unavailable as text/plain 503 when Rails is not initialized" do
    Rails.application.stub(:initialized?, false) do
      get "/health/startup?ri=jp"
    end

    assert_response :service_unavailable
    assert_equal "text/plain", response.media_type
    assert_equal "unavailable\n", response.body
    assert_not_includes response.body, "sign"
    assert_not_includes response.body, "surface"
  end

  test "health aggregate is text/plain and never names the surface" do
    result = Health::CheckResult.new(
      check: :health,
      status: :ok,
      surface: "sign app",
      dependencies: {
        "liveness" => { status: "ok" },
        "readiness" => { status: "ok" },
        "startup" => { status: "ok" },
      },
    )

    Health::SnapshotCheck.stub(:call, result) do
      get "/health?ri=jp"
    end

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal "status: ok\nstartup: ok\nliveness: ok\nreadiness: ok\n", response.body
    assert_no_match(/surface/i, response.body)
    assert_no_match(/sign app/i, response.body)
  end

  # The `.json` suffix is deliberately not a route: `/api/v0/health.json` serves real JSON at nearly
  # the same spelling, so answering the suffix with text/plain would tell that caller it had reached
  # the JSON endpoint. An `Accept` header is a different case and is still answered -- a probe that
  # 406s because its client sent a boilerplate `Accept` reports an outage that is not happening.
  test "health aggregate does not route a .json suffix but still answers an Accept header" do
    get "/health.json?ri=jp"

    assert_response :not_found

    get "/health", headers: { "Accept" => "application/json" }

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_no_match(/\A\s*[{\[]/, response.body)
  end
end

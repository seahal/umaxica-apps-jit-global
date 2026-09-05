# frozen_string_literal: true

require "test_helper"

class PlainTextHealthEndpointsTest < ActionDispatch::IntegrationTest
  test "health endpoints expose the resourceful plain text contract without authentication or redirects" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    {
      "/health" => "status: ok\nstartup: ok\nliveness: ok\nreadiness: ok\n",
      "/health/startup" => "ok\n",
      "/health/liveness" => "ok\n",
      "/health/readiness" => "ok\n",
    }.each do |path, expected_body|
      get path

      assert_response :success
      assert_equal "text/plain", response.media_type
      assert_equal "utf-8", response.charset
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_equal expected_body, response.body
      assert_not_predicate response, :redirect?
      assert_nil response.headers["Location"]
    end
  end

  test "health endpoints never negotiate json or html representations" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    ["/health", "/health/startup", "/health/liveness", "/health/readiness"].each do |path|
      ["application/json", "text/html"].each do |accept|
        get path, headers: { "Accept" => accept }

        assert_includes [200, 503], response.status
        assert_equal "text/plain", response.media_type
        assert_equal "utf-8", response.charset
      end
    end

    get "/health.json"

    assert_response :not_found

    get "/health/readiness.txt"

    assert_response :not_found
  end

  # `/health.json` and `/revision.json` used to route and answer 200 with the plain-text body,
  # because the text routes accepted a format segment. That is actively misleading now that
  # `/api/v0/health.json` and `/api/v0/revision.json` serve real JSON at almost the same spelling:
  # a caller that reached for the suffix got text/plain and a 200, not the JSON it asked for.
  test "a format suffix on a text endpoint is not routed" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    ["/health.json", "/health/liveness.json", "/revision.json", "/revision.txt"].each do |path|
      get path

      assert_response :not_found, path
    end

    get "/api/v0/health.json", headers: { "Accept" => "application/json" }

    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "readiness returns service unavailable when a required dependency fails" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")
    result = Health::CheckResult.new(
      check: :readiness,
      status: :unready,
      surface: Health::Profiles::SignApp.surface_label,
      dependencies: { "database" => "failed" },
    )

    Health::ReadinessCheck.stub(:call, result) do
      get "/health/readiness"
    end

    assert_response :service_unavailable
    assert_equal "text/plain", response.media_type
    assert_equal "unavailable\n", response.body
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "liveness stays successful when external dependencies fail" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    Health::ReadinessCheck.stub(:call, ->(*) { raise StandardError, "readiness dependency touched" }) do
      ActiveRecord::Base.stub(:connection, -> { raise StandardError, "database touched" }) do
        get "/health/liveness"
      end
    end

    assert_response :success
    assert_equal "ok\n", response.body
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# End-to-end contract for the health endpoints on every declared surface.
#
#   GET /health            -> text/plain four-line aggregate (status, startup, liveness, readiness)
#   GET /health/{probe}    -> text/plain "ok\n" / HTTP 200 or "unavailable\n" / HTTP 503
#   GET /api/v0/health.json -> application/json {"status":..,"checks":{..}}, 406 on a non-JSON Accept
class HealthEndpointsTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      host: ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost"),
      controller: "auth/app/healths",
      liveness_controller: "auth/app/health/livenesses",
      readiness_controller: "auth/app/health/readinesses",
      startup_controller: "auth/app/health/startups",
      json_controller: "auth/app/api/v0/healths",
      profile: Health::Profiles::SignApp,
    },
    {
      host: ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost"),
      controller: "auth/com/healths",
      liveness_controller: "auth/com/health/livenesses",
      readiness_controller: "auth/com/health/readinesses",
      startup_controller: "auth/com/health/startups",
      json_controller: "auth/com/api/v0/healths",
      profile: Health::Profiles::SignCom,
    },
    {
      host: ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost"),
      controller: "auth/org/healths",
      liveness_controller: "auth/org/health/livenesses",
      readiness_controller: "auth/org/health/readinesses",
      startup_controller: "auth/org/health/startups",
      json_controller: "auth/org/api/v0/healths",
      profile: Health::Profiles::SignOrg,
    },
    {
      host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
      controller: "base/app/healths",
      liveness_controller: "base/app/health/livenesses",
      readiness_controller: "base/app/health/readinesses",
      startup_controller: "base/app/health/startups",
      json_controller: "base/app/api/v0/healths",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
      controller: "base/com/healths",
      liveness_controller: "base/com/health/livenesses",
      readiness_controller: "base/com/health/readinesses",
      startup_controller: "base/com/health/startups",
      json_controller: "base/com/api/v0/healths",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
      controller: "base/org/healths",
      liveness_controller: "base/org/health/livenesses",
      readiness_controller: "base/org/health/readinesses",
      startup_controller: "base/org/health/startups",
      json_controller: "base/org/api/v0/healths",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("PRIVATE_BASE_NETWORK_URL", "base.net.localhost"),
      controller: "base/net/healths",
      liveness_controller: "base/net/health/livenesses",
      readiness_controller: "base/net/health/readinesses",
      startup_controller: "base/net/health/startups",
      json_controller: "base/net/api/v0/healths",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PRIVATE_BASE_DEVELOPER_URL", "base.dev.localhost"),
      controller: "base/dev/healths",
      liveness_controller: "base/dev/health/livenesses",
      readiness_controller: "base/dev/health/readinesses",
      startup_controller: "base/dev/health/startups",
      json_controller: "base/dev/api/v0/healths",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PUBLIC_PALM_SERVICE_URL"),
      controller: "palm/app/healths",
      liveness_controller: "palm/app/health/livenesses",
      readiness_controller: "palm/app/health/readinesses",
      startup_controller: "palm/app/health/startups",
      json_controller: "palm/app/api/v0/healths",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PRIVATE_HELP_SERVICE_URL"),
      controller: "help/app/healths",
      liveness_controller: "help/app/health/livenesses",
      readiness_controller: "help/app/health/readinesses",
      startup_controller: "help/app/health/startups",
      json_controller: "help/app/api/v0/healths",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PRIVATE_HELP_CORPORATE_URL"),
      controller: "help/com/healths",
      liveness_controller: "help/com/health/livenesses",
      readiness_controller: "help/com/health/readinesses",
      startup_controller: "help/com/health/startups",
      json_controller: "help/com/api/v0/healths",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("PRIVATE_HELP_STAFF_URL"),
      controller: "help/org/healths",
      liveness_controller: "help/org/health/livenesses",
      readiness_controller: "help/org/health/readinesses",
      startup_controller: "help/org/health/startups",
      json_controller: "help/org/api/v0/healths",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("PRIVATE_DOCS_SERVICE_URL"),
      controller: "docs/app/healths",
      liveness_controller: "docs/app/health/livenesses",
      readiness_controller: "docs/app/health/readinesses",
      startup_controller: "docs/app/health/startups",
      json_controller: "docs/app/api/v0/healths",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PRIVATE_DOCS_CORPORATE_URL"),
      controller: "docs/com/healths",
      liveness_controller: "docs/com/health/livenesses",
      readiness_controller: "docs/com/health/readinesses",
      startup_controller: "docs/com/health/startups",
      json_controller: "docs/com/api/v0/healths",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("PRIVATE_DOCS_STAFF_URL"),
      controller: "docs/org/healths",
      liveness_controller: "docs/org/health/livenesses",
      readiness_controller: "docs/org/health/readinesses",
      startup_controller: "docs/org/health/startups",
      json_controller: "docs/org/api/v0/healths",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("PRIVATE_NEWS_SERVICE_URL"),
      controller: "news/app/healths",
      liveness_controller: "news/app/health/livenesses",
      readiness_controller: "news/app/health/readinesses",
      startup_controller: "news/app/health/startups",
      json_controller: "news/app/api/v0/healths",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PRIVATE_NEWS_CORPORATE_URL"),
      controller: "news/com/healths",
      liveness_controller: "news/com/health/livenesses",
      readiness_controller: "news/com/health/readinesses",
      startup_controller: "news/com/health/startups",
      json_controller: "news/com/api/v0/healths",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("PRIVATE_NEWS_STAFF_URL"),
      controller: "news/org/healths",
      liveness_controller: "news/org/health/livenesses",
      readiness_controller: "news/org/health/readinesses",
      startup_controller: "news/org/health/startups",
      json_controller: "news/org/api/v0/healths",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("PRIVATE_INFO_SERVICE_URL", "info.app.localhost"),
      controller: "info/app/healths",
      liveness_controller: "info/app/health/livenesses",
      readiness_controller: "info/app/health/readinesses",
      startup_controller: "info/app/health/startups",
      json_controller: "info/app/api/v0/healths",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PRIVATE_INFO_CORPORATE_URL", "info.com.localhost"),
      controller: "info/com/healths",
      liveness_controller: "info/com/health/livenesses",
      readiness_controller: "info/com/health/readinesses",
      startup_controller: "info/com/health/startups",
      json_controller: "info/com/api/v0/healths",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("PRIVATE_INFO_STAFF_URL", "info.org.localhost"),
      controller: "info/org/healths",
      liveness_controller: "info/org/health/livenesses",
      readiness_controller: "info/org/health/readinesses",
      startup_controller: "info/org/health/startups",
      json_controller: "info/org/api/v0/healths",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost")),
      controller: "core/app/healths",
      liveness_controller: "core/app/health/livenesses",
      readiness_controller: "core/app/health/readinesses",
      startup_controller: "core/app/health/startups",
      json_controller: "core/app/api/v0/healths",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL", ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost")),
      controller: "core/com/healths",
      liveness_controller: "core/com/health/livenesses",
      readiness_controller: "core/com/health/readinesses",
      startup_controller: "core/com/health/startups",
      json_controller: "core/com/api/v0/healths",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("PUBLIC_CORE_STAFF_URL", ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost")),
      controller: "core/org/healths",
      liveness_controller: "core/org/health/livenesses",
      readiness_controller: "core/org/health/readinesses",
      startup_controller: "core/org/health/startups",
      json_controller: "core/org/api/v0/healths",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("PRIVATE_CORE_NETWORK_URL", "core.net.localhost"),
      controller: "core/net/healths",
      liveness_controller: "core/net/health/livenesses",
      readiness_controller: "core/net/health/readinesses",
      startup_controller: "core/net/health/startups",
      json_controller: "core/net/api/v0/healths",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PRIVATE_CORE_DEVELOPER_URL", "core.dev.localhost"),
      controller: "core/dev/healths",
      liveness_controller: "core/dev/health/livenesses",
      readiness_controller: "core/dev/health/readinesses",
      startup_controller: "core/dev/health/startups",
      json_controller: "core/dev/api/v0/healths",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost"),
      controller: "side/app/healths",
      liveness_controller: "side/app/health/livenesses",
      readiness_controller: "side/app/health/readinesses",
      startup_controller: "side/app/health/startups",
      json_controller: "side/app/api/v0/healths",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PUBLIC_SIDE_CORPORATE_URL", "side.com.localhost"),
      controller: "side/com/healths",
      liveness_controller: "side/com/health/livenesses",
      readiness_controller: "side/com/health/readinesses",
      startup_controller: "side/com/health/startups",
      json_controller: "side/com/api/v0/healths",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("PUBLIC_SIDE_STAFF_URL", "side.org.localhost"),
      controller: "side/org/healths",
      liveness_controller: "side/org/health/livenesses",
      readiness_controller: "side/org/health/readinesses",
      startup_controller: "side/org/health/startups",
      json_controller: "side/org/api/v0/healths",
      profile: Health::Profiles::Org,
    },
  ].freeze

  PROBES = %w(liveness readiness startup).freeze

  test "surface routes resolve to concrete local controllers with exact profiles" do
    SURFACES.each do |surface|
      assert_health_route(surface[:host], "/health", surface[:controller])
      assert_health_route(surface[:host], "/health/liveness", surface[:liveness_controller])
      assert_health_route(surface[:host], "/health/readiness", surface[:readiness_controller])
      assert_health_route(surface[:host], "/health/startup", surface[:startup_controller])
      assert_health_route(surface[:host], "/api/v0/health.json", surface[:json_controller])

      [
        surface[:controller],
        surface[:liveness_controller],
        surface[:readiness_controller],
        surface[:startup_controller],
        surface[:json_controller],
      ].each do |controller|
        controller_class = "#{controller}_controller".camelize.constantize

        assert_same surface[:profile], controller_class.const_get(:HEALTH_PROFILE, false)
      end
    end
  end

  # One Rails process answers on every surface hostname. The wire probe body is now just "ok\n",
  # so the surface is no longer named in the response; instead every surface must route to its own
  # <realm>/<surface> controller namespace, and no two surfaces may share one. That is what keeps
  # a misdirected request between two hostnames from being silently served by the wrong surface.
  test "every surface routes health to a unique <realm>/<surface> controller namespace" do
    namespaces =
      SURFACES.map do |surface|
        controllers = [
          surface[:controller], surface[:liveness_controller], surface[:readiness_controller],
          surface[:startup_controller], surface[:json_controller],
        ]
        prefixes = controllers.map { |controller| controller.split("/").first(2).join("/") }

        assert_equal 1, prefixes.uniq.length,
                     "#{surface[:host]} spreads its health controllers across namespaces: #{prefixes.inspect}"

        prefixes.first
      end

    assert_equal namespaces.length, namespaces.uniq.length,
                 "two surfaces share a controller namespace: #{namespaces.inspect}"
  end

  test "all health controllers use the shared rendering concern" do
    SURFACES.each do |surface|
      [
        surface[:controller],
        surface[:liveness_controller],
        surface[:readiness_controller],
        surface[:startup_controller],
        surface[:json_controller],
      ].each do |controller|
        controller_class = "#{controller}_controller".camelize.constantize

        assert_includes controller_class.ancestors, ::HealthCheckRendering
      end
    end
  end

  test "GET /health is a text/plain four-line aggregate, never HTML or JSON, with no polling" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    get "/health"

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_not_equal "text/html", response.media_type
    assert_not_equal "application/json", response.media_type
    assert_match(/\Astatus: \w+\nstartup: \w+\nliveness: \w+\nreadiness: \w+\n\z/, response.body)
    assert_no_match(/<html|<!doctype/i, response.body)
    assert_no_match(/fetch\s*\(|setInterval|setTimeout|EventSource|WebSocket/i, response.body)
    assert_no_match(/health\.json/i, response.body)
  end

  # Two different refusals, and the difference is the point. Asking for JSON with an `Accept` header
  # is answered -- with plain text, because that is the only representation the endpoint has, and a
  # probe that 406s because its client sent a boilerplate `Accept` is a probe that reports an
  # outage. Asking for it with a `.json` path suffix is a 404, because `/api/v0/health.json` is a
  # real endpoint serving real JSON at nearly the same spelling, and answering the suffix with
  # text/plain would tell that caller it had reached the JSON one.
  test "GET /health answers an Accept header with text and does not route a .json suffix" do
    SURFACES.each do |surface|
      host! surface[:host]

      get "/health.json"

      assert_response :not_found, surface[:host]

      get "/health", headers: { "Accept" => "application/json" }

      assert_response :success
      assert_equal "text/plain", response.media_type
      assert_no_match(/\A\s*[{\[]/, response.body)
    end
  end

  test "text probes render \"ok\\n\" regardless of Accept header, and reject a format suffix" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    PROBES.each do |probe|
      [nil, "text/html", "*/*", "application/json"].each do |accept|
        headers = accept ? { "Accept" => accept } : {}

        get "/health/#{probe}", headers: headers

        assert_includes [200, 503], response.status
        assert_equal "text/plain", response.media_type
        assert_not_equal "application/json", response.media_type
        assert_includes ["ok\n", "unavailable\n"], response.body
        assert_not_predicate response, :redirect?
      end
    end

    # A format suffix is not a route here, so a browser-shaped request for one gets a 404 rather
    # than plain text under an HTML-looking URL.
    get "/health/readiness.html", headers: { "Accept" => "text/html" }

    assert_response :not_found

    get "/health/startup.html", headers: { "Accept" => "text/html" }

    assert_response :not_found
  end

  test "liveness remains dependency free" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    Health::ReadinessCheck.stub(:call, ->(_profile:) { raise RuntimeError, "readiness loaded" }) do
      ActiveRecord::Base.stub(:connection, -> { raise RuntimeError, "database touched" }) do
        get "/health/liveness"
      end
    end

    assert_response :success
    assert_equal "ok\n", response.body
    assert_equal "text/plain", response.media_type
  end

  test "readiness does not raise prosopite n plus one errors" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    assert_health_request_has_no_prosopite_n_plus_one("/health/readiness")
  end

  test "health snapshot does not raise prosopite n plus one errors" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    assert_health_request_has_no_prosopite_n_plus_one("/health")
  end

  test "startup remains dependency light" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    Health::Checks::Database.stub(:new, ->(*) { raise RuntimeError, "database check built" }) do
      get "/health/startup"
    end

    assert_response :success
    assert_equal "ok\n", response.body
  end

  test "app readiness ignores org-only dependencies" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")

    assert_readiness_does_not_build(OrgTicketRecord)
  end

  test "sign readiness ignores acme-only dependencies" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    assert_readiness_does_not_build(AppRpRecord)
  end

  test "new database base classes do not affect existing surfaces by default" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    new_record_base = Class.new(ApplicationRecord)

    assert_readiness_does_not_build(new_record_base)
  end

  test "probe status codes come from result status" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    assert_probe_status(:ok, :success)
    assert_probe_status(:degraded_acceptable, :success)
    assert_probe_status(:unready, :service_unavailable)
  end

  # An orchestrator acts on the verdict it is handed. A stored 200 keeps traffic going to an
  # instance that has since failed readiness, and a stored 503 keeps it away from one that has
  # recovered, so every health response has to be uncacheable - including the ones that are not
  # a successful probe render.
  test "no health response may be stored by a cache" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    get "/health"

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]

    PROBES.each do |probe|
      get "/health/#{probe}"

      assert_includes [200, 503], response.status
      assert_equal "no-store", response.headers["Cache-Control"], "/health/#{probe} may not be stored"
    end

    get "/api/v0/health.json", headers: { "Accept" => "application/json" }

    assert_includes [200, 503], response.status
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "a failing probe and a refused machine format are uncacheable too" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    unready = Health::CheckResult.new(
      check: :readiness,
      status: :unready,
      surface: Health::Profiles::SignApp.surface_label,
    )

    Health::ReadinessCheck.stub(:call, unready) do
      get "/health/readiness"
    end

    assert_response :service_unavailable
    assert_equal "unavailable\n", response.body
    assert_equal "no-store", response.headers["Cache-Control"]

    get "/api/v0/health.json", headers: { "Accept" => "text/html" }

    assert_response :not_acceptable
    assert_empty response.body
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "probe responses omit topology and exception details" do
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

    assert_equal "unavailable\n", response.body

    forbidden = %w(
      AppPrincipalRecord app_principal app_principal_replica writing reading localhost
      StandardError PG::ConnectionBad Mysql2 database failed
    )

    forbidden.each { |value| assert_not_includes response.body, value }
  end

  test "wrong host is not routed to public health" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://wrong.example.test/health", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://wrong.example.test/api/v0/health.json", method: :get)
    end
  end

  test "missing and inherited health profiles fail loudly" do
    missing =
      Class.new(::ApplicationController) do
        include ::HealthCheckRendering
      end
    inherited_parent =
      Class.new(::ApplicationController) do
        include ::HealthCheckRendering
      end
    inherited_parent.const_set(:HEALTH_PROFILE, Health::Profiles::App)
    inherited_child = Class.new(inherited_parent)

    assert_raises(Health::MissingProfileError) { missing.new.send(:health_profile) }
    assert_raises(Health::MissingProfileError) { inherited_child.new.send(:health_profile) }
  end

  # ------------------------------------------------------------------------------------------------
  # Machine JSON aggregate: GET /api/v0/health.json
  # ------------------------------------------------------------------------------------------------

  test "GET /api/v0/health.json is the pass/warn/fail schema on every declared surface" do
    SURFACES.each do |surface|
      host! surface[:host]

      stub_healthy do
        get "/api/v0/health.json", headers: { "Accept" => "application/json" }
      end

      assert_response :success, "#{surface[:host]} /api/v0/health.json"
      assert_equal "application/json", response.media_type
      assert_not_equal "text/plain", response.media_type
      assert_not_equal "text/html", response.media_type

      body = response.parsed_body

      assert_equal %w(checks status), body.keys.sort
      assert_equal %w(liveness readiness startup), body.fetch("checks").keys.sort
      assert_includes %w(pass warn fail), body.fetch("status")

      body.fetch("checks").each_value do |check|
        assert_equal %w(status), check.keys
        assert_includes %w(pass warn fail), check.fetch("status")
      end

      assert_equal "pass", body.fetch("status")
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "GET /api/v0/health.json refuses a non-JSON Accept with an empty 406" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    ["text/html", "text/plain"].each do |accept|
      get "/api/v0/health.json", headers: { "Accept" => accept }

      assert_response :not_acceptable, "Accept: #{accept}"
      assert_empty response.body
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "GET /api/v0/health.json is 200 on pass and 503 on fail, and a readiness outage keeps liveness passing" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    stub_healthy do
      get "/api/v0/health.json", headers: { "Accept" => "application/json" }
    end

    assert_response :success
    assert_equal "pass", response.parsed_body.fetch("status")

    unready = Health::CheckResult.new(
      check: :readiness, status: :unready, surface: Health::Profiles::SignApp.surface_label,
    )

    Health::ReadinessCheck.stub(:call, unready) do
      get "/api/v0/health.json", headers: { "Accept" => "application/json" }
    end

    assert_response :service_unavailable
    body = response.parsed_body

    assert_equal "fail", body.fetch("status")
    assert_equal "fail", body.dig("checks", "readiness", "status")
    assert_equal "pass", body.dig("checks", "liveness", "status")
    assert_equal "pass", body.dig("checks", "startup", "status")
  end

  test "GET /api/v0/health.json body leaks no internal detail" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    result = Health::CheckResult.new(
      check: :readiness,
      status: :unready,
      surface: Health::Profiles::SignApp.surface_label,
      dependencies: { "database" => "failed" },
    )

    Health::ReadinessCheck.stub(:call, result) do
      get "/api/v0/health.json", headers: { "Accept" => "application/json" }
    end

    forbidden = [
      Rails.root.to_s, "secret_key_base", "git", "AppPrincipalRecord", "PG::",
      "StandardError", "localhost", "database", "failed", "readiness loaded",
    ]

    forbidden.each { |value| assert_not_includes response.body, value }
    assert_no_match(/\.rb:\d+|backtrace|Traceback/, response.body)
  end

  test "every declared health surface executes its controller show actions" do
    SURFACES.each do |surface|
      host! surface[:host]

      profile = surface[:profile]
      liveness = Health::CheckResult.new(check: :liveness, status: :ok, surface: profile.surface_label)
      readiness = Health::CheckResult.new(
        check: :readiness,
        status: :ok,
        surface: profile.surface_label,
        dependencies: {},
      )
      startup = Health::CheckResult.new(check: :startup, status: :ok, surface: profile.surface_label)
      snapshot = Health::CheckResult.new(
        check: :health,
        status: :ok,
        surface: profile.surface_label,
        dependencies: {
          "liveness" => liveness.as_public_json,
          "readiness" => readiness.as_public_json,
          "startup" => startup.as_public_json,
        },
      )

      Health::LivenessCheck.stub(:call, liveness) do
        Health::ReadinessCheck.stub(:call, readiness) do
          Health::StartupCheck.stub(:call, startup) do
            Health::SnapshotCheck.stub(:call, snapshot) do
              get "/health"

              assert_response :success
              assert_equal "text/plain", response.media_type
              assert_equal "status: ok\nstartup: ok\nliveness: ok\nreadiness: ok\n", response.body

              PROBES.each do |probe|
                get "/health/#{probe}"

                assert_response :success
                assert_equal "text/plain", response.media_type
                assert_equal "ok\n", response.body
              end

              get "/api/v0/health.json", headers: { "Accept" => "application/json" }

              assert_response :success
              assert_equal "application/json", response.media_type
              assert_equal "pass", response.parsed_body.fetch("status")
            end
          end
        end
      end
    end
  end

  private

  def stub_healthy(&)
    profile = Health::Profiles::App
    ok = ->(check) { Health::CheckResult.new(check: check, status: :ok, surface: profile.surface_label) }

    Health::LivenessCheck.stub(:call, ok.call(:liveness)) do
      Health::ReadinessCheck.stub(:call, ok.call(:readiness)) do
        Health::StartupCheck.stub(:call, ok.call(:startup), &)
      end
    end
  end

  def assert_health_route(host, path, controller)
    recognized = Rails.application.routes.recognize_path("http://#{host}#{path}", method: :get)

    assert_equal controller, recognized[:controller]
    assert_equal "show", recognized[:action]
  end

  def assert_probe_status(status, expected_response)
    result = Health::CheckResult.new(
      check: :readiness,
      status: status,
      surface: Health::Profiles::SignApp.surface_label,
    )

    Health::ReadinessCheck.stub(:call, result) do
      get("/health/readiness")
    end

    assert_response expected_response
  end

  def assert_readiness_does_not_build(forbidden_record_class)
    Health::Checks::Database.stub(
      :new,
      lambda { |record_class:, **_options|
        raise RuntimeError, "unexpected dependency" if record_class == forbidden_record_class

        Struct.new(:result) do
          def call = result
        end.new(Health::DependencyResult.new(kind: :database, status: :ok))
      },
    ) do
      get("/health/readiness")
    end

    assert_response :success
  end

  def assert_health_request_has_no_prosopite_n_plus_one(path)
    Prosopite.pause do
      assert_nothing_raised do
        Prosopite.scan do
          get(path)
        end
      end
    end

    assert_includes [200, 503], response.status
    assert_predicate response.media_type, :present?

    Prosopite.pause do
      Prosopite.tc[:prosopite_query_counter] = Hash.new(0)
      Prosopite.tc[:prosopite_query_holder] = Hash.new { |h, k| h[k] = [] }
      Prosopite.tc[:prosopite_query_caller] = {}
    end
  end
end

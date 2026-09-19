# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CoreRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  BOOT_HOSTS = Rails.configuration.x.boot_config.fetch(:hosts)
  CORE_APP_HOST = ENV.fetch("PUBLIC_CORE_SERVICE_URL", BOOT_HOSTS.core_service.host)
  CORE_COM_HOST = ENV.fetch("PUBLIC_CORE_CORPORATE_URL", BOOT_HOSTS.core_corporate.host)
  CORE_ORG_HOST = ENV.fetch("PUBLIC_CORE_STAFF_URL", BOOT_HOSTS.core_staff.host)
  CORE_NET_HOST = ENV["PRIVATE_CORE_NETWORK_URL"] || ENV.fetch("PRIVATE_CORE_NETWORK_URL", "core.net.localhost")
  CORE_DEV_HOST = ENV["PRIVATE_CORE_DEVELOPER_URL"] || ENV.fetch("PRIVATE_CORE_DEVELOPER_URL", "core.dev.localhost")

  # Two request paths reach the Core app/com/org surfaces with different Host headers:
  # cloudflared forwards the browser-facing PUBLIC_* site name, while a request that arrives
  # directly on the compose `frontend` network carries the PRIVATE_* ingress alias. The
  # constraints used to list only the boot_config (PUBLIC_*) host, so every request on the
  # private alias fell through to Rails' welcome page and every other path 404'd.
  #
  # The alias is forced to a value the environment does not otherwise hold, so the assertion
  # cannot pass by the two families happening to agree in whichever environment runs it.
  test "core route contract accepts the private ingress alias alongside the public host" do
    aliases = {
      "PRIVATE_CORE_SERVICE_URL" => ["core-service.private.example", "core/app"],
      "PRIVATE_CORE_CORPORATE_URL" => ["core-corporate.private.example", "core/com"],
      "PRIVATE_CORE_STAFF_URL" => ["core-staff.private.example", "core/org"],
    }

    with_env(aliases.transform_values(&:first)) do
      aliases.each_value do |host, module_prefix|
        assert_recognizes(
          { controller: "#{module_prefix}/roots", action: "index" },
          { path: "http://#{host}/", method: :get },
        )

        assert_recognizes(
          { controller: "#{module_prefix}/health/livenesses", action: "show" },
          { path: "http://#{host}/health/liveness", method: :get },
        )
      end
    end
  end

  test "core route contract still accepts the public host while the private alias is set" do
    with_env(
      "PRIVATE_CORE_SERVICE_URL" => "core-service.private.example",
      "PRIVATE_CORE_CORPORATE_URL" => "core-corporate.private.example",
      "PRIVATE_CORE_STAFF_URL" => "core-staff.private.example",
    ) do
      {
        CORE_APP_HOST => "core/app",
        CORE_COM_HOST => "core/com",
        CORE_ORG_HOST => "core/org",
      }.each do |host, module_prefix|
        assert_recognizes(
          { controller: "#{module_prefix}/health/livenesses", action: "show" },
          { path: "http://#{host}/health/liveness", method: :get },
        )
      end
    end
  end

  test "core route contract does not accept a host outside both families" do
    with_env(
      "PRIVATE_CORE_SERVICE_URL" => "core-service.private.example",
    ) do
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://core-service.unrelated.example/health/liveness",
          method: :get,
        )
      end
    end
  end

  test "core surfaces do not expose dashboards" do
    [CORE_APP_HOST, CORE_COM_HOST, CORE_ORG_HOST, CORE_NET_HOST, CORE_DEV_HOST].each do |host|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/dashboard", method: :get)
      end
    end
  end

  test "core app route contract" do
    assert_recognizes(
      { controller: "core/app/roots", action: "index" },
      { path: "http://#{CORE_APP_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/well_known/jwks", action: "show" },
      { path: "http://#{CORE_APP_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/healths", action: "show" },
      { path: "http://#{CORE_APP_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/health/livenesses", action: "show" },
      { path: "http://#{CORE_APP_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/health/readinesses", action: "show" },
      { path: "http://#{CORE_APP_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/health/startups", action: "show" },
      { path: "http://#{CORE_APP_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/csp_violation_reports", action: "create" },
      { path: "http://#{CORE_APP_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "core/app/api/v0/preferences/cookies", action: "show" },
      { path: "http://#{CORE_APP_HOST}/api/v0/preferences/cookie", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/api/v0/preferences/cookies", action: "update" },
      { path: "http://#{CORE_APP_HOST}/api/v0/preferences/cookie", method: :patch },
    )

    assert_recognizes(
      { controller: "core/app/api/v0/preferences/themes", action: "show" },
      { path: "http://#{CORE_APP_HOST}/api/v0/preferences/theme", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/api/v0/preferences/themes", action: "update" },
      { path: "http://#{CORE_APP_HOST}/api/v0/preferences/theme", method: :patch },
    )

    assert_recognizes(
      { controller: "core/app/api/v0/preferences/dbsc", action: "create" },
      { path: "http://#{CORE_APP_HOST}/api/v0/preferences/dbsc", method: :post },
    )

    assert_recognizes(
      { controller: "core/app/api/v0/sessions", action: "show" },
      { path: "http://#{CORE_APP_HOST}/api/v0/session", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/api/v0/token/refreshes", action: "create" },
      { path: "http://#{CORE_APP_HOST}/api/v0/token/refresh", method: :post },
    )

    assert_recognizes(
      { controller: "core/app/oidc/callbacks", action: "show" },
      { path: "http://#{CORE_APP_HOST}/sign/in/callback", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/oidc/authorizations", action: "show" },
      { path: "http://#{CORE_APP_HOST}/sign/in", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_APP_HOST}/oidc/callback", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_APP_HOST}/oidc/authorization", method: :get)
    end

    assert_recognizes(
      { controller: "core/app/sign/outs", action: "new" },
      { path: "http://#{CORE_APP_HOST}/sign/out/new", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/sign/outs", action: "edit" },
      { path: "http://#{CORE_APP_HOST}/sign/out/edit", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/sign/outs", action: "create" },
      { path: "http://#{CORE_APP_HOST}/sign/out", method: :post },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_APP_HOST}/sign/out/complete", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_APP_HOST}/sign/out", method: :delete)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_APP_HOST}/sso/authorize", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_APP_HOST}/sso/logout", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_APP_HOST}/auth/acme", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_APP_HOST}/auth/acme/callback", method: :get)
    end

    assert_recognizes(
      { controller: "core/app/oidc/backchannel/logouts", action: "create" },
      { path: "http://#{CORE_APP_HOST}/oidc/backchannel/logout", method: :post },
    )
  end

  test "core com route contract" do
    assert_recognizes(
      { controller: "core/com/roots", action: "index" },
      { path: "http://#{CORE_COM_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/well_known/jwks", action: "show" },
      { path: "http://#{CORE_COM_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/healths", action: "show" },
      { path: "http://#{CORE_COM_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/health/livenesses", action: "show" },
      { path: "http://#{CORE_COM_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/health/readinesses", action: "show" },
      { path: "http://#{CORE_COM_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/health/startups", action: "show" },
      { path: "http://#{CORE_COM_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/csp_violation_reports", action: "create" },
      { path: "http://#{CORE_COM_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "core/com/api/v0/preferences/cookies", action: "show" },
      { path: "http://#{CORE_COM_HOST}/api/v0/preferences/cookie", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/api/v0/preferences/cookies", action: "update" },
      { path: "http://#{CORE_COM_HOST}/api/v0/preferences/cookie", method: :patch },
    )

    assert_recognizes(
      { controller: "core/com/api/v0/preferences/themes", action: "show" },
      { path: "http://#{CORE_COM_HOST}/api/v0/preferences/theme", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/api/v0/preferences/themes", action: "update" },
      { path: "http://#{CORE_COM_HOST}/api/v0/preferences/theme", method: :patch },
    )

    assert_recognizes(
      { controller: "core/com/api/v0/preferences/dbsc", action: "create" },
      { path: "http://#{CORE_COM_HOST}/api/v0/preferences/dbsc", method: :post },
    )

    assert_recognizes(
      { controller: "core/com/api/v0/sessions", action: "show" },
      { path: "http://#{CORE_COM_HOST}/api/v0/session", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/api/v0/token/refreshes", action: "create" },
      { path: "http://#{CORE_COM_HOST}/api/v0/token/refresh", method: :post },
    )

    assert_recognizes(
      { controller: "core/com/oidc/callbacks", action: "show" },
      { path: "http://#{CORE_COM_HOST}/sign/in/callback", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/oidc/authorizations", action: "show" },
      { path: "http://#{CORE_COM_HOST}/sign/in", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_COM_HOST}/oidc/callback", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_COM_HOST}/oidc/authorization", method: :get)
    end

    assert_recognizes(
      { controller: "core/com/sign/outs", action: "new" },
      { path: "http://#{CORE_COM_HOST}/sign/out/new", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/sign/outs", action: "edit" },
      { path: "http://#{CORE_COM_HOST}/sign/out/edit", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/sign/outs", action: "create" },
      { path: "http://#{CORE_COM_HOST}/sign/out", method: :post },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_COM_HOST}/sign/out/complete", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_COM_HOST}/sign/out", method: :delete)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_COM_HOST}/sso/authorize", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_COM_HOST}/sso/logout", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_COM_HOST}/auth/acme", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_COM_HOST}/auth/acme/callback", method: :get)
    end

    assert_recognizes(
      { controller: "core/com/oidc/backchannel/logouts", action: "create" },
      { path: "http://#{CORE_COM_HOST}/oidc/backchannel/logout", method: :post },
    )
  end

  # rubocop:disable Minitest/MultipleAssertions
  test "core org route contract" do
    assert_recognizes(
      { controller: "core/org/roots", action: "index" },
      { path: "http://#{CORE_ORG_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/well_known/jwks", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/healths", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/health/livenesses", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/health/readinesses", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/health/startups", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/csp_violation_reports", action: "create" },
      { path: "http://#{CORE_ORG_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "core/org/api/v0/preferences/cookies", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/api/v0/preferences/cookie", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/api/v0/preferences/cookies", action: "update" },
      { path: "http://#{CORE_ORG_HOST}/api/v0/preferences/cookie", method: :patch },
    )

    assert_recognizes(
      { controller: "core/org/api/v0/preferences/themes", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/api/v0/preferences/theme", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/api/v0/preferences/themes", action: "update" },
      { path: "http://#{CORE_ORG_HOST}/api/v0/preferences/theme", method: :patch },
    )

    assert_recognizes(
      { controller: "core/org/api/v0/preferences/dbsc", action: "create" },
      { path: "http://#{CORE_ORG_HOST}/api/v0/preferences/dbsc", method: :post },
    )

    assert_recognizes(
      { controller: "core/org/api/v0/sessions", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/api/v0/session", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/api/v0/token/refreshes", action: "create" },
      { path: "http://#{CORE_ORG_HOST}/api/v0/token/refresh", method: :post },
    )

    assert_recognizes(
      { controller: "core/org/oidc/callbacks", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/sign/in/callback", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/oidc/authorizations", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/sign/in", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_ORG_HOST}/oidc/callback", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_ORG_HOST}/oidc/authorization", method: :get)
    end

    assert_recognizes(
      { controller: "core/org/sign/outs", action: "new" },
      { path: "http://#{CORE_ORG_HOST}/sign/out/new", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/sign/outs", action: "edit" },
      { path: "http://#{CORE_ORG_HOST}/sign/out/edit", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/sign/outs", action: "create" },
      { path: "http://#{CORE_ORG_HOST}/sign/out", method: :post },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_ORG_HOST}/sign/out/complete", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_ORG_HOST}/sign/out", method: :delete)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_ORG_HOST}/sso/authorize", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_ORG_HOST}/sso/logout", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_ORG_HOST}/auth/acme", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_ORG_HOST}/auth/acme/callback", method: :get)
    end

    assert_recognizes(
      { controller: "core/org/oidc/backchannel/logouts", action: "create" },
      { path: "http://#{CORE_ORG_HOST}/oidc/backchannel/logout", method: :post },
    )
  end
  # rubocop:enable Minitest/MultipleAssertions

  test "core net route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_NET_HOST}/",
      method: :get,
    )

    assert_equal "core/net/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_NET_HOST}/health",
      method: :get,
    )

    assert_equal "core/net/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_NET_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "core/net/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_NET_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "core/net/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_NET_HOST}/health/startup",
      method: :get,
    )

    assert_equal "core/net/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_NET_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "core/net/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]
  end

  test "core dev route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_DEV_HOST}/",
      method: :get,
    )

    assert_equal "core/dev/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_DEV_HOST}/health",
      method: :get,
    )

    assert_equal "core/dev/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_DEV_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "core/dev/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_DEV_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "core/dev/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_DEV_HOST}/health/startup",
      method: :get,
    )

    assert_equal "core/dev/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_DEV_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "core/dev/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]
  end

  test "core retired routes do not resolve" do
    [CORE_APP_HOST, CORE_COM_HOST, CORE_ORG_HOST].each do |host|
      {
        get: %w(/web/v0/cookie /web/v0/theme /edge/v0/cookie /robots.txt /sitemap.xml),
        patch: %w(/web/v0/cookie /web/v0/theme /edge/v0/cookie),
        post: %w(/edge/v0/dbsc),
      }.each do |method, paths|
        paths.each do |path|
          assert_raises(ActionController::RoutingError) do
            Rails.application.routes.recognize_path("http://#{host}#{path}", method: method)
          end
        end
      end

      %w(cookie theme).each do |preference|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path(
            "http://#{host}/api/v0/preferences/#{preference}",
            method: :put,
          )
        end
      end
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_ORG_HOST}/configuration", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_APP_HOST}/oidc/backchannel_logout",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_COM_HOST}/oidc/backchannel_logout",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_ORG_HOST}/oidc/backchannel_logout",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_APP_HOST}/oidc/frontchannel_logout",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_COM_HOST}/oidc/frontchannel_logout",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_ORG_HOST}/oidc/frontchannel_logout",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_APP_HOST}/accounts",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_COM_HOST}/accounts",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_ORG_HOST}/accounts",
        method: :get,
      )
    end
  end

  test "core rails remains transitional and does not expose authorization server endpoints" do
    [CORE_APP_HOST, CORE_COM_HOST, CORE_ORG_HOST, CORE_NET_HOST, CORE_DEV_HOST].each do |host|
      %w(/authorize /token /userinfo /jwks /oauth/authorize /oauth/token /oauth/userinfo /oauth/jwks).each do |path|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("http://#{host}#{path}", method: :get)
        end
      end

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/oauth/token", method: :post)
      end
    end
  end

  private

  # Route constraints read ENV when the route set is drawn, so the routes have to be
  # redrawn for an override to take effect and redrawn again to put them back.
  def with_env(overrides)
    original = overrides.keys.index_with { |key| ENV[key] }
    overrides.each { |key, value| ENV[key] = value }
    Rails.application.reload_routes!
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    Rails.application.reload_routes!
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BaseRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  BASE_APP_HOST = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
  BASE_COM_HOST = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
  BASE_ORG_HOST = ENV.fetch("PUBLIC_BASE_STAFF_URL")

  # Every path on these hosts resolves inside the host's own module. Health and revision used to
  # resolve to Base::App instead, which left the hosts unable to name themselves in a health
  # response and left Base::Net and Base::Dev controllers on disk that no route reached.
  test "base private network and developer hosts route entirely within their own modules" do
    {
      "base.net.localhost" => "base/net",
      "base.dev.localhost" => "base/dev",
    }.each do |host, module_prefix|
      {
        ["/", :get] => ["roots", "index"],
        ["/revision", :get] => ["revisions", "show"],
        ["/health", :get] => ["healths", "show"],
        ["/health/liveness", :get] => ["health/livenesses", "show"],
        ["/health/readiness", :get] => ["health/readinesses", "show"],
        ["/health/startup", :get] => ["health/startups", "show"],
        ["/csp-violation-report", :post] => ["csp_violation_reports", "create"],
      }.each do |(path, method), (controller, action)|
        recognized = Rails.application.routes.recognize_path("http://#{host}#{path}", method: method)

        assert_equal "#{module_prefix}/#{controller}", recognized[:controller]
        assert_equal action, recognized[:action]
      end
    end
  end

  # rubocop:disable Minitest/MultipleAssertions
  test "base app route contract" do
    [Rails.configuration.x.boot_config.fetch(:hosts).base_service.host, "www.umaxica.app",
     BASE_APP_HOST,].uniq.each do |host|
      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/",
        method: :get,
      )

      assert_equal "base/app/roots", recognized[:controller]
      assert_equal "index", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/health",
        method: :get,
      )

      assert_equal "base/app/healths", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/health/liveness",
        method: :get,
      )

      assert_equal "base/app/health/livenesses", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/health/readiness",
        method: :get,
      )

      assert_equal "base/app/health/readinesses", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/health/startup",
        method: :get,
      )

      assert_equal "base/app/health/startups", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/robots.txt",
        method: :get,
      )

      assert_equal "base/app/robots", recognized[:controller]
      assert_equal "index", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/sitemap.xml",
        method: :get,
      )

      assert_equal "base/app/sitemaps", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/identity/emails",
        method: :get,
      )

      assert_equal "base/app/identity/emails", recognized[:controller]
      assert_equal "index", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/groups",
        method: :get,
      )

      assert_equal "base/app/groups", recognized[:controller]
      assert_equal "index", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/dashboard",
        method: :get,
      )

      assert_equal "base/app/dashboards", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/oidc/authorization",
        method: :get,
      )

      assert_equal "base/app/oidc/authorizations", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/oidc/callback",
        method: :get,
      )

      assert_equal "base/app/oidc/callbacks", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/oauth/authorize",
        method: :get,
      )

      assert_equal "base/app/oauth/authorizations", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/oauth/token",
        method: :post,
      )

      assert_equal "base/app/oauth/tokens", recognized[:controller]
      assert_equal "create", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/oauth/userinfo",
        method: :get,
      )

      assert_equal "base/app/oauth/userinfos", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/oauth/revoke",
        method: :post,
      )

      assert_equal "base/app/oauth/revocations", recognized[:controller]
      assert_equal "create", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/oidc/logout",
        method: :get,
      )

      assert_equal "base/app/oidc/logouts", recognized[:controller]
      assert_equal "show", recognized[:action]

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/oidc", method: :get)
      end

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/sign/out/new",
        method: :get,
      )

      assert_equal "base/app/sign_outs", recognized[:controller]
      assert_equal "new", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/sign/out",
        method: :post,
      )

      assert_equal "base/app/sign_outs", recognized[:controller]
      assert_equal "create", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/lobby",
        method: :get,
      )

      assert_equal "base/app/lobbies", recognized[:controller]
      assert_equal "show", recognized[:action]

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/sign/out/complete", method: :get)
      end

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/sign/out", method: :delete)
      end

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/csp-violation-report",
        method: :post,
      )

      assert_equal "base/app/csp_violation_reports", recognized[:controller]
      assert_equal "create", recognized[:action]
    end
  end
  # rubocop:enable Minitest/MultipleAssertions

  # rubocop:disable Minitest/MultipleAssertions
  test "base com route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/",
      method: :get,
    )

    assert_equal "base/com/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/health",
      method: :get,
    )

    assert_equal "base/com/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "base/com/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "base/com/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/health/startup",
      method: :get,
    )

    assert_equal "base/com/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/robots.txt",
      method: :get,
    )

    assert_equal "base/com/robots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/sitemap.xml",
      method: :get,
    )

    assert_equal "base/com/sitemaps", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/dashboard",
      method: :get,
    )

    assert_equal "base/com/dashboards", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/oidc/authorization",
      method: :get,
    )

    assert_equal "base/com/oidc/authorizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/oidc/callback",
      method: :get,
    )

    assert_equal "base/com/oidc/callbacks", recognized[:controller]
    assert_equal "show", recognized[:action]

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_COM_HOST}/oidc", method: :get)
    end

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/sign/out/new",
      method: :get,
    )

    assert_equal "base/com/sign_outs", recognized[:controller]
    assert_equal "new", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/sign/out/edit",
      method: :get,
    )

    assert_equal "base/com/sign_outs", recognized[:controller]
    assert_equal "edit", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/sign/out",
      method: :post,
    )

    assert_equal "base/com/sign_outs", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/lobby",
      method: :get,
    )

    assert_equal "base/com/lobbies", recognized[:controller]
    assert_equal "show", recognized[:action]

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_COM_HOST}/sign/out/complete", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_COM_HOST}/sign/out", method: :delete)
    end

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "base/com/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]
  end
  # rubocop:enable Minitest/MultipleAssertions

  # rubocop:disable Minitest/MultipleAssertions
  test "base org route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/",
      method: :get,
    )

    assert_equal "base/org/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/health",
      method: :get,
    )

    assert_equal "base/org/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "base/org/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "base/org/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/health/startup",
      method: :get,
    )

    assert_equal "base/org/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/robots.txt",
      method: :get,
    )

    assert_equal "base/org/robots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/sitemap.xml",
      method: :get,
    )

    assert_equal "base/org/sitemaps", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/dashboard",
      method: :get,
    )

    assert_equal "base/org/dashboards", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/oidc/authorization",
      method: :get,
    )

    assert_equal "base/org/oidc/authorizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/oidc/callback",
      method: :get,
    )

    assert_equal "base/org/oidc/callbacks", recognized[:controller]
    assert_equal "show", recognized[:action]

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/oidc", method: :get)
    end

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/sign/out/new",
      method: :get,
    )

    assert_equal "base/org/sign_outs", recognized[:controller]
    assert_equal "new", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/sign/out/edit",
      method: :get,
    )

    assert_equal "base/org/sign_outs", recognized[:controller]
    assert_equal "edit", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/sign/out",
      method: :post,
    )

    assert_equal "base/org/sign_outs", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/lobby",
      method: :get,
    )

    assert_equal "base/org/lobbies", recognized[:controller]
    assert_equal "show", recognized[:action]

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/sign/out/complete", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/sign/out", method: :delete)
    end

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "base/org/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]
  end
  # rubocop:enable Minitest/MultipleAssertions
end

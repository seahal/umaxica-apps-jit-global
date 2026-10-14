# typed: false
# frozen_string_literal: true

require "test_helper"

class TechRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  TECH_HOST = "tech.org.localhost"

  test "Tech exposes the operator dashboard and browser RP entrypoints" do
    assert_recognizes(
      { controller: "tech/org/roots", action: "index" },
      { path: "http://#{TECH_HOST}/", method: :get },
    )
    assert_recognizes(
      { controller: "tech/org/dashboards", action: "show" },
      { path: "http://#{TECH_HOST}/dashboard", method: :get },
    )
    assert_recognizes(
      { controller: "tech/org/sign/entries", action: "show" },
      { path: "http://#{TECH_HOST}/sign", method: :get },
    )
    assert_recognizes(
      { controller: "tech/org/sign/entries", action: "create" },
      { path: "http://#{TECH_HOST}/sign", method: :post },
    )
    assert_recognizes(
      { controller: "tech/org/oidc/callbacks", action: "show" },
      { path: "http://#{TECH_HOST}/oidc/callback", method: :get },
    )
  end

  test "Tech exposes only the declared health, revision, CSP, and sign-out routes" do
    assert_recognizes(
      { controller: "tech/org/healths", action: "show" },
      { path: "http://#{TECH_HOST}/health", method: :get },
    )
    assert_recognizes(
      { controller: "tech/org/api/v0/healths", action: "show" },
      { path: "http://#{TECH_HOST}/api/v0/health.json", method: :get },
    )
    assert_recognizes(
      { controller: "tech/org/revisions", action: "show" },
      { path: "http://#{TECH_HOST}/revision", method: :get },
    )
    assert_recognizes(
      { controller: "tech/org/api/v0/revisions", action: "show" },
      { path: "http://#{TECH_HOST}/api/v0/revision.json", method: :get },
    )
    assert_recognizes(
      { controller: "tech/org/csp_violation_reports", action: "create" },
      { path: "http://#{TECH_HOST}/csp-violation-report", method: :post },
    )
    assert_recognizes(
      { controller: "tech/org/sign/outs", action: "show" },
      { path: "http://#{TECH_HOST}/sign/out", method: :get },
    )
    assert_recognizes(
      { controller: "tech/org/sign/outs", action: "create" },
      { path: "http://#{TECH_HOST}/sign/out", method: :post },
    )
    assert_recognizes(
      { controller: "tech/org/sign/out/completions", action: "show" },
      { path: "http://#{TECH_HOST}/sign/out/completion", method: :get },
    )
    assert_recognizes(
      { controller: "tech/org/sign/out/completions", action: "create" },
      { path: "http://#{TECH_HOST}/sign/out/completion", method: :post },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{TECH_HOST}/api/v0/profile", method: :get)
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{TECH_HOST}/oidc/authorization", method: :get)
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{TECH_HOST}/oidc/backchannel/logout", method: :post)
    end
  end
end

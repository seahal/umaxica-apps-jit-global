# frozen_string_literal: true

require "test_helper"

class AppRailsEdgeOwnershipContractTest < ActiveSupport::TestCase
  RAILS_OWNED = [
    [ENV.fetch("PRIVATE_CORE_SERVICE_URL"), :get, "/", "core/app/roots", "index"],
    [ENV.fetch("PRIVATE_CORE_SERVICE_URL"), :get, "/oidc/authorization", "core/app/oidc/authorizations", "show"],
    [ENV.fetch("PRIVATE_CORE_SERVICE_URL"), :get, "/oidc/callback", "core/app/oidc/callbacks", "show"],
    [ENV.fetch("PRIVATE_CORE_SERVICE_URL"), :post, "/oidc/backchannel/logout", "core/app/oidc/backchannel/logouts",
     "create",],
    [ENV.fetch("PRIVATE_CORE_SERVICE_URL"), :get, "/api/v0/session", "core/app/api/v0/sessions", "show"],
    [ENV.fetch("PRIVATE_CORE_SERVICE_URL"), :post, "/api/v0/token/refresh", "core/app/api/v0/token/refreshes",
     "create",],
    [ENV.fetch("PRIVATE_CORE_SERVICE_URL"), :get, "/sign/out/new", "core/app/sign/outs", "new"],
    [ENV.fetch("PRIVATE_CORE_SERVICE_URL"), :get, "/sign/out/edit", "core/app/sign/outs", "edit"],
    [ENV.fetch("PRIVATE_CORE_SERVICE_URL"), :post, "/sign/out", "core/app/sign/outs", "create"],
    [ENV.fetch("PRIVATE_CORE_SERVICE_URL"), :get, "/sign/out/complete", "core/app/sign/outs/completions", "show"],
    [ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), :get, "/sign/in", "auth/app/sign/ins", "show"],
    [ENV.fetch("PUBLIC_BASE_SERVICE_URL"), :get, "/lobby", "base/app/lobbies", "show"],
    [ENV.fetch("PUBLIC_BASE_SERVICE_URL"), :get, "/dashboard", "base/app/dashboards", "show"],
    [ENV.fetch("PUBLIC_SIDE_SERVICE_URL"), :get, "/dashboard", "side/app/dashboards", "show"],
  ].freeze

  test "app route ownership keeps Rails authentication, sign-out, API, and retained UI endpoints" do
    mismatches =
      RAILS_OWNED.filter_map do |host, method, path, expected_controller, expected_action|
        route = Rails.application.routes.recognize_path("http://#{host}#{path}", method: method)
        next if route[:controller] == expected_controller && route[:action] == expected_action

        "#{method.upcase} #{host}#{path}: #{route[:controller]}##{route[:action]}"
      rescue ActionController::RoutingError => e
        "#{method.upcase} #{host}#{path}: #{e.class}"
      end

    assert_empty mismatches
  end

  test "Core legacy page aliases are absent from Rails" do
    core_host = ENV.fetch("PRIVATE_CORE_SERVICE_URL")

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{core_host}/dashboard", method: :get)
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{core_host}/sso/authorize", method: :get)
    end
  end

  test "Base sign-out completion remains the lobby rather than a public completion route" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{base_host}/sign/out/complete", method: :get)
    end
  end

  test "state-changing app endpoints reject GET routing" do
    core_host = ENV.fetch("PRIVATE_CORE_SERVICE_URL")

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{core_host}/api/v0/token/refresh", method: :get)
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{core_host}/sign/out", method: :get)
    end
  end
end

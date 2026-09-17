# typed: false
# frozen_string_literal: true

require "test_helper"

class CycleCloseAuthenticatedRootsTest < ActionDispatch::IntegrationTest
  ROOTS = [
    ["PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"],
    ["PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost"],
    ["PUBLIC_AUTH_STAFF_URL", "auth.org.localhost"],
    ["PUBLIC_BASE_SERVICE_URL", "base.app.localhost"],
    ["PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"],
    ["PUBLIC_BASE_STAFF_URL", "base.org.localhost"],
    ["PUBLIC_CORE_SERVICE_URL", "core.app.localhost"],
    ["PUBLIC_CORE_CORPORATE_URL", "core.com.localhost"],
    ["PUBLIC_CORE_STAFF_URL", "core.org.localhost"],
    ["SIDE_SERVICE_URL", "wide.app.localhost"],
    ["SIDE_CORPORATE_URL", "wide.com.localhost"],
    ["SIDE_STAFF_URL", "wide.org.localhost"],
    ["PUBLIC_EDIT_STAFF_URL", "edit.org.localhost"],
    ["PUBLIC_PALM_SERVICE_URL", "palm.app.localhost"],
  ].freeze

  test "fourteen in-scope roots answer on their host and do not open-redirect" do
    ROOTS.each do |env_key, fallback|
      host = ENV.fetch(env_key, fallback)
      get "/", params: { ri: "jp" }, headers: { "Host" => host }

      assert_includes [200, 302, 303, 401], response.status, host
      next unless response.redirect?

      location = URI.parse(response.location)

      assert_not_equal "evil.example", location.host, host
      assert_not_includes location.to_s, "://evil.", host
    end
  end

  test "retired dashboard and lobby paths stay unrouted" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    %w(/dashboard /lobby).each do |path|
      get path, params: { ri: "jp" }, headers: { "Host" => host }

      assert_response :not_found, path
    end
  end

  test "an unrecognized ri does not redirect off-host" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")

    get "/", params: { ri: "https://evil.example" }, headers: { "Host" => host }

    assert_includes [200, 302, 303, 400], response.status
    if response.redirect?
      assert_not_includes response.location, "evil.example"
    end
  end
end

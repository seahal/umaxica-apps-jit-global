# typed: false
# frozen_string_literal: true

require "test_helper"

# Every surface declares its own default web limiter on its application
# controller, each with its own scope name, and the limiter is the only thing
# standing between an unauthenticated caller and unbounded traffic to that
# surface. A scope name that collides with another surface, a store that is not
# wired up, or a refusal handler that is never reached all look like a passing
# suite otherwise, because nothing else exercises the limiter itself.
#
# Each case sends the full quota and then one more request, so it also pins that
# the quota is not off by one in either direction.
class SurfaceDefaultWebRateLimitTest < ActionDispatch::IntegrationTest
  counts_rate_limits!
  self.fixture_table_names = []

  DEFAULT_WEB_QUOTA = 300

  SURFACES = {
    "base app" => ["PUBLIC_BASE_SERVICE_URL", :base_app_dashboard_path],
    "base com" => ["PUBLIC_BASE_CORPORATE_URL", :base_com_dashboard_path],
    "base org" => ["PUBLIC_BASE_STAFF_URL", :base_org_dashboard_path],
    "base developer" => [nil, :base_developer_root_path],
    "auth app" => ["PUBLIC_AUTH_SERVICE_URL", :auth_app_dashboard_path],
    "auth com" => ["PUBLIC_AUTH_CORPORATE_URL", :auth_com_dashboard_path],
    "auth org" => ["PUBLIC_AUTH_STAFF_URL", :auth_org_dashboard_path],
    "core app" => ["PUBLIC_CORE_SERVICE_URL", :core_app_web_v0_theme_path],
    "core com" => ["PUBLIC_CORE_CORPORATE_URL", :core_com_web_v0_theme_path],
    "core org" => ["PUBLIC_CORE_STAFF_URL", :core_org_web_v0_theme_path],
    "side app" => ["PUBLIC_SIDE_SERVICE_URL", :side_app_dashboard_path],
    "side com" => ["PUBLIC_SIDE_CORPORATE_URL", :side_com_dashboard_path],
    "side org" => ["PUBLIC_SIDE_STAFF_URL", :side_org_dashboard_path],
    "palm app" => ["PUBLIC_PALM_SERVICE_URL", :palm_app_sign_out_path],
  }.freeze

  setup { Rails.configuration.x.rate_limit.fetch(:store).clear }
  teardown { Rails.configuration.x.rate_limit.fetch(:store).clear }

  SURFACES.each do |surface, (env_name, helper)|
    test "#{surface} answers the request past its default web quota with a retry hint" do
      host!(env_name ? ENV.fetch(env_name) : "base.dev.localhost")

      DEFAULT_WEB_QUOTA.times { get public_send(helper, ri: "jp") }

      assert_not_equal 429, response.status,
                       "#{surface} refused a request inside its quota of #{DEFAULT_WEB_QUOTA}"

      get public_send(helper, ri: "jp")

      assert_response :too_many_requests
      assert_equal "60", response.headers["Retry-After"]
    end
  end
end

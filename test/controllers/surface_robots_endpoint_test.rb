# typed: false
# frozen_string_literal: true

require "test_helper"

# public_robots_routing_test.rb covers the base, core, acme and palm surfaces.
# The Warp surfaces and the two corporate/staff auth surfaces answer /robots.txt
# from their own controllers, and each of those is a separate crawl directive:
# a surface that silently 404s here is one a crawler is free to index.
class SurfaceRobotsEndpointTest < ActionDispatch::IntegrationTest
  SURFACE_HOSTS = {
    "warp_app" => "PUBLIC_WARP_SERVICE_URL",
    "warp_com" => "PUBLIC_WARP_CORPORATE_URL",
    "warp_org" => "PUBLIC_WARP_STAFF_URL",
    "auth_com" => "PRIVATE_AUTH_CORPORATE_URL",
    "auth_org" => "PRIVATE_AUTH_STAFF_URL",
  }.freeze

  SURFACE_HOSTS.each do |prefix, env_name|
    test "#{prefix} serves robots.txt as plain text from its own host" do
      host! ENV.fetch(env_name)

      get public_send("#{prefix}_robots_path"), headers: { "Client-Agent" => "Mozilla/5.0" }

      assert_response :success
      assert_equal "text/plain; charset=utf-8", response.content_type
      assert_equal "User-agent: *\nDisallow:\n", response.body
    end
  end
end

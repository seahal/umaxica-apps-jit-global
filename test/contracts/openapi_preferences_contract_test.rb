# frozen_string_literal: true

require "test_helper"
require_relative "../support/openapi_contract"

# Validates `/api/v0/preferences/{theme,cookie}` against each surface description on every host that
# serves it. The description lists Base, Auth, Core, and Warp hosts in the path-level `servers`; all
# four answer with the same contract.
class OpenapiPreferencesContractTest < ActionDispatch::IntegrationTest
  include OpenapiContract

  SURFACE_HOST_KEYS = { "app" => "SERVICE", "com" => "CORPORATE", "org" => "STAFF" }.freeze
  JSON_HEADERS = { "Accept" => "application/json", "Content-Type" => "application/json" }.freeze

  %w(base auth core warp).product(%w(app com org)).each do |family, surface|
    test "#{family} #{surface} preference endpoints conform to the #{surface} description" do
      self.openapi_surface = surface
      host! ENV.fetch("PUBLIC_#{family.upcase}_#{SURFACE_HOST_KEYS.fetch(surface)}_URL")

      get "/api/v0/preferences/theme", headers: { "Accept" => "application/json" }

      assert_response :ok
      assert_openapi_conform 200

      get "/api/v0/preferences/cookie", headers: { "Accept" => "application/json" }

      assert_response :ok
      assert_openapi_conform 200

      patch "/api/v0/preferences/theme", params: { theme: "dark" }.to_json, headers: JSON_HEADERS

      assert_response :ok
      assert_openapi_conform 200

      patch "/api/v0/preferences/cookie", params: { cookie: { consented: true, functional: false } }.to_json,
                                          headers: JSON_HEADERS

      assert_response :no_content
      assert_openapi_conform 204

      patch "/api/v0/preferences/theme", params: { theme: "sepia" }.to_json, headers: JSON_HEADERS

      assert_response :unprocessable_content
      assert_openapi_response_conform 422

      patch "/api/v0/preferences/theme", params: "theme=dark",
                                         headers: { "Accept" => "application/json", "Content-Type" => "text/plain" }

      assert_response :unsupported_media_type
      assert_openapi_response_conform 415
    end
  end
end

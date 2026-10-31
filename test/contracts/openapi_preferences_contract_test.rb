# frozen_string_literal: true

require "test_helper"
require_relative "../support/openapi_contract"

# Validates `/api/v0/preferences/{theme,cookie}` against each surface description on every host that
# serves it. The com surface is anonymous and serves the API only from Base; app and org keep the
# Base, Auth, Core, and Warp hosts, all answering with the same contract.
class OpenapiPreferencesContractTest < ActionDispatch::IntegrationTest
  include OpenapiContract

  SURFACE_HOST_KEYS = { "app" => "SERVICE", "com" => "CORPORATE", "org" => "STAFF" }.freeze
  JSON_HEADERS = { "Accept" => "application/json", "Content-Type" => "application/json" }.freeze

  (%w(base auth core warp).product(%w(app org)) + [["base", "com"]]).each do |family, surface|
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

      if surface == "com"
        patch "/api/v0/preferences/theme", params: { theme: "DARK" }.to_json, headers: JSON_HEADERS

        assert_response :ok
        assert_openapi_conform 200
      end

      patch "/api/v0/preferences/cookie", params: { cookie: { consented: true, functional: false } }.to_json,
                                          headers: JSON_HEADERS

      if surface == "com"
        assert_response :ok
        assert_openapi_conform 200
      else
        assert_response :no_content
        assert_openapi_conform 204
      end

      patch "/api/v0/preferences/theme", params: { theme: "sepia" }.to_json, headers: JSON_HEADERS

      assert_response :unprocessable_content
      assert_openapi_response_conform 422

      patch "/api/v0/preferences/theme", params: "theme=dark",
                                         headers: { "Accept" => "application/json", "Content-Type" => "text/plain" }

      assert_response :unsupported_media_type
      assert_openapi_response_conform 415
    end
  end
  test "base com Web Push preference conforms to the com description" do
    self.openapi_surface = "com"
    host! ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    get "/api/v0/preferences/web_push", headers: { "Accept" => "application/json" }

    assert_response :ok
    assert_openapi_conform 200

    patch "/api/v0/preferences/web_push", params: { web_push: "enabled" }.to_json, headers: JSON_HEADERS

    assert_response :ok
    assert_openapi_conform 200

    patch "/api/v0/preferences/web_push", params: { web_push: "invalid" }.to_json, headers: JSON_HEADERS

    assert_response :unprocessable_content
    assert_openapi_response_conform 422
  end

  test "com preference APIs describe ambiguous cookie and storage failure responses" do
    self.openapi_surface = "com"
    host! ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    https!
    duplicate = "#{PreferenceCookieName.anonymous_jwt}=first; #{PreferenceCookieName.anonymous_jwt}=second"
    ["/api/v0/preferences/theme", "/api/v0/preferences/cookie", "/api/v0/preferences/web_push"].each do |path|
      get path, headers: { "Accept" => "application/json", "Cookie" => duplicate }

      assert_response :bad_request
      assert_openapi_response_conform 400

      patch path, params: {}.to_json, headers: JSON_HEADERS.merge("Cookie" => duplicate)

      assert_response :bad_request
      assert_openapi_response_conform 400
    end

    [
      ["/api/v0/preferences/theme", { theme: "dark" }],
      ["/api/v0/preferences/cookie", { consented: true }],
      ["/api/v0/preferences/web_push", { web_push: "enabled" }],
    ].each do |path, body|
      PreferenceToken.stub(:encode, nil) do
        patch path, params: body.to_json, headers: JSON_HEADERS
      end

      assert_response :service_unavailable
      assert_equal "application/problem+json", response.media_type
      assert_openapi_response_conform 503
    end
  end

  test "com consent and Web Push describe a mismatched browser binding" do
    self.openapi_surface = "com"
    host! ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    https!
    patch "/api/v0/preferences/cookie", params: { consented: true }.to_json, headers: JSON_HEADERS

    assert_response :ok
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = PreferenceBrowserBinding.mint_value
    [
      ["/api/v0/preferences/cookie", { consented: false }],
      ["/api/v0/preferences/web_push", { web_push: "enabled" }],
    ].each do |path, body|
      patch path, params: body.to_json, headers: JSON_HEADERS

      assert_response :forbidden
      assert_equal "application/problem+json", response.media_type
      assert_openapi_response_conform 403
    end
  end
end

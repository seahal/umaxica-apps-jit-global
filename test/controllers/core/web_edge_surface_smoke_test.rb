# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CorePreferenceApiSurfaceSmokeTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      host: ENV.fetch("PUBLIC_CORE_SERVICE_URL"),
      cookie_path: "/api/v0/preferences/cookie",
      theme_path: "/api/v0/preferences/theme",
    },
    {
      host: ENV.fetch("PUBLIC_CORE_STAFF_URL"),
      cookie_path: "/api/v0/preferences/cookie",
      theme_path: "/api/v0/preferences/theme",
    },
  ].freeze

  test "core preference API endpoints expose reads and refuse writes on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      get "https://#{host}#{surface.fetch(:cookie_path)}", params: { ri: "jp" }

      assert_response :success
      assert_equal "application/json", response.media_type

      patch "https://#{host}#{surface.fetch(:cookie_path)}", params: { ri: "jp", value: "1" }, as: :json

      assert_response :forbidden
      assert_equal "application/problem+json", response.media_type

      patch "https://#{host}#{surface.fetch(:cookie_path)}", params: { cookie: { consented: true } }, as: :json

      assert_response :forbidden

      get "https://#{host}#{surface.fetch(:theme_path)}", params: { ri: "jp" }

      assert_response :success
      assert_equal "application/json", response.media_type

      patch "https://#{host}#{surface.fetch(:theme_path)}", params: { ri: "jp", value: "dark" }, as: :json

      assert_response :forbidden

      patch "https://#{host}#{surface.fetch(:theme_path)}", params: { theme: "dark" }, as: :json

      assert_response :forbidden
    end
  end
end

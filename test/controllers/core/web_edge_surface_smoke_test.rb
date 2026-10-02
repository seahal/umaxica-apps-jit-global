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
      dbsc_path: "/api/v0/preferences/dbsc",
    },
    {
      host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL"),
      cookie_path: "/api/v0/preferences/cookie",
      theme_path: "/api/v0/preferences/theme",
      dbsc_path: "/api/v0/preferences/dbsc",
    },
    {
      host: ENV.fetch("PUBLIC_CORE_STAFF_URL"),
      cookie_path: "/api/v0/preferences/cookie",
      theme_path: "/api/v0/preferences/theme",
      dbsc_path: "/api/v0/preferences/dbsc",
    },
  ].freeze

  test "core preference API endpoints are executable on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      get "https://#{host}#{surface.fetch(:cookie_path)}", params: { ri: "jp" }

      assert_response :success
      assert_equal "application/json", response.media_type

      # A body without a consent decision is a validation problem, not a credential failure.
      patch "https://#{host}#{surface.fetch(:cookie_path)}", params: { ri: "jp", value: "1" }, as: :json

      assert_response :unprocessable_content
      assert_equal "application/problem+json", response.media_type
      assert_equal ["/cookie/consented"], response.parsed_body.fetch("errors").pluck("pointer")

      patch "https://#{host}#{surface.fetch(:cookie_path)}", params: { cookie: { consented: true } }, as: :json

      assert_response :no_content

      get "https://#{host}#{surface.fetch(:theme_path)}", params: { ri: "jp" }

      assert_response :success
      assert_equal "application/json", response.media_type

      patch "https://#{host}#{surface.fetch(:theme_path)}", params: { ri: "jp", value: "dark" }, as: :json

      assert_response :unprocessable_content
      assert_equal ["/theme"], response.parsed_body.fetch("errors").pluck("pointer")

      patch "https://#{host}#{surface.fetch(:theme_path)}", params: { theme: "dark" }, as: :json

      assert_response :success
      assert_equal "application/json", response.media_type
      assert_equal "dr", response.parsed_body.fetch("theme")

      post "https://#{host}#{surface.fetch(:dbsc_path)}", params: { ri: "jp" }, as: :json

      assert_response :unprocessable_content
      assert_equal "missing_proof", response.parsed_body.fetch("error_code")
    end
  end
end

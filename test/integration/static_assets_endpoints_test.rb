# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StaticAssetsEndpointsTest < ActionDispatch::IntegrationTest
  ROBOTS_SURFACES = [
    {
      host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
      controller: "base/com/robots",
    },
    {
      host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
      controller: "base/org/robots",
    },
    {
      host: ENV.fetch("PUBLIC_PALM_SERVICE_URL"),
      controller: "palm/app/robots",
    },
  ].freeze

  # Every surface that still declares a sitemaps controller belongs here. Core no longer routes
  # `/robots.txt` or `/sitemap.xml`; those files are an Edge/Next concern on Core hosts.
  SITEMAP_SURFACES = [
    {
      host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      controller: "auth/app/sitemaps",
    },
    {
      host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost"),
      controller: "auth/com/sitemaps",
    },
    {
      host: ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost"),
      controller: "auth/org/sitemaps",
    },
    {
      host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
      controller: "base/app/sitemaps",
    },
    {
      host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
      controller: "base/com/sitemaps",
    },
    {
      host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
      controller: "base/org/sitemaps",
    },
    {
      host: ENV.fetch("PUBLIC_PALM_SERVICE_URL"),
      controller: "palm/app/sitemaps",
    },
    {
      host: ENV.fetch("PUBLIC_WARP_SERVICE_URL", "warp.app.localhost"),
      controller: "warp/app/sitemaps",
    },
    {
      host: ENV.fetch("PUBLIC_WARP_CORPORATE_URL", "warp.com.localhost"),
      controller: "warp/com/sitemaps",
    },
    {
      host: ENV.fetch("PUBLIC_WARP_STAFF_URL", "warp.org.localhost"),
      controller: "warp/org/sitemaps",
    },
  ].freeze

  test "robots.txt is served on every configured surface" do
    ROBOTS_SURFACES.each do |surface|
      host! surface[:host]

      get "/robots.txt"

      assert_response :success
      assert_equal "text/plain", response.media_type
      assert_includes response.body, "User-agent:"

      assert_equal "index", @request.params[:action]
      assert_equal surface[:controller], @request.params[:controller]
    end
  end

  test "sitemap.xml is served on every surface that declares a sitemaps controller" do
    SITEMAP_SURFACES.each do |surface|
      host! surface[:host]

      get "/sitemap.xml"

      assert_response :success
      assert_equal "application/xml", response.media_type
      assert_includes response.body, "<urlset"

      assert_equal "show", @request.params[:action]
      assert_equal surface[:controller], @request.params[:controller]
    end
  end

  test "robots and sitemap responses set long cache headers" do
    host! ENV.fetch("PUBLIC_PALM_SERVICE_URL")

    get "/sitemap.xml"

    cache_control = response.headers["Cache-Control"]

    assert_not_nil cache_control
    assert_match(/public/, cache_control)
    assert_match(/max-age=300/, cache_control)
    assert_match(/s-maxage=600/, cache_control)
    assert_equal "600", response.headers["Surrogate-Control"][("max-age=".size)..]
  end
end

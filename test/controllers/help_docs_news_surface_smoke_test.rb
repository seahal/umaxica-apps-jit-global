# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class HelpDocsNewsSurfaceSmokeTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      host_env: "PRIVATE_HELP_SERVICE_URL",
      host_fallback: "help.app.localhost",
      label: "Help",
      root_path: "/",
      health_path: "/health",
      entries_index_path: "/api/v0/entries",
      surface: "help",
      expected_body: "Help API is available",
    },
    {
      host_env: "PRIVATE_DOCS_SERVICE_URL",
      host_fallback: "docs.app.localhost",
      label: "Docs",
      root_path: "/",
      health_path: "/health",
      entries_index_path: "/api/v0/entries",
      surface: "docs",
      expected_body: "Docs API is available",
    },
    {
      host_env: "PRIVATE_NEWS_SERVICE_URL",
      host_fallback: "news.app.localhost",
      label: "News",
      root_path: "/",
      health_path: "/health",
      entries_index_path: "/api/v0/entries",
      surface: "news",
      expected_body: "News API is available",
    },
  ].freeze
  SURFACE_HOME_PAGES = [
    ["help.jp.umaxica.app", "Help App", "help.app.roots.message"],
    ["help.jp.umaxica.com", "Help Com", "help.com.roots.message"],
    ["help.jp.umaxica.org", "Help Org", "help.org.roots.message"],
    ["docs.jp.umaxica.app", "Docs App", "docs.app.roots.message"],
    ["docs.jp.umaxica.com", "Docs Com", "docs.com.roots.message"],
    ["docs.jp.umaxica.org", "Docs Org", "docs.org.roots.message"],
    ["news.jp.umaxica.app", "News App", "news.app.roots.message"],
    ["news.jp.umaxica.com", "News Com", "news.com.roots.message"],
    ["news.jp.umaxica.org", "News Org", "news.org.roots.message"],
  ].freeze

  test "help docs and news app surfaces respond on their public read-only endpoints" do
    SURFACES.each do |surface|
      host = ENV.fetch(surface.fetch(:host_env), surface.fetch(:host_fallback))
      host! host

      get surface.fetch(:root_path), headers: { "Host" => host }

      assert_response :success, surface.fetch(:label)
      assert_homepage_html title: "#{surface.fetch(:label)} App",
                           message: "#{surface.fetch(:expected_body)}. Browser article pages are served outside Rails."

      get surface.fetch(:health_path), headers: { "Host" => host }

      assert_response :success, surface.fetch(:label)
      assert_not_empty response.body, surface.fetch(:label)

      published = create_publishing_entry(
        audience: "app", surface: surface.fetch(:surface),
        namespace: surface.fetch(:label).downcase,
      )

      get surface.fetch(:entries_index_path),
          params: { locale: "test-smoke" },
          headers: { "Host" => host, "Accept" => "application/json" },
          as: :json

      assert_response :success, surface.fetch(:label)
      entry = response.parsed_body.fetch("data").first

      assert_equal published.slug, entry.fetch("slug"), surface.fetch(:label)
      assert_equal surface.fetch(:label).downcase, entry.fetch("namespace"), surface.fetch(:label)
      assert_equal "app", entry.fetch("surface"), surface.fetch(:label)

      get "#{surface.fetch(:entries_index_path)}/#{published.entry.public_id}",
          params: { locale: "test-smoke" },
          headers: { "Host" => host, "Accept" => "application/json" },
          as: :json

      assert_response :success, surface.fetch(:label)
      assert_equal published.entry.public_id, response.parsed_body.fetch("public_id"), surface.fetch(:label)
      assert_equal published.slug, response.parsed_body.fetch("slug"), surface.fetch(:label)
    end
  end

  test "help docs and news public host families render standalone homepages" do
    SURFACE_HOME_PAGES.each do |host, title, key|
      host! host

      get "/?ri=jp", headers: { "Host" => host }

      assert_response :success, title
      assert_homepage_html title: title, message: I18n.t(key)
    end
  end

  private

  def assert_homepage_html(title:, message:)
    assert_equal "text/html", response.media_type
    assert_includes response.body, "<!doctype html>"
    assert_select "html body main section h1", text: title
    assert_select "html body main section p", text: message
    assert_select "header", count: 0
    assert_select "footer", count: 0
  end

  def create_publishing_entry(audience:, surface:, namespace:)
    entry =
      publishing_published_entry(
        audience:, surface:, locale: "test-smoke", slug: "#{namespace}-surface-smoke",
        title: "#{namespace.titleize} Surface Smoke", published_at: 1.minute.ago,
      )
    entry.slugs.canonical.first
  end
end

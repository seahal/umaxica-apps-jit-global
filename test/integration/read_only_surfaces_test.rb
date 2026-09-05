# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ReadOnlySurfacesTest < ActionDispatch::IntegrationTest
  STATIC_SURFACES = [
    ["palm_app_root_url", "PUBLIC_PALM_SERVICE_URL", "palm.app.localhost", "Palm API is available"],
  ].freeze

  # The base gateway roots answer with a canonical redirect to the regional root instead of a
  # page, so they are asserted on their `Location` rather than on a body.
  BASE_GATEWAY_ROOTS = [
    ["base_app_root_url", "BASE_SERVICE_URL", "base.app.localhost", "https://jp.umaxica.app/"],
    ["base_com_root_url", "BASE_CORPORATE_URL", "base.com.localhost", "https://jp.umaxica.com/"],
    ["base_org_root_url", "BASE_STAFF_URL", "base.org.localhost", "https://jp.umaxica.org/"],
  ].freeze

  CONTENT_SURFACES = [
    ["help_app_root_url", "PRIVATE_HELP_SERVICE_URL", "help.app.localhost", "Help API is available"],
    ["help_com_root_url", "PRIVATE_HELP_CORPORATE_URL", "help.com.localhost", "Help API is available"],
    ["help_org_root_url", "PRIVATE_HELP_STAFF_URL", "help.org.localhost", "Help API is available"],
    ["docs_app_root_url", "PRIVATE_DOCS_SERVICE_URL", "docs.app.localhost", "Docs API is available"],
    ["docs_com_root_url", "PRIVATE_DOCS_CORPORATE_URL", "docs.com.localhost", "Docs API is available"],
    ["docs_org_root_url", "PRIVATE_DOCS_STAFF_URL", "docs.org.localhost", "Docs API is available"],
    ["news_app_root_url", "PRIVATE_NEWS_SERVICE_URL", "news.app.localhost", "News API is available"],
    ["news_com_root_url", "PRIVATE_NEWS_CORPORATE_URL", "news.com.localhost", "News API is available"],
    ["news_org_root_url", "PRIVATE_NEWS_STAFF_URL", "news.org.localhost", "News API is available"],
  ].freeze

  CONTENT_API_SURFACES = [
    ["help_app_api_v0_entry_url", "PRIVATE_HELP_SERVICE_URL", "help.app.localhost", "help", "app"],
    ["help_com_api_v0_entry_url", "PRIVATE_HELP_CORPORATE_URL", "help.com.localhost", "help", "com"],
    ["help_org_api_v0_entry_url", "PRIVATE_HELP_STAFF_URL", "help.org.localhost", "help", "org"],
    ["docs_app_api_v0_entry_url", "PRIVATE_DOCS_SERVICE_URL", "docs.app.localhost", "docs", "app"],
    ["docs_com_api_v0_entry_url", "PRIVATE_DOCS_CORPORATE_URL", "docs.com.localhost", "docs", "com"],
    ["docs_org_api_v0_entry_url", "PRIVATE_DOCS_STAFF_URL", "docs.org.localhost", "docs", "org"],
    ["news_app_api_v0_entry_url", "PRIVATE_NEWS_SERVICE_URL", "news.app.localhost", "news", "app"],
    ["news_com_api_v0_entry_url", "PRIVATE_NEWS_CORPORATE_URL", "news.com.localhost", "news", "com"],
    ["news_org_api_v0_entry_url", "PRIVATE_NEWS_STAFF_URL", "news.org.localhost", "news", "org"],
  ].freeze

  test "static palm roots respond without auth redirects" do
    STATIC_SURFACES.each do |helper, env_key, fallback, expected|
      host = ENV.fetch(env_key, fallback)
      host! host
      get public_send(helper, ri: "jp", host: host)

      assert_response :success
      assert_includes response.body, expected
    end
  end

  test "base gateway roots answer with the canonical regional redirect" do
    BASE_GATEWAY_ROOTS.each do |helper, env_key, fallback, expected_location|
      host = ENV.fetch(env_key, fallback)
      host! host
      get public_send(helper, ri: "jp", host: host)

      assert_response :moved_permanently
      assert_equal expected_location, response.location
    end
  end

  test "content roots respond as thin availability endpoints" do
    CONTENT_SURFACES.each do |helper, env_key, fallback, expected|
      host! ENV.fetch(env_key, fallback)
      get public_send(helper, ri: "jp", host: ENV.fetch(env_key, fallback))

      assert_response :success
      assert_includes response.body, expected
    end
  end

  test "content api show rejects unpublished entries and old rails article routes are unavailable" do
    published = create_publishing_entry(
      audience: "app", surface: "docs", slug: "visible-entry",
      title: "Visible Entry", locale: "test-show",
    )
    future = create_publishing_entry(
      audience: "app", surface: "docs", slug: "future-entry", title: "Future Entry", locale: "test-show",
      published_at: 1.day.from_now,
    )

    host! ENV.fetch("PRIVATE_DOCS_SERVICE_URL")
    get docs_app_api_v0_entry_url(public_id: published.public_id, locale: "test-show")

    assert_response :success
    assert_equal "visible-entry", response.parsed_body.fetch("slug")

    get docs_app_api_v0_entry_url(public_id: future.public_id, locale: "test-show")

    assert_response :not_found

    get "/entries/#{published.public_id}", params: { locale: "test-show" }

    assert_response :not_found

    get "/edge/v0/entries/#{published.public_id}", params: { locale: "test-show" }

    assert_response :not_found
  end

  test "content api show resolves locale from ri and rejects draft or archived entries" do
    published = create_publishing_entry(
      audience: "app", surface: "docs", slug: "locale-visible-entry",
      title: "Locale Visible Entry", locale: "ja",
    )
    draft = create_publishing_entry(
      audience: "app", surface: "docs", slug: "locale-draft-entry", title: "Locale Draft Entry", locale: "ja",
      status: "draft",
    )
    archived = create_publishing_entry(
      audience: "app", surface: "docs", slug: "locale-archived-entry", title: "Locale Archived Entry", locale: "ja",
      status: "archived",
    )

    host! ENV.fetch("PRIVATE_DOCS_SERVICE_URL")

    get docs_app_api_v0_entry_url(public_id: published.public_id, ri: "jp")

    assert_response :success
    assert_equal published.slugs.canonical.first.slug, response.parsed_body.fetch("slug")

    get docs_app_api_v0_entry_url(public_id: draft.public_id, ri: "jp")

    assert_response :not_found

    get docs_app_api_v0_entry_url(public_id: archived.public_id, ri: "jp")

    assert_response :not_found
  end

  test "content api show falls back safely for invalid ri values" do
    published = create_publishing_entry(
      audience: "app", surface: "docs", slug: "fallback-visible-entry", title: "Fallback Visible Entry",
      locale: I18n.locale.to_s,
    )
    english = create_publishing_entry(
      audience: "app", surface: "docs", slug: "fallback-english-entry", title: "Fallback English Entry", locale: "en",
    )

    host! ENV.fetch("PRIVATE_DOCS_SERVICE_URL")

    get docs_app_api_v0_entry_url(public_id: published.public_id, ri: "zz")

    assert_response :success
    assert_equal published.slugs.canonical.first.slug, response.parsed_body.fetch("slug")

    get docs_app_api_v0_entry_url(public_id: english.public_id, ri: "us")

    assert_response :success
    assert_equal english.slugs.canonical.first.slug, response.parsed_body.fetch("slug")
  end

  test "content api index and show serialize published content with the expected namespace" do
    CONTENT_API_SURFACES.each do |helper, env_key, fallback, surface, audience|
      create_publishing_entry(
        audience:, surface:, slug: "#{audience}-older-entry", title: "Older Entry", locale: "test-api",
        published_at: 2.hours.ago,
      )
      newer =
        create_publishing_entry(
          audience:, surface:, slug: "#{audience}-newer-entry", title: "Newer Entry",
          locale: "test-api",
        )
      create_publishing_entry(
        audience:, surface:, slug: "#{audience}-other-locale", title: "Other Locale",
        locale: "jp",
      )

      host = ENV.fetch(env_key, fallback)
      host! host

      get public_send(helper, public_id: newer.public_id, locale: "test-api", host: host),
          headers: { "Host" => host, "Accept" => "application/json" },
          as: :json

      assert_response :success
      entry = response.parsed_body

      assert_equal newer.public_id, entry.fetch("public_id")
      assert_equal newer.slugs.canonical.first.slug, entry.fetch("slug")
      assert_equal surface, entry.fetch("namespace")
      assert_equal audience, entry.fetch("surface")
      assert_equal "Newer Entry", entry.fetch("title")

      get public_send(helper, public_id: "unknownpublicid0000001", locale: "test-api", host: host),
          headers: { "Host" => host, "Accept" => "application/json" },
          as: :json

      assert_response :not_found

      get "/api/v0/entries",
          params: { locale: "test-api" },
          headers: { "Host" => host, "Accept" => "application/json" },
          as: :json

      assert_response :success
      entries = response.parsed_body.fetch("data")

      assert_equal [newer.slugs.canonical.first.slug, "#{audience}-older-entry"], entries.map { |e| e.fetch("slug") }
      assert_equal surface, entries.first.fetch("namespace")
      assert_equal audience, entries.first.fetch("surface")
      assert_equal "Newer Entry", entries.first.fetch("title")
    end
  end

  private

  # "archived" publishes the entry and then archives it, so the case genuinely
  # exercises the archived-entry exclusion rather than merely skipping
  # publication the way a draft does.
  def create_publishing_entry(audience:, surface:, slug:, title:, locale: "jp", status: "published",
                              published_at: 1.hour.ago)
    edition = publishing_edition(audience:, surface:, locale:)
    entry = publishing_draft(edition:, slug:, title:, locale:)
    return entry if status == "draft"

    publishing_publish(entry:, published_at:)
    entry.update!(archived_at: Time.current, archive_reason: "test fixture") if status == "archived"
    entry
  end
end

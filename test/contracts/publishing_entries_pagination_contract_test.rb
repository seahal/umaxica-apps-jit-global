# frozen_string_literal: true

require "test_helper"
require_relative "../support/openapi_contract"

class PublishingEntriesPaginationContractTest < ActionDispatch::IntegrationTest
  include OpenapiContract

  SERVICES = %w(docs help info news).freeze
  HOST_ROLES = { "app" => "SERVICE", "com" => "CORPORATE", "org" => "STAFF" }.freeze
  PAGE_SIZE = PublishingPublishedEntriesQuery::PAGE_SIZE

  test "every publishing cell exposes the same page envelope" do
    SERVICES.product(HOST_ROLES.keys).each do |service, surface|
      prepare(service:, surface:)
      publish("cell-page", "Cell Page")

      get "/api/v0/entries?locale=ja&page=1", headers: json_headers

      assert_response :success, "#{service}/#{surface}"
      body = response.parsed_body
      page = body.fetch("page")

      assert_equal 1, body.fetch("data").length, "#{service}/#{surface}"
      assert_equal({ "current" => 1, "previous" => nil, "next" => nil, "last" => 1 }, page, "#{service}/#{surface}")
      assert_not page.key?("next_cursor"), "#{service}/#{surface}"
      assert_not page.key?("has_more"), "#{service}/#{surface}"
      assert_openapi_conform 200
    end
  end

  test "the first page reports null previous and a next page when the collection overflows" do
    prepare(service: "docs", surface: "app")
    slugs = (PAGE_SIZE + 1).times.map { |i| "first-#{i}" }
    slugs.each_with_index { |slug, i| publish(slug, slug, published_at: (i + 1).hours.ago) }

    get "/api/v0/entries?locale=ja&page=1", headers: json_headers

    assert_response :success
    body = response.parsed_body

    assert_equal slugs.first(PAGE_SIZE), body.fetch("data").map { |entry| entry.fetch("slug") }
    assert_equal({ "current" => 1, "previous" => nil, "next" => 2, "last" => 2 }, body.fetch("page"))
  end

  test "a middle page reports both neighbours" do
    prepare(service: "docs", surface: "app")
    count = (PAGE_SIZE * 2) + 1
    slugs = count.times.map { |i| "middle-#{i}" }
    slugs.each_with_index { |slug, i| publish(slug, slug, published_at: (i + 1).hours.ago) }

    get "/api/v0/entries?locale=ja&page=2", headers: json_headers

    assert_response :success
    body = response.parsed_body

    assert_equal slugs[PAGE_SIZE, PAGE_SIZE], body.fetch("data").map { |entry| entry.fetch("slug") }
    assert_equal({ "current" => 2, "previous" => 1, "next" => 3, "last" => 3 }, body.fetch("page"))
  end

  test "the final page reports null next" do
    prepare(service: "docs", surface: "app")
    count = (PAGE_SIZE * 2) + 3
    slugs = count.times.map { |i| "final-#{i}" }
    slugs.each_with_index { |slug, i| publish(slug, slug, published_at: (i + 1).hours.ago) }

    get "/api/v0/entries?locale=ja&page=3", headers: json_headers

    assert_response :success
    body = response.parsed_body

    assert_equal slugs.last(3), body.fetch("data").map { |entry| entry.fetch("slug") }
    assert_equal({ "current" => 3, "previous" => 2, "next" => nil, "last" => 3 }, body.fetch("page"))
  end

  test "a collection smaller than one page is returned in full" do
    prepare(service: "docs", surface: "app")
    %w(small-a small-b small-c).each_with_index do |slug, i|
      publish(slug, slug, published_at: (i + 1).hours.ago)
    end

    get "/api/v0/entries?locale=ja", headers: json_headers

    assert_response :success
    body = response.parsed_body

    assert_equal %w(small-a small-b small-c), body.fetch("data").map { |entry| entry.fetch("slug") }
    assert_equal({ "current" => 1, "previous" => nil, "next" => nil, "last" => 1 }, body.fetch("page"))
  end

  test "an empty collection still carries page coordinates" do
    prepare(service: "docs", surface: "app")

    get "/api/v0/entries?locale=ja", headers: json_headers

    assert_response :success
    assert_equal(
      { "data" => [], "page" => { "current" => 1, "previous" => nil, "next" => nil, "last" => 1 } },
      response.parsed_body,
    )
  end

  test "duplicate publication timestamps keep a stable public_id order" do
    prepare(service: "docs", surface: "app")
    published_at = Time.zone.parse("2026-01-15 12:00:00 UTC")
    first = publish("tie-a", "Tie A", published_at:)
    second = publish("tie-b", "Tie B", published_at:)
    expected = publishing_query(audience: "app", surface: "docs").call.map(&:public_id)

    get "/api/v0/entries?locale=ja", headers: json_headers

    assert_response :success
    assert_equal expected, response.parsed_body.fetch("data").map { |entry| entry.fetch("public_id") }
    assert_equal [first.public_id, second.public_id].sort, expected.sort
  end

  test "locale isolation applies across pages" do
    prepare(service: "docs", surface: "app")
    publish("ja-only", "JA Only")
    english = publishing_draft(audience: "app", surface: "docs", slug: "en-only", title: "EN Only", locale: "en")
    publishing_publish(entry: english)

    get "/api/v0/entries?locale=ja&page=1", headers: json_headers

    assert_response :success
    assert_equal %w(ja-only), response.parsed_body.fetch("data").map { |entry| entry.fetch("slug") }

    get "/api/v0/entries?locale=en&page=1", headers: json_headers

    assert_response :success
    assert_equal %w(en-only), response.parsed_body.fetch("data").map { |entry| entry.fetch("slug") }
  end

  test "category filtering is applied before pagination" do
    prepare(service: "docs", surface: "app")
    category = publishing_category_vocabulary(audience: "app", surface: "docs")
    guide = publishing_term(vocabulary: category, locale: "ja", slug: "guide")
    ((PAGE_SIZE * 2) + 2).times do |i|
      entry = publishing_draft(audience: "app", surface: "docs", slug: "cat-#{i}", title: "Cat #{i}")
      if i.even?
        create_single_assignment(
          entry_revision: entry.current_revision, vocabulary: category, vocabulary_kind: category.kind,
          taxonomy_term: guide, locale: "ja",
        )
      end
      publishing_publish(entry:, published_at: (i + 1).hours.ago)
    end

    get "/api/v0/entries?locale=ja&category=guide&page=1", headers: json_headers

    assert_response :success
    body = response.parsed_body
    slugs = body.fetch("data").map { |entry| entry.fetch("slug") }

    assert(slugs.all? { |slug| slug[/\d+/].to_i.even? })
    assert_equal PAGE_SIZE, slugs.length
    assert_equal 2, body.dig("page", "last")
  end

  test "tag filtering is applied before pagination" do
    prepare(service: "docs", surface: "app")
    tag = publishing_tag_vocabulary(audience: "app", surface: "docs")
    ruby = publishing_term(vocabulary: tag, locale: "ja", slug: "ruby")
    3.times do |i|
      entry = publishing_draft(audience: "app", surface: "docs", slug: "tag-#{i}", title: "Tag #{i}")
      if i == 1
        create_multiple_assignment(
          entry_revision: entry.current_revision, vocabulary: tag, vocabulary_kind: tag.kind,
          taxonomy_term: ruby, locale: "ja", position: 0,
        )
      end
      publishing_publish(entry:, published_at: (i + 1).hours.ago)
    end

    get "/api/v0/entries?locale=ja&tag=ruby&page=1", headers: json_headers

    assert_response :success
    body = response.parsed_body

    assert_equal %w(tag-1), body.fetch("data").map { |entry| entry.fetch("slug") }
    assert_equal({ "current" => 1, "previous" => nil, "next" => nil, "last" => 1 }, body.fetch("page"))
  end

  test "page zero and a fractional page are refused" do
    prepare(service: "docs", surface: "app")
    publish("present", "Present")

    get "/api/v0/entries?locale=ja&page=0", headers: json_headers

    assert_response :bad_request
    assert_equal "urn:umaxica:problem:bad-request", response.parsed_body.fetch("type")

    get "/api/v0/entries?locale=ja&page=1.5", headers: json_headers

    assert_response :bad_request
    assert_equal "urn:umaxica:problem:bad-request", response.parsed_body.fetch("type")
  end

  test "a caller-supplied limit does not change the server page size" do
    prepare(service: "docs", surface: "app")
    (PAGE_SIZE + 1).times { |i| publish("limit-#{i}", "Limit #{i}", published_at: (i + 1).hours.ago) }

    get "/api/v0/entries?locale=ja&page=1&limit=1", headers: json_headers

    assert_response :success
    assert_equal PAGE_SIZE, response.parsed_body.fetch("data").length
  end

  private

  def prepare(service:, surface:)
    self.openapi_surface = surface
    @service = service
    @audience = surface
    @host = ENV.fetch("PRIVATE_#{service.upcase}_#{HOST_ROLES.fetch(surface)}_URL")
    host!(@host)
  end

  def publish(slug, title, published_at: 1.hour.ago)
    entry = publishing_draft(audience: @audience, surface: @service, slug:, title:)
    publishing_publish(entry:, published_at:)
  end

  def json_headers
    { "Accept" => "application/json" }
  end
end

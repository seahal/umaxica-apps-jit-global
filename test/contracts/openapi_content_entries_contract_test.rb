# frozen_string_literal: true

require "test_helper"
require_relative "../support/openapi_contract"

# Validates the read-only content API against every surface description, for every service that
# serves it.
#
# `/api/v0/entries` is declared in config/routes/{docs,help,info,news}.rb and nowhere else -- Core
# does not route it, which the previous single description got wrong by attaching all content paths
# to a Core default host. Twelve service-and-surface combinations run the same controller code
# through `PublishingContentRendering`, so validating one would not prove the others; the surfaces
# are independent boundaries and each has its own description.
#
# The docs and news editions have no production host entry (config/environments/production.rb), so
# they are not publicly reachable today. They are still routed, implemented, and covered here: the
# gap is ingress, not behaviour.
class OpenapiContentEntriesContractTest < ActionDispatch::IntegrationTest
  include OpenapiContract

  SERVICES = %w(docs help info news).freeze

  # Surface to the environment variable holding that surface's private ingress name. `app` is
  # SERVICE, `com` is CORPORATE, `org` is STAFF throughout the repository.
  HOST_ROLES = { "app" => "SERVICE", "com" => "CORPORATE", "org" => "STAFF" }.freeze

  SERVICES.each do |service|
    HOST_ROLES.each_key do |surface|
      test "GET /api/v0/entries conforms for #{service} on the #{surface} surface" do
        prepare(service:, surface:)
        publish("listed", "Listed")

        get "/api/v0/entries?locale=ja", headers: json_headers(service:, surface:)

        assert_response :success
        data = response.parsed_body.fetch("data")

        assert_equal %w(listed), data.map { |entry| entry.fetch("slug") }
        assert(data.all? { |entry| entry.fetch("public_id").present? })
        assert_openapi_conform 200
      end

      test "GET /api/v0/entries/{public_id} conforms for #{service} on the #{surface} surface" do
        prepare(service:, surface:)
        entry = publish("readable", "Readable")

        get "/api/v0/entries/#{entry.public_id}?locale=ja", headers: json_headers(service:, surface:)

        assert_response :success
        assert_equal entry.public_id, response.parsed_body.fetch("public_id")
        assert_openapi_conform 200
      end
    end
  end

  test "a null member is described as nullable and is present rather than omitted" do
    # This is the defect the version change repaired. Under the previous `openapi: 3.2.0`,
    # `nullable: true` was an unknown keyword that JSON Schema silently ignored, so a nullable
    # member was published as a non-nullable string while the serializer emitted null. The
    # assertion below fails against a schema that gets this wrong.
    prepare(service: "docs", surface: "app")
    entry = publish("null-summary", "Null Summary", summary: nil)

    get "/api/v0/entries/#{entry.public_id}?locale=ja", headers: json_headers(service: "docs", surface: "app")

    assert_response :success

    entry = response.parsed_body

    assert entry.key?("summary"), "an absent member and a null member are different contracts"
    assert_nil entry.fetch("summary")
    assert_openapi_conform 200
  end

  test "published_at is never null on a rendered entry" do
    # `publishing_publications.effective_from` is NOT NULL and
    # `PublishingEntrySerializer#call` renders nothing at all without an active publication, so a
    # rendered entry always carries a timestamp. The schema described it as nullable, which
    # described a state that cannot occur; this pins the correction.
    prepare(service: "docs", surface: "app")
    entry = publish("always-timestamped", "Always Timestamped")

    get "/api/v0/entries/#{entry.public_id}?locale=ja", headers: json_headers(service: "docs", surface: "app")

    assert_response :success
    assert_not_nil response.parsed_body.fetch("published_at")
    assert_openapi_conform 200
  end

  test "a matching validator answers a conforming 304" do
    prepare(service: "docs", surface: "app")
    entry = publish("revalidated", "Revalidated")
    headers = json_headers(service: "docs", surface: "app")

    get "/api/v0/entries/#{entry.public_id}?locale=ja", headers: headers

    assert_response :success
    etag = response.headers.fetch("ETag")

    get "/api/v0/entries/#{entry.public_id}?locale=ja", headers: headers.merge("If-None-Match" => etag)

    assert_response :not_modified
    assert_empty response.body
    # Committee skips body validation for 304 by design, so this checks that 304 is a described
    # status for the operation and that its headers conform.
    assert_openapi_conform 304
  end

  test "an unknown public_id answers a conforming problem document" do
    prepare(service: "docs", surface: "app")

    get "/api/v0/entries/unknownpublicid0000001?locale=ja", headers: json_headers(service: "docs", surface: "app")

    assert_response :not_found
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:not-found", response.parsed_body.fetch("type")
    assert_openapi_conform 404
  end

  test "a public_id resolves only through its own cell, never another audience, surface, or locale" do
    prepare(service: "docs", surface: "app")
    entry = publish("cell-bound", "Cell Bound")
    own_host = @host

    # Same public_id, every other cell that routes /api/v0/entries: different
    # surface, different service, and the same cell in another locale.
    foreign = [
      { service: "docs", surface: "com" },
      { service: "docs", surface: "org" },
      { service: "help", surface: "app" },
      { service: "news", surface: "app" },
      { service: "info", surface: "app" },
    ]
    foreign.each do |cell|
      prepare(**cell)
      get "/api/v0/entries/#{entry.public_id}?locale=ja", headers: json_headers(**cell)

      assert_response :not_found, "#{cell} must not resolve an app/docs public_id"
      assert_equal "application/problem+json", response.media_type
    end

    # Its own cell in a locale it was not published in.
    # Locale isolation: the same family has no published row for `en`.
    host!(own_host)
    get "/api/v0/entries/#{entry.public_id}?locale=en", headers: json_headers(service: "docs", surface: "app")

    assert_response :not_found

    # Sanity: it does resolve through its own cell.
    host!(own_host)
    get "/api/v0/entries/#{entry.public_id}?locale=ja", headers: json_headers(service: "docs", surface: "app")

    assert_response :success
  end

  test "a publication outside its window is not readable or listed" do
    prepare(service: "docs", surface: "app")

    scheduled = publishing_draft(audience: "app", surface: "docs", slug: "scheduled-entry", title: "Scheduled Entry")
    publishing_publish(entry: scheduled, published_at: 1.hour.from_now)
    get "/api/v0/entries/#{scheduled.public_id}?locale=ja", headers: json_headers(service: "docs", surface: "app")

    assert_response :not_found

    expired = publishing_draft(audience: "app", surface: "docs", slug: "expired-entry", title: "Expired Entry")
    publishing_publish(entry: expired, published_at: 2.hours.ago, effective_until: 1.hour.ago)
    get "/api/v0/entries/#{expired.public_id}?locale=ja", headers: json_headers(service: "docs", surface: "app")

    assert_response :not_found

    get "/api/v0/entries?locale=ja", headers: json_headers(service: "docs", surface: "app")

    assert_response :success
    slugs = response.parsed_body.fetch("data").map { |entry| entry.fetch("slug") }

    assert_empty slugs & %w(scheduled-entry expired-entry)
  end

  test "a draft or archived entry is not readable by a known public_id" do
    prepare(service: "docs", surface: "app")

    draft = publishing_draft(audience: "app", surface: "docs", slug: "draft-entry", title: "Draft Entry")
    get "/api/v0/entries/#{draft.public_id}?locale=ja", headers: json_headers(service: "docs", surface: "app")

    assert_response :not_found

    archived = publish("archived-entry", "Archived Entry")
    archived.update!(archived_at: Time.current, archive_reason: "test fixture")
    get "/api/v0/entries/#{archived.public_id}?locale=ja", headers: json_headers(service: "docs", surface: "app")

    assert_response :not_found
  end

  test "a collection is bounded even when the client omits page" do
    prepare(service: "docs", surface: "app")
    25.times { |i| publish("bounded-#{i}", "Bounded #{i}", published_at: (i + 1).hours.ago) }

    get "/api/v0/entries?locale=ja", headers: json_headers(service: "docs", surface: "app")

    assert_response :success

    body = response.parsed_body

    assert_equal PublishingPublishedEntriesQuery::PAGE_SIZE, body.fetch("data").length
    assert_equal 1, body.dig("page", "current")
    assert_nil body.dig("page", "previous")
    assert_equal 2, body.dig("page", "next")
    assert_equal 2, body.dig("page", "last")
    assert_not body.fetch("page").key?("next_cursor")
    assert_not body.fetch("page").key?("has_more")
    assert_openapi_conform 200
  end

  test "page numbers walk the whole collection exactly once, in order" do
    prepare(service: "docs", surface: "app")
    expected = (PublishingPublishedEntriesQuery::PAGE_SIZE + 5).times.map { |i| "walked-#{i}" }
    expected.each_with_index { |slug, i| publish(slug, slug, published_at: (i + 1).hours.ago) }

    seen = []
    2.times do |index|
      get "/api/v0/entries?locale=ja&page=#{index + 1}", headers: json_headers(service: "docs", surface: "app")

      assert_response :success
      assert_openapi_conform 200

      body = response.parsed_body
      seen.concat(body.fetch("data").map { |entry| entry.fetch("slug") })
    end

    assert_equal expected, seen
  end

  test "a malformed page is refused rather than silently defaulted" do
    prepare(service: "docs", surface: "app")
    publish("guarded", "Guarded")

    get "/api/v0/entries?locale=ja&page=twenty", headers: json_headers(service: "docs", surface: "app")

    assert_response :bad_request
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:bad-request", response.parsed_body.fetch("type")
    assert_openapi_response_conform 400
  end

  test "an out-of-range page is refused rather than answering with the first page" do
    prepare(service: "docs", surface: "app")
    publish("only-one", "Only One")

    get "/api/v0/entries?locale=ja&page=2", headers: json_headers(service: "docs", surface: "app")

    assert_response :bad_request
    assert_equal "urn:umaxica:problem:bad-request", response.parsed_body.fetch("type")
    assert_openapi_response_conform 400
  end

  test "the validator is page-specific" do
    prepare(service: "docs", surface: "app")
    (PublishingPublishedEntriesQuery::PAGE_SIZE + 1).times do |i|
      publish("paged-#{i}", "Paged #{i}", published_at: (i + 1).hours.ago)
    end
    headers = json_headers(service: "docs", surface: "app")

    get "/api/v0/entries?locale=ja&page=1", headers: headers

    assert_response :success
    first_page_etag = response.headers.fetch("ETag")

    get "/api/v0/entries?locale=ja&page=2", headers: headers

    assert_response :success
    assert_not_equal first_page_etag, response.headers.fetch("ETag")
  end

  test "an unacceptable Accept answers a conforming problem document" do
    prepare(service: "docs", surface: "app")

    get "/api/v0/entries?locale=ja", headers: { "Accept" => "text/csv" }

    assert_response :not_acceptable
    assert_equal "application/problem+json", response.media_type
    assert_openapi_conform 406
  end

  private

  def prepare(service:, surface:)
    self.openapi_surface = surface
    @service = service
    @audience = surface
    @host = ENV.fetch("PRIVATE_#{service.upcase}_#{HOST_ROLES.fetch(surface)}_URL")
    host!(@host)
  end

  # `summary` is the one nullable column behind the Entry schema, and the shared fixture helper
  # always fills it, so a test that needs the null case has to clear it before promotion.
  def publish(slug, title, published_at: 1.hour.ago, summary: :unset)
    entry = publishing_draft(audience: @audience, surface: @service, slug:, title:)
    entry.current_revision.update!(summary:) unless summary == :unset
    publishing_publish(entry:, published_at:)
  end

  def json_headers(service: @service, surface: @surface)
    _ = service
    _ = surface
    { "Accept" => "application/json" }
  end
end

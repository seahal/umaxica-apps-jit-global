# frozen_string_literal: true

require "test_helper"
require_relative "../support/openapi_contract"

# Pins the public read contract consumed by the edge applications. Adding,
# removing, or retyping a field here is a deliberate API change, not an
# incidental one.
#
# `openapi_content_entries_contract_test.rb` validates this endpoint against the OpenAPI
# description on all twelve service-and-surface combinations. The assertions here are the ones the
# description cannot make. `additionalProperties: false` is forbidden by
# adr/api-versioning-and-client-conventions.md -- clients must tolerate unknown response fields --
# so a schema can require the contracted members but can never object to an extra one. Only the
# exact key-set assertions below catch a field that leaks in.
class PublishingEntryApiContractTest < ActionDispatch::IntegrationTest
  include OpenapiContract

  openapi_surface :app

  ENTRY_KEYS = %w(
    public_id namespace surface slug locale title summary body published_at updated_at
    snapshot_public_id taxonomy
  ).freeze
  TAXONOMY_KEYS = %w(category tag).freeze
  TERM_KEYS = %w(public_id slug name).freeze

  setup do
    @host = ENV.fetch("PRIVATE_DOCS_SERVICE_URL")
    @edition = publishing_edition(audience: "app", surface: "docs", locale: "ja")
    @category = publishing_category_vocabulary(audience: "app", surface: "docs")
    @tag = publishing_tag_vocabulary(audience: "app", surface: "docs")
    @guide = publishing_term(vocabulary: @category, locale: "ja", slug: "guide", name: "ガイド")
    @setup_term = publishing_term(vocabulary: @category, locale: "ja", slug: "setup", name: "セットアップ", parent: @guide)
    @ruby = publishing_term(vocabulary: @tag, locale: "ja", slug: "ruby", name: "Ruby")
    @rails = publishing_term(vocabulary: @tag, locale: "ja", slug: "rails", name: "Rails")
  end

  test "a published entry exposes exactly the contracted key set" do
    publish("contract-entry", "Contract Entry")

    entry = show("contract-entry")

    assert_equal ENTRY_KEYS, entry.keys
    assert_equal TAXONOMY_KEYS, entry.fetch("taxonomy").keys
    # The schema cannot assert this: it may require every member, but it may not close the object,
    # so an extra field would satisfy it. The line above is the guard; this one proves the two
    # descriptions of the same payload agree.
    assert_openapi_conform 200
  end

  test "body is always the complete object, never a bare string" do
    publish("object-body", "Object Body")

    entry = show("object-body")

    assert_kind_of Hash, entry.fetch("body")
    assert_equal({ "text" => "Object Body body" }, entry.fetch("body"))
  end

  test "an unassigned entry renders a null category and an empty tag list" do
    publish("unassigned", "Unassigned")

    taxonomy = show("unassigned").fetch("taxonomy")

    assert_nil taxonomy.fetch("category")
    assert_empty taxonomy.fetch("tag")
  end

  test "a category renders as one object carrying its breadcrumb path" do
    publish("with-category", "With Category", category: @setup_term)

    category = show("with-category").fetch("taxonomy").fetch("category")

    assert_equal TERM_KEYS + ["path"], category.keys
    assert_equal "setup", category.fetch("slug")
    assert_equal "セットアップ", category.fetch("name")
    assert_equal @setup_term.public_id, category.fetch("public_id")
    assert_equal %w(guide setup), category.fetch("path").map { |step| step.fetch("slug") }
  end

  test "tags render as an ordered list of terms" do
    publish("with-tags", "With Tags", tags: [@rails, @ruby])

    tags = show("with-tags").fetch("taxonomy").fetch("tag")

    assert_equal %w(rails ruby), tags.map { |term| term.fetch("slug") }
    assert_equal TERM_KEYS, tags.first.keys
  end

  test "taxonomy comes from the published version, not the current draft" do
    entry = publish("frozen-taxonomy", "Frozen Taxonomy", category: @setup_term)
    @setup_term.update!(name: "改名後", slug: "renamed")
    revision = publishing_revision(entry:, title: "Frozen Taxonomy v2", sequence: 2)
    entry.update!(current_revision: revision)

    category = show("frozen-taxonomy").fetch("taxonomy").fetch("category")

    assert_equal "setup", category.fetch("slug")
    assert_equal "セットアップ", category.fetch("name")
  end

  test "no database, revision, or version identifier leaks into the payload" do
    publish("no-identifiers", "No Identifiers", category: @setup_term, tags: [@ruby])

    payload = show("no-identifiers").to_json

    assert_no_match(/"(id|entry_id|entry_version_id|entry_revision_id|vocabulary_id|taxonomy_term_id)"/, payload)
    assert_no_match(/revision/i, payload)
    assert_no_match(/version/i, payload)
  end

  test "index filters by category slug and preserves publication ordering" do
    publish("older-tagged", "Older Tagged", category: @setup_term, published_at: 3.hours.ago)
    publish("newer-tagged", "Newer Tagged", category: @setup_term, published_at: 1.hour.ago)
    publish("untagged", "Untagged", published_at: 2.hours.ago)

    assert_equal %w(newer-tagged older-tagged), index(category: "setup").map { |entry| entry.fetch("slug") }
    # Filtering never reorders: the list stays newest-published first.
    assert_equal %w(newer-tagged untagged older-tagged), index.map { |entry| entry.fetch("slug") }
  end

  test "index filters by tag slug" do
    publish("ruby-entry", "Ruby Entry", tags: [@ruby])
    publish("rails-entry", "Rails Entry", tags: [@rails])

    assert_equal %w(ruby-entry), index(tag: "ruby").map { |entry| entry.fetch("slug") }
  end

  test "an unknown filter term yields an empty list rather than the unfiltered one" do
    publish("filtered-out", "Filtered Out", category: @setup_term)

    assert_empty index(category: "does-not-exist")
    assert_empty index(tag: "does-not-exist")
  end

  test "a new vocabulary row appears in the API without any code change" do
    topic = publishing_vocabulary(
      audience: "app", surface: "docs", key: "topic", kind: Publishing::TaxonomyKind::SINGLE_HIERARCHICAL,
    )
    term = publishing_term(vocabulary: topic, locale: "ja", slug: "architecture", name: "Architecture")
    entry = publishing_draft(edition: @edition, slug: "topical", title: "Topical")
    Publishing::RevisionSingleTaxonomyAssignment.create!(
      entry_revision: entry.current_revision, vocabulary: topic, vocabulary_kind: topic.kind,
      taxonomy_term: term, locale: "ja",
    )
    publishing_publish(entry:)

    taxonomy = show("topical").fetch("taxonomy")

    # No serializer, promotion, or restore branch knows the word "topic".
    assert_equal %w(category tag topic), taxonomy.keys
    assert_equal "architecture", taxonomy.fetch("topic").fetch("slug")
    assert_nil taxonomy.fetch("category")
    assert_equal [entry], PublishingPublishedEntriesQuery.call(edition: @edition, category: nil).to_a
  end

  test "a flat vocabulary added at runtime serializes as an ordered array" do
    channel = publishing_vocabulary(
      audience: "app", surface: "docs", key: "channel", kind: Publishing::TaxonomyKind::MULTIPLE_ORDERED_FLAT,
    )
    first = publishing_term(vocabulary: channel, locale: "ja", slug: "email", name: "Email")
    second = publishing_term(vocabulary: channel, locale: "ja", slug: "web", name: "Web")
    entry = publishing_draft(edition: @edition, slug: "channelled", title: "Channelled")
    [second, first].each_with_index do |term, position|
      Publishing::RevisionMultipleTaxonomyAssignment.create!(
        entry_revision: entry.current_revision, vocabulary: channel, vocabulary_kind: channel.kind,
        taxonomy_term: term, locale: "ja", position:,
      )
    end
    publishing_publish(entry:)

    taxonomy = show("channelled").fetch("taxonomy")

    assert_equal %w(web email), taxonomy.fetch("channel").map { |term| term.fetch("slug") }
    assert_empty taxonomy.fetch("tag")
  end

  test "filters match the published snapshot after the live term is renamed" do
    entry = publish("stable-url", "Stable URL", category: @setup_term)
    @setup_term.update!(slug: "renamed-slug", name: "Renamed")

    assert_equal "setup", show("stable-url").fetch("taxonomy").fetch("category").fetch("slug")
    assert_equal %w(stable-url), index(category: "setup").map { |listed| listed.fetch("slug") }
    assert_empty index(category: "renamed-slug")
    assert_predicate entry, :persisted?
  end

  test "a published entry is shared-cacheable and revalidatable" do
    publish("cacheable", "Cacheable")

    host! @host
    get docs_app_api_v0_entry_url(public_id: public_id_for("cacheable"), locale: "ja", host: @host)

    assert_response :success
    assert_includes response.headers["Cache-Control"], "public"
    assert_includes response.headers["Cache-Control"], "max-age=60"
    assert_predicate response.headers["ETag"], :present?
    assert_predicate response.headers["Last-Modified"], :present?
  end

  test "a matching validator answers 304 with no body" do
    publish("revalidated", "Revalidated")
    host! @host
    public_id = public_id_for("revalidated")
    get docs_app_api_v0_entry_url(public_id:, locale: "ja", host: @host)

    assert_response :success
    etag = response.headers.fetch("ETag")

    get docs_app_api_v0_entry_url(public_id:, locale: "ja", host: @host),
        headers: { "If-None-Match" => etag }

    assert_response :not_modified
    assert_empty response.body
  end

  test "the index is revalidatable and its validator tracks the rendered payload" do
    publish("index-one", "Index One")
    host! @host
    get docs_app_api_v0_entries_url(locale: "ja", host: @host)

    assert_response :success
    assert_includes response.headers["Cache-Control"], "public"

    etag = response.headers.fetch("ETag")

    get docs_app_api_v0_entries_url(locale: "ja", host: @host), headers: { "If-None-Match" => etag }

    assert_response :not_modified

    # The validator is derived from the payload, so publishing another entry must invalidate it.
    publish("index-two", "Index Two")

    get docs_app_api_v0_entries_url(locale: "ja", host: @host), headers: { "If-None-Match" => etag }

    assert_response :success
    assert_not_equal etag, response.headers.fetch("ETag")
  end

  test "an unknown public_id returns an RFC 9457 problem document" do
    host! @host
    get docs_app_api_v0_entry_url(public_id: "unknownpublicid0000001", locale: "ja", host: @host)

    assert_response :not_found
    assert_equal "application/problem+json", response.media_type

    body = response.parsed_body

    assert_equal "urn:umaxica:problem:not-found", body.fetch("type")
    assert_equal 404, body.fetch("status")
    assert_predicate body.fetch("request_id"), :present?
    assert_openapi_conform 404
  end

  test "the database primary key is not accepted as a public_id" do
    entry = publish("pk-guard", "PK Guard")

    host! @host
    get docs_app_api_v0_entry_url(public_id: entry.id.to_s, locale: "ja", host: @host)

    assert_response :not_found
    assert_equal "application/problem+json", response.media_type
  end

  test "a slug is not accepted as a public_id" do
    publish("slug-guard", "Slug Guard")

    host! @host
    get docs_app_api_v0_entry_url(public_id: "slug-guard", locale: "ja", host: @host)

    assert_response :not_found
  end

  # PublishingContentRendering used to merge a string-valued `error` member into every problem
  # document on these paths -- a second legacy shape alongside the nested object the other
  # boundaries carried. Both were removed on 2026-08-22 once an audit established that no consumer
  # read either.
  test "no transitional error member remains in the problem document" do
    host! @host
    get docs_app_api_v0_entry_url(public_id: "unknownpublicid0000001", locale: "ja", host: @host)

    body = response.parsed_body

    assert_not body.key?("error"), "the transitional error member is gone"
    assert_equal %w(instance request_id status title type), body.keys.sort
  end

  test "an unknown locale returns an empty index rather than an error" do
    publish("locale-entry", "Locale Entry")

    host! @host
    get docs_app_api_v0_entries_url(locale: "zz", host: @host)

    assert_response :success
    assert_empty response.parsed_body.fetch("data")
  end

  private

  def publish(slug, title, category: nil, tags: [], published_at: 1.hour.ago)
    entry = publishing_draft(edition: @edition, slug:, title:)
    if category
      Publishing::RevisionSingleTaxonomyAssignment.create!(
        entry_revision: entry.current_revision, vocabulary: @category, vocabulary_kind: @category.kind,
        taxonomy_term: category, locale: "ja",
      )
    end
    tags.each_with_index do |term, position|
      Publishing::RevisionMultipleTaxonomyAssignment.create!(
        entry_revision: entry.current_revision, vocabulary: @tag, vocabulary_kind: @tag.kind,
        taxonomy_term: term, locale: "ja", position:,
      )
    end
    publishing_publish(entry:, published_at:)
  end

  # A single resource is returned at the top level, with no wrapper key
  # (adr/api-collection-contract.md). The API addresses entries by opaque
  # `public_id`; tests still name them by slug for readability and resolve here.
  def public_id_for(slug)
    Publishing::EntrySlug.find_by!(slug:).entry.public_id
  end

  def show(slug)
    host!(@host)
    get(docs_app_api_v0_entry_url(public_id: public_id_for(slug), locale: "ja", host: @host))

    assert_response :success
    response.parsed_body
  end

  def index(**params)
    host!(@host)
    get(docs_app_api_v0_entries_url(locale: "ja", host: @host, **params))

    assert_response :success
    response.parsed_body.fetch("data")
  end
end

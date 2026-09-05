# typed: false
# frozen_string_literal: true

require "test_helper"

class InfoSurfacePublishingTest < ActionDispatch::IntegrationTest
  SURFACES = [
    { host_fallback: "info.app.localhost", audience: "app" },
    { host_fallback: "info.com.localhost", audience: "com" },
    { host_fallback: "info.org.localhost", audience: "org" },
  ].freeze

  test "info surfaces read published entries from the publishing DB" do
    SURFACES.each do |surface|
      host! surface.fetch(:host_fallback)
      audience = surface.fetch(:audience)
      entry = create_published_entry(audience:, slug: "#{audience}-info-smoke")

      get "/api/v0/entries", headers: { "Host" => surface.fetch(:host_fallback), "Accept" => "application/json" },
                             as: :json

      assert_response :success, audience
      json_entry =
        response.parsed_body.fetch("data").find { |candidate|
          candidate.fetch("slug") == entry.slugs.first.slug
        }

      assert json_entry, "expected #{audience} index to include the published entry"
      assert_equal "info", json_entry.fetch("namespace")
      assert_equal audience, json_entry.fetch("surface")

      get "/api/v0/entries/#{entry.public_id}",
          headers: { "Host" => surface.fetch(:host_fallback), "Accept" => "application/json" }, as: :json

      assert_response :success, audience
      assert_equal entry.public_id, response.parsed_body.fetch("public_id")
      assert_equal entry.slugs.first.slug, response.parsed_body.fetch("slug")
    end
  end

  test "info show returns 404 for an unknown public_id" do
    host! "info.app.localhost"

    get "/api/v0/entries/does-not-exist", headers: { "Accept" => "application/json" }, as: :json

    assert_response :not_found
  end

  private

  def create_published_entry(audience:, slug:)
    edition = Publishing::Edition.find_or_create_by!(audience:, surface: "info", locale: "ja")
    entry = Publishing::Entry.create!(edition:, locale: "ja")
    Publishing::EntrySlug.create!(
      entry:, edition:, locale: "ja", slug:, state: "canonical",
      canonicalized_at: Time.current,
    )
    digest = "f" * 64
    revision =
      Publishing::EntryRevision.create!(
        entry:, locale: "ja", title: "T", summary: "S", body: { "text" => "hello" }, schema_version: 1,
        content_digest: digest, sequence: 1,
      )
    entry.update!(current_revision: revision)
    version =
      Publishing::EntryVersion.create!(
        entry:, entry_revision: revision, locale: "ja", title: "T", summary: "S", body: { "text" => "hello" },
        schema_version: 1, content_digest: digest, sequence: 1,
      )
    Publishing::Publication.create!(entry:, entry_version: version, effective_from: 1.hour.ago)
    entry
  end
end

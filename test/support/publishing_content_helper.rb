# frozen_string_literal: true

# Builds publishing fixtures through the real lifecycle: a draft revision
# promoted by Publishing::PromoteRevisionOperation, then published. Tests
# that need a partially built entry stop earlier by passing a different status.
module PublishingContentHelper
  REGIONAL_SURFACES = %w(docs news help).freeze

  # A statement rejected by PostgreSQL aborts the surrounding transaction, so a
  # test asserting several rejections has to isolate each one in its own
  # savepoint. Active Record does this automatically for model saves but not for
  # update_columns or raw SQL.
  def assert_database_rejects(error_class = ActiveRecord::StatementInvalid, &)
    assert_raises(error_class) do
      PublishingRecord.transaction(requires_new: true, &)
    end
  end

  # Info is global and carries no region; docs, news, and help are regional and
  # must carry one, per chk_publishing_editions_region.
  def publishing_edition(audience:, surface:, locale:)
    Publishing::Edition.find_or_create_by!(audience:, surface:, locale:) do |edition|
      edition.region_code = "jp" if REGIONAL_SURFACES.include?(surface.to_s)
    end
  end

  def publishing_vocabulary(audience:, surface:, key:, kind:)
    Publishing::Vocabulary.find_or_create_by!(audience:, surface:, key:) do |vocabulary|
      vocabulary.kind = kind
      vocabulary.internal_name = key.capitalize
    end
  end

  def publishing_category_vocabulary(audience:, surface:)
    publishing_vocabulary(audience:, surface:, key: "category", kind: Publishing::TaxonomyKind::SINGLE_HIERARCHICAL)
  end

  def publishing_tag_vocabulary(audience:, surface:)
    publishing_vocabulary(audience:, surface:, key: "tag", kind: Publishing::TaxonomyKind::MULTIPLE_ORDERED_FLAT)
  end

  def publishing_term(vocabulary:, locale:, slug:, name: nil, parent: nil)
    Publishing::TaxonomyTerm.create!(
      vocabulary:, vocabulary_kind: vocabulary.kind, locale:, slug:, name: name || slug.titleize,
      parent:, depth: parent ? parent.depth + 1 : 0,
      position: Publishing::TaxonomyTerm.next_sibling_position(
        vocabulary_id: vocabulary.id, locale:, parent_id: parent&.id,
      ),
    )
  end

  def publishing_draft(edition:, slug:, title:, locale: nil, sequence: 1)
    locale ||= edition.locale
    entry = Publishing::Entry.create!(edition:, locale:)
    Publishing::EntrySlug.create!(entry:, edition:, locale:, slug:, state: "canonical", canonicalized_at: Time.current)
    revision = publishing_revision(entry:, title:, locale:, sequence:)
    entry.update!(current_revision: revision)
    entry
  end

  def publishing_revision(entry:, title:, locale: nil, sequence: 1)
    locale ||= entry.locale
    Publishing::EntryRevision.create!(
      entry:, locale:, title:, summary: "#{title} summary", body: { "text" => "#{title} body" },
      schema_version: 1, content_digest: Digest::SHA256.hexdigest("#{title}-#{sequence}"), sequence:,
    )
  end

  def publishing_publish(entry:, published_at: 1.hour.ago, effective_until: nil)
    version = Publishing::PromoteRevisionOperation.call(revision: entry.current_revision)
    Publishing::Publication.create!(entry:, entry_version: version, effective_from: published_at, effective_until:)
    entry
  end

  def publishing_media_file(storage_key: nil)
    Publishing::MediaFile.create!(
      storage_key: storage_key || "test/#{SecureRandom.hex(12)}",
      content_type: "image/png",
      byte_size: 32,
      digest_algorithm: "sha256",
      digest: Digest::SHA256.hexdigest(SecureRandom.hex(8)),
      metadata: {},
    )
  end

  def publishing_revision_media_usage(
    revision:, media_file:, role: "body", position: 0, field_path: "body.blocks.0", block_path: "blocks.0",
    caption: nil, alt_text: nil, presentation_metadata: nil
  )
    Publishing::RevisionMediaUsage.create!(
      entry_revision: revision,
      media_file:,
      role:,
      field_path:,
      block_path:,
      position:,
      caption:,
      alt_text:,
      presentation_metadata:,
    )
  end

  # One-call fixture: draft, promote, publish.
  def publishing_published_entry(audience:, surface:, slug:, title:, locale: "ja", published_at: 1.hour.ago)
    edition = publishing_edition(audience:, surface:, locale:)
    entry = publishing_draft(edition:, slug:, title:, locale:)
    publishing_publish(entry:, published_at:)
  end
end

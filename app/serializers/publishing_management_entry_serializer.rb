# typed: false
# frozen_string_literal: true

# Allowlisted Publishing entry data for the Edit RP (R5-WU13, one.md section 6.4).
#
# The Publishing authority answers with these plain values only, never Active Record objects, so
# the Edit RP renders pages without reading the publishing database. Keys are stable contract
# fields; adding one is a contract change.
class PublishingManagementEntrySerializer
  class << self
    public

    def summary(entry)
      revision = entry.current_revision
      {
        "public_id" => entry.public_id,
        "title" => revision&.title,
        "locale" => entry.locale,
        "canonical_slug" => entry.canonical_slug&.slug,
        "archive_state" => entry.archived? ? "archived" : "active",
        "publication_state" => entry.active_publication.present? ? "published" : "draft",
        "revision_sequence" => revision&.sequence,
        "updated_at" => entry.updated_at&.iso8601,
      }
    end

    def detail(entry)
      revision = entry.current_revision
      active = entry.active_publication
      summary(entry).merge(
        "current_revision_public_id" => revision&.public_id,
        "summary" => revision&.summary,
        "body" => revision&.body,
        "archive_reason" => entry.archive_reason,
        "revision_count" => entry.revisions.count,
        "version_count" => entry.versions.count,
        "lock_version" => entry.lock_version,
        "active_publication" => (publication(active) if active),
        "scheduled_publications" => scheduled(entry).map { |row| publication(row) },
      )
    end

    def page(page)
      {
        "entries" => page.entries.map { |entry| summary(entry) },
        "number" => page.number,
        "per_page" => page.per_page,
        "total" => page.total,
        "has_more" => page.has_more,
      }
    end

    private

    # Windows recorded but not yet started; the operator's only place to see or cancel them.
    def scheduled(entry)
      entry.publications.includes(:entry_version).where(cancelled_at: nil, terminated_at: nil)
        .where(effective_from: Time.current...).order(:effective_from)
    end

    def publication(row)
      {
        "public_id" => row.public_id,
        "effective_from" => row.effective_from.iso8601,
        "version_public_id" => row.entry_version.public_id,
      }
    end
  end
end

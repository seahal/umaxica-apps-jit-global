# typed: false
# frozen_string_literal: true

module Publishing
  # Opens a published version back up for editing as a new draft revision.
  #
  # Restoring the same version twice deliberately produces two distinct
  # revisions: each restore is a new editing session, not a repeat of one.
  # This operation is therefore not idempotent, and it must not be treated as
  # if it were. When a public write endpoint is introduced it needs its own
  # transport-level idempotency (an idempotency key carried by the request);
  # disabling a button in a UI is not network idempotency.
  #
  # Restoration is deterministic: assignments are rebuilt from the version's
  # live foreign keys, never by looking terms up again by snapshot slug or
  # name. A term that has since been archived is allowed into the draft --
  # otherwise old content could never be reopened -- and
  # Publishing::PromoteRevisionOperation refuses to publish it until the
  # author resolves it.
  class RestoreVersionOperation < ApplicationService
    def initialize(version:, operator_public_id: nil)
      super()
      @version = version
      @operator_public_id = operator_public_id
    end

    def call
      entry = version.entry

      entry.with_lock do
        revision = create_revision(entry)
        copy_taxonomy_assignments(revision)
        copy_media_usages(revision)
        entry.update!(current_revision: revision)
        revision
      end
    end

    private

    attr_reader :version, :operator_public_id

    def create_revision(entry)
      EntryRevision.create!(
        entry:,
        locale: version.locale,
        title: version.title,
        summary: version.summary,
        body: version.body,
        schema_version: version.schema_version,
        content_digest: version.content_digest,
        created_by_operator_public_id: operator_public_id,
        restored_from_version_id: version.id,
        sequence: next_sequence(entry),
      )
    end

    def next_sequence(entry)
      (entry.revisions.maximum(:sequence) || 0) + 1
    end

    # Snapshot columns stay frozen history; the draft is rebuilt from live
    # identifiers so the author edits today's terms, not yesterday's strings.
    def copy_taxonomy_assignments(revision)
      version.single_taxonomy_assignments.each do |assignment|
        RevisionSingleTaxonomyAssignment.create!(
          entry_revision: revision,
          vocabulary_id: assignment.vocabulary_id,
          vocabulary_kind: assignment.vocabulary_kind,
          taxonomy_term_id: assignment.taxonomy_term_id,
          locale: assignment.locale,
        )
      end

      version.multiple_taxonomy_assignments.ordered.each do |assignment|
        RevisionMultipleTaxonomyAssignment.create!(
          entry_revision: revision,
          vocabulary_id: assignment.vocabulary_id,
          vocabulary_kind: assignment.vocabulary_kind,
          taxonomy_term_id: assignment.taxonomy_term_id,
          locale: assignment.locale,
          position: assignment.position,
        )
      end
    end

    def copy_media_usages(revision)
      version.media_usages.find_each do |usage|
        RevisionMediaUsage.create!(
          media_file_id: usage.media_file_id,
          entry_revision: revision,
          role: usage.role,
          field_path: usage.field_path,
          block_path: usage.block_path,
          position: usage.position,
          alt_text: usage.alt_text,
          caption: usage.caption,
          presentation_metadata: usage.presentation_metadata,
        )
      end
    end
  end
end

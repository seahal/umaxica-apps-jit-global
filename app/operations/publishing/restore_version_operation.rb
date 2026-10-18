# typed: false
# frozen_string_literal: true

module Publishing
  class RestoreVersionOperation < ApplicationService
    def initialize(version:, operator_public_id: nil)
      super()
      @version = version
      @operator_public_id = operator_public_id
      @cell = ContentFamilies.cell_for_version(version)
    end

    def call
      entry = cell.fetch(:entry).find(version.entry_id)

      entry.with_lock do
        revision = create_revision(entry)
        copy_taxonomy_assignments(revision)
        copy_media_usages(revision)
        entry.update!(current_revision: revision)
        revision
      end
    end

    private

    attr_reader :version, :operator_public_id, :cell

    def create_revision(entry)
      entry.revisions.create!(
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

    def copy_taxonomy_assignments(revision)
      cell.fetch(:version_single).where(entry_version_id: version.id).find_each do |assignment|
        cell.fetch(:revision_single).create!(
          entry_revision_id: revision.id,
          vocabulary_id: assignment.vocabulary_id,
          vocabulary_kind: assignment.vocabulary_kind,
          taxonomy_term_id: assignment.taxonomy_term_id,
          locale: assignment.locale,
        )
      end

      cell.fetch(:version_multiple).where(entry_version_id: version.id).order(:position).find_each do |assignment|
        cell.fetch(:revision_multiple).create!(
          entry_revision_id: revision.id,
          vocabulary_id: assignment.vocabulary_id,
          vocabulary_kind: assignment.vocabulary_kind,
          taxonomy_term_id: assignment.taxonomy_term_id,
          locale: assignment.locale,
          position: assignment.position,
        )
      end
    end

    def copy_media_usages(revision)
      cell.fetch(:version_media).where(entry_version_id: version.id).find_each do |usage|
        cell.fetch(:revision_media).create!(
          entry_revision_id: revision.id,
          media_file_id: usage.media_file_id,
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

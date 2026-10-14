# typed: false
# frozen_string_literal: true

module Publishing
  class ReviseEntryOperation < ApplicationService
    def initialize(entry:, title:, summary:, body:, lock_version:, operator_public_id:)
      super()
      @entry = entry
      @title = title
      @summary = summary
      @body = body
      @lock_version = lock_version
      @operator_public_id = operator_public_id
    end

    # Failure messages are single strings, not arrays. They reach the edit view through the same
    # `errors` prop as `ReviseEntryForm#message_hash`, and `ManagementEdit` types that prop as
    # `Record<string, string>` and renders each value directly; an array rendered there is React
    # concatenating its elements, which reads as a message only by accident.
    def call
      entry.with_lock do
        return PublishingReviseEntryResult.failure(lock_version: "is stale") if stale_lock?

        cell = ContentFamilies.cell_for_entry(entry)
        revision_class = cell.fetch(:revision)
        current = revision_class.find_by(id: entry.current_revision_id)
        if current.blank?
          return PublishingReviseEntryResult.failure(base: "entry has no current revision")
        end

        revision = create_revision(current)
        copy_taxonomy_assignments(current, revision)
        copy_media_usages(current, revision)
        entry.update!(current_revision: revision)
        PublishingReviseEntryResult.success(revision)
      end
    end

    private

    attr_reader :entry, :title, :summary, :body, :lock_version, :operator_public_id

    def stale_lock?
      lock_version.nil? || entry.lock_version != lock_version.to_i
    end

    def create_revision(current)
      entry.revisions.create!(
        locale: current.locale,
        title:,
        summary:,
        body:,
        schema_version: current.schema_version,
        content_digest: PublishingRevisionContentDigest.call(
          schema_version: current.schema_version,
          locale: current.locale,
          title:,
          summary:,
          body:,
        ),
        restored_from_revision_id: current.id,
        created_by_operator_public_id: operator_public_id,
        sequence: next_sequence,
      )
    end

    def next_sequence
      (entry.revisions.maximum(:sequence) || 0) + 1
    end

    def copy_taxonomy_assignments(source, revision)
      cell = ContentFamilies.cell_for_revision(source)
      cell.fetch(:revision_single).where(entry_revision_id: source.id).find_each do |assignment|
        cell.fetch(:revision_single).create!(
          entry_revision_id: revision.id,
          vocabulary_id: assignment.vocabulary_id,
          vocabulary_kind: assignment.vocabulary_kind,
          taxonomy_term_id: assignment.taxonomy_term_id,
          locale: assignment.locale,
        )
      end

      cell.fetch(:revision_multiple).where(entry_revision_id: source.id).order(:position).find_each do |assignment|
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

    def copy_media_usages(source, revision)
      cell = ContentFamilies.cell_for_revision(source)
      cell.fetch(:revision_media).where(entry_revision_id: source.id).find_each do |usage|
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

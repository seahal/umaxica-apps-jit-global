# typed: false
# frozen_string_literal: true

module Publishing
  # Freezes a draft revision into an immutable version, together with a
  # complete snapshot of its taxonomy assignments.
  #
  # This operation owns the transaction. Promotion is deliberately not a model
  # callback: a version and its snapshots must commit together or not at all,
  # and that boundary belongs somewhere a reader can see it.
  #
  # Idempotency rests on UNIQUE(entry_revision_id) in
  # publishing_entry_versions. A concurrent second attempt loses the insert,
  # then re-reads the winner and verifies it is a complete snapshot of the
  # same revision rather than returning whatever row it happens to find.
  class PromoteRevisionOperation < ApplicationService
    class RevisionMismatchError < StandardError; end

    class IncompleteVersionError < StandardError; end

    def initialize(revision:, operator_public_id: nil)
      super()
      @revision = revision
      @operator_public_id = operator_public_id
    end

    # The unique index that makes promotion idempotent. Any other uniqueness
    # failure is a real error and must not be swallowed as a lost race.
    IDEMPOTENCY_INDEX = "index_publishing_entry_versions_on_entry_revision_id"

    def call
      entry = revision.entry
      raise(RevisionMismatchError, "revision #{revision.id} has no entry") unless entry

      entry.with_lock do
        existing = EntryVersion.find_by(entry_revision_id: revision.id)
        next verify_complete!(existing) if existing

        lock_taxonomy!
        reject_archived_assignments!
        create_version(entry)
      end
    end

    private

    attr_reader :revision, :operator_public_id

    def create_version(entry)
      version =
        EntryVersion.create!(
          entry:,
          entry_revision: revision,
          locale: revision.locale,
          title: revision.title,
          summary: revision.summary,
          body: revision.body,
          schema_version: revision.schema_version,
          content_digest: revision.content_digest,
          created_by_operator_public_id: operator_public_id || revision.created_by_operator_public_id,
          sequence: next_sequence(entry),
        )
      copy_taxonomy_assignments(version)
      copy_media_usages(version)
      version
    rescue ActiveRecord::RecordNotUnique => e
      # Only a collision on the idempotency index means another promotion of
      # this same revision won the race. Anything else -- a duplicate sequence,
      # a duplicate public id -- is a genuine failure.
      raise unless e.message.include?(IDEMPOTENCY_INDEX)

      verify_complete!(EntryVersion.find_by!(entry_revision_id: revision.id))
    end

    # Locking the assigned vocabularies in a deterministic order stops a
    # concurrent rename or subtree move from changing a breadcrumb midway
    # through snapshot generation, and stops two promotions from deadlocking.
    # MoveTaxonomySubtreeOperation takes the same vocabulary lock, exclusively.
    def lock_taxonomy!
      vocabulary_ids =
        (revision.single_taxonomy_assignments.pluck(:vocabulary_id) +
          revision.multiple_taxonomy_assignments.pluck(:vocabulary_id)).uniq
      vocabulary_ids.sort!
      return if vocabulary_ids.empty?

      Vocabulary.where(id: vocabulary_ids).order(:id).lock("FOR SHARE").load
    end

    def next_sequence(entry)
      (entry.versions.maximum(:sequence) || 0) + 1
    end

    # A version may never commit holding a partial snapshot, so the copies run
    # inside the caller's transaction and any failure rolls the version back.
    def copy_taxonomy_assignments(version)
      # The vocabulary and term of every assignment are read for the snapshot,
      # so they are loaded up front rather than one row at a time.
      revision.single_taxonomy_assignments.includes(:vocabulary, :taxonomy_term).find_each do |assignment|
        VersionSingleTaxonomyAssignment
          .new(
            entry_version: version,
            vocabulary_id: assignment.vocabulary_id,
            vocabulary_kind: assignment.vocabulary_kind,
            taxonomy_term_id: assignment.taxonomy_term_id,
            locale: assignment.locale,
          )
          .apply_snapshot(vocabulary: assignment.vocabulary, term: assignment.taxonomy_term)
          .save!
      end

      revision.multiple_taxonomy_assignments.includes(:vocabulary, :taxonomy_term).find_each do |assignment|
        VersionMultipleTaxonomyAssignment
          .new(
            entry_version: version,
            vocabulary_id: assignment.vocabulary_id,
            vocabulary_kind: assignment.vocabulary_kind,
            taxonomy_term_id: assignment.taxonomy_term_id,
            locale: assignment.locale,
            position: assignment.position,
          )
          .apply_snapshot(vocabulary: assignment.vocabulary, term: assignment.taxonomy_term)
          .save!
      end
    end

    def copy_media_usages(version)
      revision.media_usages.find_each do |usage|
        VersionMediaUsage.create!(
          media_file_id: usage.media_file_id,
          entry_version: version,
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

    def reject_archived_assignments!
      archived = revision.archived_taxonomy_assignments
      return if archived.empty?

      # Every obsolete term on the breadcrumb is reported, not just the assigned
      # leaf, so an authoring UI can show everything that needs resolving.
      details =
        archived.flat_map do |assignment|
          obsolete = assignment.taxonomy_term.archived_in_path
          obsolete = [assignment.taxonomy_term] if obsolete.empty?
          obsolete.map do |term|
            ArchivedTaxonomyAssignmentError::Detail.new(
              vocabulary_key: assignment.vocabulary.key,
              term_public_id: term.public_id,
              term_slug: term.slug,
              revision_public_id: revision.public_id,
              assigned_term_public_id: assignment.taxonomy_term.public_id,
              vocabulary_archived: assignment.vocabulary.archived?,
            )
          end
        end
      raise(ArchivedTaxonomyAssignmentError, details)
    end

    # Proves the winning version really is this revision's complete snapshot
    # before handing it back to a caller that lost the race.
    def verify_complete!(version)
      unless version.entry_revision_id == revision.id
        raise(RevisionMismatchError, "version #{version.id} does not belong to revision #{revision.id}")
      end

      expected_single = revision.single_taxonomy_assignments.count
      expected_multiple = revision.multiple_taxonomy_assignments.count
      expected_media = revision.media_usages.count
      actual_single = version.single_taxonomy_assignments.count
      actual_multiple = version.multiple_taxonomy_assignments.count
      actual_media = version.media_usages.count

      unless expected_single == actual_single && expected_multiple == actual_multiple && expected_media == actual_media
        raise(
          IncompleteVersionError,
          "version #{version.id} holds #{actual_single}/#{actual_multiple} taxonomy snapshots " \
          "and #{actual_media} media usages, expected #{expected_single}/#{expected_multiple} " \
          "and #{expected_media}",
        )
      end

      version
    end
  end
end

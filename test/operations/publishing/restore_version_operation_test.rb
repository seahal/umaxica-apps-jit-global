# frozen_string_literal: true

require "test_helper"

module Publishing
  class RestoreVersionOperationTest < ActiveSupport::TestCase
    setup do
      @category = publishing_category_vocabulary(audience: "app", surface: "docs")
      @tag = publishing_tag_vocabulary(audience: "app", surface: "docs")
      @guide = publishing_term(vocabulary: @category, locale: "ja", slug: "guide", name: "ガイド")
      @ruby = publishing_term(vocabulary: @tag, locale: "ja", slug: "ruby", name: "Ruby")
      @rails = publishing_term(vocabulary: @tag, locale: "ja", slug: "rails", name: "Rails")

      @entry = publishing_draft(audience: "app", surface: "docs", slug: "restorable", title: "Restorable")
      assign_category(@entry.current_revision, @guide)
      assign_tags(@entry.current_revision, [@rails, @ruby])
      @version = PromoteRevisionOperation.call(revision: @entry.current_revision)
    end

    test "creates a new draft revision recording where it was restored from" do
      revision = RestoreVersionOperation.call(version: @version)

      assert_equal @version.id, revision.restored_from_version_id
      assert_equal 2, revision.sequence
      assert_equal @version.title, revision.title
      assert_equal revision, @entry.reload.current_revision
    end

    test "recreates draft assignments from live identifiers and preserves tag order" do
      revision = RestoreVersionOperation.call(version: @version)

      assert_equal @guide.id,
                   Docs::App::RevisionSingleTaxonomyAssignment.find_by!(entry_revision_id: revision.id)
                     .taxonomy_term_id
      assert_equal(
        %w(rails ruby),
        Docs::App::RevisionMultipleTaxonomyAssignment.where(entry_revision_id: revision.id)
          .includes(:taxonomy_term).order(:position).map { |assignment|
          assignment.taxonomy_term.slug
        },
      )
      assert_equal [0, 1],
                   Docs::App::RevisionMultipleTaxonomyAssignment.where(entry_revision_id: revision.id)
                     .order(:position).map(&:position)
    end

    test "restoring twice deliberately produces two distinct revisions" do
      first = RestoreVersionOperation.call(version: @version)
      second = RestoreVersionOperation.call(version: @version)

      assert_not_equal first.id, second.id
      assert_equal [2, 3], [first.sequence, second.sequence]
      assert_equal second, @entry.reload.current_revision
    end

    test "a restored draft may hold an archived term, but cannot be promoted until it is resolved" do
      @guide.update!(archived_at: Time.current, archive_reason: "retired")

      revision = RestoreVersionOperation.call(version: @version)

      assert_equal @guide.id,
                   Docs::App::RevisionSingleTaxonomyAssignment.find_by!(entry_revision_id: revision.id)
                     .taxonomy_term_id
      assert_raises(ArchivedTaxonomyAssignmentError) { PromoteRevisionOperation.call(revision:) }

      Docs::App::RevisionSingleTaxonomyAssignment.where(entry_revision_id: revision.id).destroy_all

      assert_nothing_raised { PromoteRevisionOperation.call(revision: revision.reload) }
    end

    test "restoration follows the historical term even after it was renamed or moved" do
      renamed = publishing_term(vocabulary: @category, locale: "ja", slug: "new-parent", name: "新しい親")
      @guide.update!(name: "改名", slug: "renamed")
      MoveTaxonomySubtreeOperation.call(term: @guide, new_parent: renamed)

      revision = RestoreVersionOperation.call(version: @version)
      assignment = Docs::App::RevisionSingleTaxonomyAssignment.includes(:taxonomy_term)
        .find_by!(entry_revision_id: revision.id)

      # The live foreign key still points at the same term row, which now
      # carries its current name and place in the tree.
      assert_equal @guide.id, assignment.taxonomy_term_id
      assert_equal "renamed", assignment.taxonomy_term.slug
      # The published version keeps what it published.
      assert_equal "guide", Docs::App::VersionSingleTaxonomyAssignment.find_by!(entry_version_id: @version.id)
        .term_slug_snapshot
    end

    test "a restored draft can be promoted into a second immutable version" do
      revision = RestoreVersionOperation.call(version: @version)

      promoted = PromoteRevisionOperation.call(revision:)

      assert_not_equal @version.id, promoted.id
      assert_equal 2, promoted.sequence
      assert_equal %w(rails ruby),
                   Docs::App::VersionMultipleTaxonomyAssignment.where(entry_version_id: promoted.id)
                     .order(:position).map(&:term_slug_snapshot)
    end

    private

    def assign_category(revision, term)
      create_single_assignment(
        entry_revision: revision, vocabulary: @category, vocabulary_kind: @category.kind, taxonomy_term: term,
        locale: "ja",
      )
    end

    def assign_tags(revision, terms)
      terms.each_with_index do |term, position|
        create_multiple_assignment(
          entry_revision: revision, vocabulary: @tag, vocabulary_kind: @tag.kind, taxonomy_term: term,
          locale: "ja", position:,
        )
      end
    end
  end
end

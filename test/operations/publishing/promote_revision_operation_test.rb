# frozen_string_literal: true

require "test_helper"

module Publishing
  class PromoteRevisionOperationTest < ActiveSupport::TestCase
    setup do
      @category = publishing_category_vocabulary(audience: "app", surface: "docs")
      @tag = publishing_tag_vocabulary(audience: "app", surface: "docs")
      @guide = publishing_term(vocabulary: @category, locale: "ja", slug: "guide", name: "ガイド")
      @setup_term = publishing_term(vocabulary: @category, locale: "ja", slug: "setup", name: "セットアップ", parent: @guide)
      @ruby = publishing_term(vocabulary: @tag, locale: "ja", slug: "ruby", name: "Ruby")
      @rails = publishing_term(vocabulary: @tag, locale: "ja", slug: "rails", name: "Rails")
    end

    test "promotes a revision that carries no taxonomy" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "plain", title: "Plain")

      version = PromoteRevisionOperation.call(revision: entry.current_revision)

      assert_equal entry.current_revision, version.entry_revision
      assert_equal 1, version.sequence
      assert_equal "Plain", version.title
      assert_empty version.single_taxonomy_assignments
      assert_empty version.multiple_taxonomy_assignments
    end

    test "snapshots a category with its full breadcrumb path" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "with-category", title: "With Category")
      assign_category(entry.current_revision, @setup_term)

      version = PromoteRevisionOperation.call(revision: entry.current_revision)
      snapshot = version.single_taxonomy_assignments.sole

      assert_equal "category", snapshot.vocabulary_key_snapshot
      assert_equal "setup", snapshot.term_slug_snapshot
      assert_equal "セットアップ", snapshot.term_name_snapshot
      assert_equal %w(guide setup), snapshot.term_path_snapshot.map { |step| step.fetch("slug") }
      assert_equal @setup_term.id, snapshot.taxonomy_term_id
    end

    test "snapshots ordered tags and preserves their order" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "with-tags", title: "With Tags")
      assign_tags(entry.current_revision, [@rails, @ruby])

      version = PromoteRevisionOperation.call(revision: entry.current_revision)

      assert_equal %w(rails ruby), version.multiple_taxonomy_assignments.map(&:term_slug_snapshot)
      assert_equal [0, 1], version.multiple_taxonomy_assignments.map(&:position_snapshot)
    end

    test "renaming or moving a term afterwards does not change what the version published" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "frozen", title: "Frozen")
      assign_category(entry.current_revision, @setup_term)
      version = PromoteRevisionOperation.call(revision: entry.current_revision)

      @setup_term.update!(name: "新しい名前", slug: "renamed")
      MoveTaxonomySubtreeOperation.call(term: @setup_term, new_parent: nil)

      snapshot = version.reload.single_taxonomy_assignments.sole

      assert_equal "setup", snapshot.term_slug_snapshot
      assert_equal "セットアップ", snapshot.term_name_snapshot
      assert_equal %w(guide setup), snapshot.term_path_snapshot.map { |step| step.fetch("slug") }
    end

    test "refuses to promote a revision assigning an archived term" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "archived-term", title: "Archived Term")
      assign_category(entry.current_revision, @setup_term)
      @setup_term.update!(archived_at: Time.current, archive_reason: "retired")

      error =
        assert_raises(ArchivedTaxonomyAssignmentError) {
          PromoteRevisionOperation.call(revision: entry.current_revision)
        }
      detail = error.details.sole

      assert_equal "category", detail.vocabulary_key
      assert_equal "setup", detail.term_slug
      assert_equal @setup_term.public_id, detail.term_public_id
      assert_equal entry.current_revision.public_id, detail.revision_public_id
      assert_nil Docs::App::EntryVersion.find_by(entry_revision_id: entry.current_revision.id)
    end

    test "refuses to promote a revision assigning an archived vocabulary" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "archived-vocabulary", title: "Archived Docs::App::Vocabulary")
      assign_category(entry.current_revision, @setup_term)
      @category.update!(archived_at: Time.current, archive_reason: "retired")

      assert_raises(ArchivedTaxonomyAssignmentError) { PromoteRevisionOperation.call(revision: entry.current_revision) }
    end

    test "promoting twice yields the same version with one complete snapshot set" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "idempotent", title: "Idempotent")
      assign_category(entry.current_revision, @setup_term)
      assign_tags(entry.current_revision, [@ruby])

      first = PromoteRevisionOperation.call(revision: entry.current_revision)
      second = PromoteRevisionOperation.call(revision: entry.current_revision)

      assert_equal first.id, second.id
      assert_equal 1, Docs::App::EntryVersion.where(entry_revision_id: entry.current_revision.id).count
      assert_equal 1, Docs::App::VersionSingleTaxonomyAssignment.where(entry_version_id: first.id).count
      assert_equal 1, Docs::App::VersionMultipleTaxonomyAssignment.where(entry_version_id: first.id).count
    end

    test "a promoted revision and its assignments are frozen by the database" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "frozen-revision", title: "Frozen Revision")
      assign_tags(entry.current_revision, [@ruby])
      revision = entry.current_revision
      PromoteRevisionOperation.call(revision:)
      connection = PublishingRecord.lease_connection

      # Without this, a revision could drift away from the version promoted from
      # it, and UNIQUE(entry_revision_id) makes a corrected version impossible.
      assert_database_rejects {
        connection.execute("UPDATE publishing_entry_revisions SET title = 'drifted' WHERE id = #{revision.id}")
      }
      assert_database_rejects { connection.execute("DELETE FROM publishing_entry_revisions WHERE id = #{revision.id}") }
      assert_database_rejects { assign_tags(revision, [@rails]) }
      assert_database_rejects do
        connection.execute(
          "DELETE FROM publishing_revision_multiple_taxonomy_assignments WHERE " \
          "entry_revision_id = #{revision.id}",
        )
      end
      assert_database_rejects do
        connection.execute(
          "UPDATE publishing_revision_multiple_taxonomy_assignments SET position = 9 WHERE entry_revision_id = " \
          "#{revision.id}",
        )
      end

      assert_equal "Frozen Revision", revision.reload.title
    end

    test "a draft revision that was never promoted stays editable" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "editable-revision", title: "Editable Revision")
      revision = entry.current_revision

      assign_tags(revision, [@ruby])
      revision.update!(title: "Edited")

      assert_equal "Edited", revision.reload.title
      assert_equal 1, revision.multiple_taxonomy_assignments.count
    end

    test "a version cannot commit without the snapshots its revision requires" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "incomplete", title: "Incomplete")
      revision = entry.current_revision
      assign_category(revision, @setup_term)
      assign_tags(revision, [@ruby])

      # The deferred completeness trigger fires at COMMIT, so this has to escape
      # the surrounding test transaction to be observed.
      assert_raises(ActiveRecord::StatementInvalid) do
        PublishingRecord.transaction(requires_new: true) do
          entry.versions.create!(
            entry_revision: revision, locale: "ja", title: "Incomplete", body: { "text" => "x" },
            schema_version: 1, content_digest: "f" * 64, sequence: 99,
          )
          PublishingRecord.lease_connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
        end
      end
    end

    test "a failure while copying assignments leaves no version behind" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "rollback", title: "Rollback")
      assign_category(entry.current_revision, @setup_term)
      revision = entry.current_revision

      assignment_class = revision.entry.versions.klass.reflect_on_association(:single_taxonomy_assignments).klass

      assignment_class.stub(:new, ->(*) { raise(ActiveRecord::StatementInvalid, "boom") }) do
        assert_raises(ActiveRecord::StatementInvalid) { PromoteRevisionOperation.call(revision:) }
      end

      assert_nil entry.versions.find_by(entry_revision_id: revision.id)
      assert_equal 0, assignment_class.where(vocabulary_id: @category.id).count
    end

    test "sequences increment per entry" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "sequenced", title: "Sequenced")
      first = PromoteRevisionOperation.call(revision: entry.current_revision)
      second_revision = publishing_revision(entry:, title: "Sequenced v2", sequence: 2)

      second = PromoteRevisionOperation.call(revision: second_revision)

      assert_equal 1, first.sequence
      assert_equal 2, second.sequence
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

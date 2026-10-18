# frozen_string_literal: true

require "test_helper"

module Publishing
  class ReviseEntryOperationTest < ActiveSupport::TestCase
    test "creates the next revision and leaves the previous revision unchanged" do
      entry = publishing_draft(audience: "app", surface: "info", slug: "guide", title: "Guide")
      previous = entry.current_revision
      previous_title = previous.title
      previous_body = previous.body.deep_dup

      result = ReviseEntryOperation.call(
        entry:,
        title: "Guide v2",
        summary: "Updated summary",
        body: { "text" => "Updated body" },
        lock_version: entry.lock_version,
        operator_public_id: "OPERATORPUBLICID1",
      )

      assert_predicate result, :ok?
      entry.reload

      assert_equal result.revision, entry.current_revision
      assert_equal 2, result.revision.sequence
      assert_equal "Guide v2", result.revision.title
      assert_equal "Updated summary", result.revision.summary
      assert_equal({ "text" => "Updated body" }, result.revision.body)
      previous.reload

      assert_equal previous_title, previous.title
      assert_equal previous_body, previous.body
      assert_equal 1, previous.sequence
      assert_not_equal previous.content_digest, result.revision.content_digest
    end

    test "copies taxonomy assignments and media usages onto the new revision" do
      category = publishing_category_vocabulary(audience: "app", surface: "docs")
      tag = publishing_tag_vocabulary(audience: "app", surface: "docs")
      guide = publishing_term(vocabulary: category, locale: "ja", slug: "guide", name: "ガイド")
      ruby = publishing_term(vocabulary: tag, locale: "ja", slug: "ruby", name: "Ruby")
      rails = publishing_term(vocabulary: tag, locale: "ja", slug: "rails", name: "Rails")
      entry = publishing_draft(audience: "app", surface: "docs", slug: "assigned", title: "Assigned")
      revision = entry.current_revision
      create_single_assignment(
        entry_revision: revision, vocabulary: category, taxonomy_term: guide, locale: "ja",
      )
      create_multiple_assignment(
        entry_revision: revision, vocabulary: tag, taxonomy_term: rails, locale: "ja", position: 0,
      )
      create_multiple_assignment(
        entry_revision: revision, vocabulary: tag, taxonomy_term: ruby, locale: "ja", position: 1,
      )
      media_file = publishing_media_file
      publishing_revision_media_usage(revision:, media_file:, role: "hero")

      result = ReviseEntryOperation.call(
        entry:,
        title: "Assigned v2",
        summary: revision.summary,
        body: revision.body,
        lock_version: entry.lock_version,
        operator_public_id: "OPERATORPUBLICID1",
      )

      next_revision = result.revision

      assert_equal guide.id,
                   Docs::App::RevisionSingleTaxonomyAssignment.find_by!(entry_revision_id: next_revision.id)
                     .taxonomy_term_id
      assert_equal(
        [rails.id, ruby.id],
        Docs::App::RevisionMultipleTaxonomyAssignment.where(entry_revision_id: next_revision.id)
          .order(:position).map(&:taxonomy_term_id),
      )
      usage = Docs::App::RevisionMediaUsage.find_by!(entry_revision_id: next_revision.id)

      assert_equal media_file.id, usage.media_file_id
      assert_equal "hero", usage.role
      assert_equal 1, revision.media_usages.count
    end

    test "rejects a stale lock_version without creating a revision" do
      entry = publishing_draft(audience: "app", surface: "info", slug: "stale", title: "Stale")
      current = entry.current_revision

      result = ReviseEntryOperation.call(
        entry:,
        title: "Should not persist",
        summary: "no",
        body: { "text" => "no" },
        lock_version: entry.lock_version - 1,
        operator_public_id: "OPERATORPUBLICID1",
      )

      assert_not result.ok?
      assert_equal current, entry.reload.current_revision
      assert_equal 1, entry.revisions.count
    end

    # A form that never rendered the lock_version field, or one whose field was stripped, arrives
    # here as nil. Treating that as "no concurrent edit" would make every such request overwrite
    # whatever revision won the race, so an absent lock is as stale as a wrong one.
    test "rejects a missing lock_version as stale" do
      entry = publishing_draft(audience: "app", surface: "info", slug: "no-lock", title: "No lock")

      result = ReviseEntryOperation.call(
        entry:, title: "Should not persist", summary: "no", body: { "text" => "no" }, lock_version: nil,
        operator_public_id: "OPERATORPUBLICID1",
      )

      assert_not result.ok?
      assert_equal "is stale", result.errors.fetch(:lock_version)
      assert_equal 1, entry.reload.revisions.count
    end

    # Every field of the new revision is copied from the current one, so without a current
    # revision there is nothing to revise. Reporting that beats raising NoMethodError deep in
    # `create_revision`.
    test "refuses an entry that has no current revision" do
      entry = publishing_draft(audience: "app", surface: "info", slug: "orphan", title: "Orphan")
      entry.update!(current_revision: nil)

      result = ReviseEntryOperation.call(
        entry:, title: "Title", summary: "summary", body: { "text" => "body" },
        lock_version: entry.reload.lock_version, operator_public_id: "OPERATORPUBLICID1",
      )

      assert_not result.ok?
      assert_equal "entry has no current revision", result.errors.fetch(:base)
      assert_equal 1, entry.reload.revisions.count
    end
  end
end

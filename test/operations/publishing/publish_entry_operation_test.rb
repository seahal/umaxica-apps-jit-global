# frozen_string_literal: true

require "test_helper"

module Publishing
  class PublishEntryOperationTest < ActiveSupport::TestCase
    test "an archived entry is refused rather than published" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "archived-publish", title: "Archived")
      entry.update!(archived_at: Time.current, archive_reason: "retired")

      result = PublishEntryOperation.call(entry: entry, operator_public_id: "OPERATORPUBLICID1")

      assert_not result.ok?
      assert_equal "an archived entry cannot be published", result.errors.fetch(:base)
      assert_equal 0, entry.reload.publications.count
      assert_equal 0, entry.versions.count
    end

    # `excl_<cell>_pub_windows` refuses two overlapping windows for one entry. A second open-ended
    # window scheduled after the first overlaps it, and the operator is told so instead of seeing
    # the constraint violation.
    test "a second scheduled window that overlaps the first is refused" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "overlapping", title: "Overlapping")

      first = PublishEntryOperation.call(
        entry: entry, operator_public_id: "OPERATORPUBLICID1", effective_from: 2.days.from_now,
      )

      assert_predicate first, :ok?

      second = PublishEntryOperation.call(
        entry: entry.reload, operator_public_id: "OPERATORPUBLICID1", effective_from: 3.days.from_now,
      )

      assert_not second.ok?
      assert_equal(
        "overlaps a publication window that is already scheduled",
        second.errors.fetch(:effective_from),
      )
      assert_equal 1, entry.reload.publications.count
    end

    # Terminating the live window at a time before it started is not expressible:
    # `chk_<cell>_pub_window` requires `effective_until > effective_from`.
    test "a window that would start before the live one became effective is refused" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "backdated", title: "Backdated")
      publishing_publish(entry: entry, published_at: 1.hour.ago)
      live = Docs::App::Publication.active.find_by(entry_id: entry.reload.id)

      result = PublishEntryOperation.call(
        entry: entry, operator_public_id: "OPERATORPUBLICID1", effective_from: 2.hours.ago,
      )

      assert_not result.ok?
      assert_equal(
        "must be after the current publication became effective",
        result.errors.fetch(:effective_from),
      )
      assert_equal live, Docs::App::Publication.active.find_by(entry_id: entry.reload.id)
      assert_equal 1, entry.publications.count
    end

    test "the operator is recorded on the version and on the publication" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "provenance-publish", title: "Provenance")

      result = PublishEntryOperation.call(entry: entry, operator_public_id: "OPERATORPUBLICID1")

      assert_predicate result, :ok?
      assert_equal "OPERATORPUBLICID1", result.publication.created_by_operator_public_id
      assert_equal "OPERATORPUBLICID1", Docs::App::EntryVersion.find_by!(entry_id: entry.reload.id)
        .created_by_operator_public_id
    end
  end
end

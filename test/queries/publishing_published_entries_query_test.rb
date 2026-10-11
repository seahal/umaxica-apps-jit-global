# frozen_string_literal: true

require "test_helper"

class PublishingPublishedEntriesQueryTest < ActiveSupport::TestCase
  # Seven statements: entries, canonical slugs, publications, versions, one per
  # version taxonomy assignment table, and the surface's vocabularies. All are
  # per-request, so the count stays flat as the number of entries grows -- which
  # is what this guards.
  EXPECTED_INDEX_QUERIES = 7

  test "orders by publication time then public_id without pagination mechanics" do
    published_at = Time.zone.parse("2026-03-01 09:00:00 UTC")
    older = publishing_publish(
      entry: publishing_draft(audience: "app", surface: "info", slug: "older", title: "Older"),
      published_at: published_at - 1.hour,
    )
    tied_a = publishing_publish(
      entry: publishing_draft(audience: "app", surface: "info", slug: "tied-a", title: "Tied A"),
      published_at:,
    )
    tied_b = publishing_publish(
      entry: publishing_draft(audience: "app", surface: "info", slug: "tied-b", title: "Tied B"),
      published_at:,
    )
    query = publishing_query(audience: "app", surface: "info")
    result = query.call.to_a

    assert_kind_of ActiveRecord::Relation, query.call
    assert_equal older, result.last
    assert_equal [tied_a, tied_b].map(&:public_id).sort, result.first(2).map(&:public_id).sort
    assert_equal result.map(&:public_id), publishing_query(audience: "app", surface: "info").call.map(&:public_id)
  end

  test "returns only entries with an active publication" do
    published_entry = publishing_publish(
      entry: publishing_draft(
        audience: "app", surface: "info",
        slug: "published-one", title: "Published",
      ),
    )
    draft_entry = publishing_draft(audience: "app", surface: "info", slug: "draft-one", title: "Draft")

    result = publishing_query(audience: "app", surface: "info").call

    assert_includes result, published_entry
    assert_not_includes result, draft_entry
  end

  test "excludes an archived entry even while its publication window is open" do
    entry = publishing_publish(
      entry: publishing_draft(
        audience: "app", surface: "info", slug: "archived-one",
        title: "Archived",
      ),
    )

    assert_includes publishing_query(audience: "app", surface: "info").call, entry

    entry.update!(archived_at: Time.current, archive_reason: "withdrawn")

    assert_not_includes publishing_query(audience: "app", surface: "info").call, entry
    assert_nil publishing_query(audience: "app", surface: "info").find_published(public_id: entry.public_id)
  end

  test "excludes a cancelled publication" do
    entry = publishing_draft(audience: "app", surface: "info", slug: "cancelled-one", title: "Cancelled")
    version = Publishing::PromoteRevisionOperation.call(revision: entry.current_revision)
    entry.publications.create!(
      entry_version: version, effective_from: 1.hour.from_now,
      cancelled_at: Time.current, cancellation_reason: "pulled before going live",
    )

    assert_not_includes publishing_query(audience: "app", surface: "info").call, entry
  end

  test "excludes a publication whose window has not opened yet" do
    entry = publishing_draft(audience: "app", surface: "info", slug: "scheduled-one", title: "Scheduled")
    version = Publishing::PromoteRevisionOperation.call(revision: entry.current_revision)
    entry.publications.create!(entry_version: version, effective_from: 1.hour.from_now)

    query = publishing_query(audience: "app", surface: "info")

    assert_not_includes query.call, entry
    assert_nil query.find_published(public_id: entry.public_id)
  end

  test "a terminated publication stops being served once its window closes" do
    entry = publishing_draft(audience: "app", surface: "info", slug: "terminated-one", title: "Terminated")
    version = Publishing::PromoteRevisionOperation.call(revision: entry.current_revision)
    terminated_at = 1.minute.ago
    entry.publications.create!(
      entry_version: version, effective_from: 2.hours.ago, effective_until: terminated_at,
      terminated_at:, termination_reason: "superseded",
    )

    assert_not_includes publishing_query(audience: "app", surface: "info").call, entry
  end

  test "find_published resolves a published entry by its public_id" do
    entry = publishing_publish(
      entry: publishing_draft(
        audience: "app", surface: "info", slug: "canonical-one",
        title: "Canonical",
      ),
    )

    assert_equal entry, publishing_query(audience: "app", surface: "info").find_published(public_id: entry.public_id)
  end

  test "find_published does not accept the database primary key or the slug" do
    entry = publishing_publish(
      entry: publishing_draft(
        audience: "app", surface: "info", slug: "identity-guard",
        title: "Identity Guard",
      ),
    )
    query = publishing_query(audience: "app", surface: "info")

    assert_nil query.find_published(public_id: entry.id.to_s)
    assert_nil query.find_published(public_id: "identity-guard")
  end

  test "find_published will not resolve an entry from another edition" do
    entry = publishing_publish(
      entry: publishing_draft(
        audience: "app", surface: "info", slug: "cell-bound",
        title: "Cell Bound",
      ),
    )

    assert_nil publishing_query(audience: "com", surface: "info").find_published(public_id: entry.public_id)
  end

  test "find_published returns nil for a draft or an archived entry" do
    draft = publishing_draft(audience: "app", surface: "info", slug: "no-publication", title: "No Publication")
    archived = publishing_publish(
      entry: publishing_draft(
        audience: "app", surface: "info", slug: "was-published",
        title: "Was Published",
      ),
    )
    archived.update!(archived_at: Time.current, archive_reason: "withdrawn")
    query = publishing_query(audience: "app", surface: "info")

    assert_nil query.find_published(public_id: draft.public_id)
    assert_nil query.find_published(public_id: archived.public_id)
  end

  test "filters by the published version's category and tag slugs" do
    category = publishing_category_vocabulary(audience: "app", surface: "info")
    tag = publishing_tag_vocabulary(audience: "app", surface: "info")
    guide = publishing_term(vocabulary: category, locale: "ja", slug: "guide")
    ruby = publishing_term(vocabulary: tag, locale: "ja", slug: "ruby")

    tagged = publishing_draft(audience: "app", surface: "info", slug: "tagged-entry", title: "Tagged")
    create_single_assignment(
      entry_revision: tagged.current_revision, vocabulary: category, vocabulary_kind: category.kind,
      taxonomy_term: guide, locale: "ja",
    )
    create_multiple_assignment(
      entry_revision: tagged.current_revision, vocabulary: tag, vocabulary_kind: tag.kind,
      taxonomy_term: ruby, locale: "ja", position: 0,
    )
    publishing_publish(entry: tagged)
    plain = publishing_publish(
      entry: publishing_draft(
        audience: "app", surface: "info", slug: "plain-entry",
        title: "Plain",
      ),
    )

    assert_equal [tagged], publishing_query(audience: "app", surface: "info", category: "guide").call.to_a
    assert_equal [tagged], publishing_query(audience: "app", surface: "info", tag: "ruby").call.to_a
    assert_includes publishing_query(audience: "app", surface: "info").call, plain
  end

  test "an unknown filter term returns no entries rather than falling back" do
    publishing_publish(entry: publishing_draft(audience: "app", surface: "info", slug: "plain-one", title: "Plain"))

    assert_empty publishing_query(audience: "app", surface: "info", category: "never-existed").call.to_a
    assert_empty publishing_query(audience: "app", surface: "info", tag: "never-existed").call.to_a
  end

  test "filters follow the published snapshot, not the live term" do
    category = publishing_category_vocabulary(audience: "app", surface: "info")
    term = publishing_term(vocabulary: category, locale: "ja", slug: "old-name")

    entry = publishing_draft(audience: "app", surface: "info", slug: "renamed-entry", title: "Renamed")
    create_single_assignment(
      entry_revision: entry.current_revision, vocabulary: category, vocabulary_kind: category.kind,
      taxonomy_term: term, locale: "ja",
    )
    publishing_publish(entry:)

    term.update!(slug: "new-name", name: "New Name")

    # A URL built from the published JSON keeps working, and the new name does
    # not retroactively match content published under the old one.
    assert_equal [entry], publishing_query(audience: "app", surface: "info", category: "old-name").call.to_a
    assert_empty publishing_query(audience: "app", surface: "info", category: "new-name").call.to_a

    # Archiving the live term does not unpublish what was already published, so
    # the published snapshot stays findable by the slug the response emits.
    term.update!(archived_at: Time.current, archive_reason: "retired")

    assert_equal [entry], publishing_query(audience: "app", surface: "info", category: "old-name").call.to_a
  end

  test "a category filter matches exactly and does not select descendants" do
    category = publishing_category_vocabulary(audience: "app", surface: "info")
    parent = publishing_term(vocabulary: category, locale: "ja", slug: "parent")
    child = publishing_term(vocabulary: category, locale: "ja", slug: "child", parent:)

    entry = publishing_draft(audience: "app", surface: "info", slug: "child-entry", title: "Child")
    create_single_assignment(
      entry_revision: entry.current_revision, vocabulary: category, vocabulary_kind: category.kind,
      taxonomy_term: child, locale: "ja",
    )
    publishing_publish(entry:)

    assert_equal [entry], publishing_query(audience: "app", surface: "info", category: "child").call.to_a
    assert_empty publishing_query(audience: "app", surface: "info", category: "parent").call.to_a
  end

  test "a draft-only assignment never makes an entry findable by filter" do
    category = publishing_category_vocabulary(audience: "app", surface: "info")
    term = publishing_term(vocabulary: category, locale: "ja", slug: "draft-only")

    entry = publishing_publish(
      entry: publishing_draft(
        audience: "app", surface: "info", slug: "later-tagged",
        title: "Later Tagged",
      ),
    )
    revision = publishing_revision(entry:, title: "Later Tagged v2", sequence: 2)
    create_single_assignment(
      entry_revision: revision, vocabulary: category, vocabulary_kind: category.kind,
      taxonomy_term: term, locale: "ja",
    )
    entry.update!(current_revision: revision)

    assert_empty publishing_query(audience: "app", surface: "info", category: "draft-only").call.to_a
  end

  test "serializing a published index uses a fixed number of queries" do
    3.times { |index|
      publishing_publish(
        entry: publishing_draft(
          audience: "app", surface: "info", slug: "query-count-#{index}",
          title: "Title #{index}",
        ),
      )
    }

    queries = []
    subscriber =
      lambda do |*, payload|
        sql = payload[:sql]
        next if payload[:cached] || payload[:name] == "SCHEMA"
        next if sql.match?(/\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE SAVEPOINT)/)

        queries << sql
      end

    entries = nil
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      # Mirrors the controller: the surface's vocabularies are loaded once and
      # shared across every entry in the response.
      vocabularies = Publishing::Info::App::Vocabulary.available.order(:key).to_a
      entries =
        publishing_query(audience: "app", surface: "info").call.map { |entry|
          PublishingEntrySerializer.call(entry:, namespace: :info, surface: :app, vocabularies:)
        }
    end

    assert_equal 3, entries.size
    assert_operator queries.size, :<=, EXPECTED_INDEX_QUERIES, queries.join("\n")
  end
end

# frozen_string_literal: true

require "test_helper"

module Publishing
  # These tests must observe real commits from real concurrent connections, so
  # they opt out of the transactional fixture wrapper. Without that, both
  # "threads" would share one connection and one transaction, and the race being
  # tested would never happen.
  class PromotionConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      @category = publishing_category_vocabulary(audience: "app", surface: "docs")
      @tag = publishing_tag_vocabulary(audience: "app", surface: "docs")
      @guide = publishing_term(vocabulary: @category, locale: "ja", slug: "concurrency-guide", name: "Guide")
      @leaf = publishing_term(
        vocabulary: @category, locale: "ja", slug: "concurrency-leaf", name: "Leaf",
        parent: @guide,
      )
      @ruby = publishing_term(vocabulary: @tag, locale: "ja", slug: "concurrency-ruby", name: "Ruby")
      @entry = publishing_draft(audience: "app", surface: "docs", slug: "concurrency-entry", title: "Concurrency")
      create_single_assignment(
        entry_revision: @entry.current_revision, vocabulary: @category, vocabulary_kind: @category.kind,
        taxonomy_term: @leaf, locale: "ja",
      )
      create_multiple_assignment(
        entry_revision: @entry.current_revision, vocabulary: @tag, vocabulary_kind: @tag.kind,
        taxonomy_term: @ruby, locale: "ja", position: 0,
      )
    end

    teardown do
      destroy_publishing_fixtures
    end

    test "two concurrent promotions produce one complete version and both callers see it" do
      revision = @entry.current_revision
      results = concurrently(2) { PromoteRevisionOperation.call(revision: Docs::App::EntryRevision.find(revision.id)) }

      assert_equal 1, Docs::App::EntryVersion.where(entry_revision_id: revision.id).count
      assert_equal 1, results.map(&:id).uniq.size

      version = Docs::App::EntryVersion.find_by!(entry_revision_id: revision.id)

      assert_equal 1, version.single_taxonomy_assignments.count
      assert_equal 1, version.multiple_taxonomy_assignments.count
      assert_equal "concurrency-leaf", version.single_taxonomy_assignments.sole.term_slug_snapshot
    end

    test "a subtree move racing a promotion yields one coherent breadcrumb, never a mixed one" do
      revision = @entry.current_revision
      other_root = publishing_term(vocabulary: @category, locale: "ja", slug: "concurrency-other", name: "Other")

      results =
        concurrently(2) do |index|
          if index.zero?
            PromoteRevisionOperation.call(revision: Docs::App::EntryRevision.find(revision.id))
          else
            MoveTaxonomySubtreeOperation.call(
              term: Docs::App::TaxonomyTerm.find(@guide.id),
              new_parent: Docs::App::TaxonomyTerm.find(other_root.id),
            )
          end
        end

      assert_empty results.grep(StandardError), "both operations must succeed"
      path = Docs::App::EntryVersion
        .find_by!(entry_revision_id: revision.id)
        .single_taxonomy_assignments
        .sole
        .term_path_snapshot
      slugs = path.map { |step| step.fetch("slug") }

      # Either the pre-move path or the post-move path, never a half-applied mix.
      assert_includes(
        [%w(concurrency-guide concurrency-leaf), %w(concurrency-other concurrency-guide concurrency-leaf)],
        slugs,
      )
    end

    private

    # Each block runs on its own checked-out connection so PostgreSQL sees
    # genuinely concurrent transactions. Real threads are the point here: a
    # simulated race on one connection would prove nothing.
    # rubocop:disable ThreadSafety/NewThread
    def concurrently(count, &block)
      threads =
        Array.new(count) do |index|
          Thread.new do
            PublishingRecord.connection_pool.with_connection { block.call(index) }
          rescue StandardError => e
            e
          end
        end
      threads.map(&:value)
    end
    # rubocop:enable ThreadSafety/NewThread

    def destroy_publishing_fixtures
      connection = PublishingRecord.lease_connection
      connection.execute("SET session_replication_role = replica")
      connection.tables.grep(/\Apublishing_/).each { |table| connection.execute("DELETE FROM #{table}") }
    ensure
      connection.execute("SET session_replication_role = origin")
    end
  end
end

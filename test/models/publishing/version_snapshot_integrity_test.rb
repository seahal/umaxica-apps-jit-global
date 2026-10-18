# frozen_string_literal: true

require "test_helper"

module Publishing
  # Snapshot columns are the authority for historical rendering, so they are
  # derived by PostgreSQL from the live rows rather than trusted from whoever
  # writes the assignment.
  class VersionSnapshotIntegrityTest < ActiveSupport::TestCase
    setup do
      @category = publishing_category_vocabulary(audience: "app", surface: "docs")
      @tag = publishing_tag_vocabulary(audience: "app", surface: "docs")
      @root = publishing_term(vocabulary: @category, locale: "ja", slug: "root", name: "Root")
      @leaf = publishing_term(vocabulary: @category, locale: "ja", slug: "leaf", name: "Leaf", parent: @root)
      @ruby = publishing_term(vocabulary: @tag, locale: "ja", slug: "ruby", name: "Ruby")
      @connection = PublishingRecord.lease_connection
    end

    test "forged snapshot values are overwritten with the live vocabulary and term" do
      version = promote(category: @leaf)
      forged = Docs::App::VersionSingleTaxonomyAssignment.find_by!(entry_version_id: version.id)

      # Every snapshot column was supplied by the operation, yet the row holds
      # what the database derived.
      assert_equal "leaf", forged.term_slug_snapshot
      assert_equal "Leaf", forged.term_name_snapshot
      assert_equal "category", forged.vocabulary_key_snapshot
      assert_equal @leaf.public_id, forged.term_public_id_snapshot
      assert_equal %w(root leaf), forged.term_path_snapshot.map { |step| step.fetch("slug") }
    end

    test "a direct insert claiming a different term name, slug, or path is corrected" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "forgery", title: "Forgery")
      revision = entry.current_revision
      create_single_assignment(
        entry_revision: revision, vocabulary: @category, vocabulary_kind: @category.kind, taxonomy_term: @leaf,
        locale: "ja",
      )
      version = Docs::App::EntryVersion.create!(
        entry:, entry_revision: revision, locale: "ja", title: "Forgery", body: { "text" => "x" },
        schema_version: 1, content_digest: "d" * 64, sequence: 1,
      )

      @connection.execute(<<~SQL.squish)
        INSERT INTO publishing_docs_app_version_single_taxonomy_assignments
          (entry_version_id, vocabulary_id, vocabulary_kind, taxonomy_term_id, locale,
           vocabulary_public_id_snapshot, vocabulary_key_snapshot, vocabulary_kind_snapshot,
           term_public_id_snapshot, term_slug_snapshot, term_name_snapshot, term_path_snapshot,
           locale_snapshot, created_at, updated_at)
        VALUES (#{version.id}, #{@category.id}, 'single_hierarchical', #{@leaf.id}, 'ja',
           '#{"z" * 21}', 'forged_key', 'single_hierarchical',
           '#{"z" * 21}', 'forged-slug', 'Forged Name', '[]'::jsonb, 'ja', now(), now())
      SQL

      stored = Docs::App::VersionSingleTaxonomyAssignment.find_by!(entry_version_id: version.id)

      assert_equal "leaf", stored.term_slug_snapshot
      assert_equal "Leaf", stored.term_name_snapshot
      assert_equal "category", stored.vocabulary_key_snapshot
      assert_equal @leaf.public_id, stored.term_public_id_snapshot
      assert_equal %w(root leaf), stored.term_path_snapshot.map { |step| step.fetch("slug") }
    end

    test "a forged ordered position snapshot is replaced by the assigned position" do
      version = promote(tags: [@ruby])
      stored = Docs::App::VersionMultipleTaxonomyAssignment.find_by!(entry_version_id: version.id)

      assert_equal stored.position, stored.position_snapshot
    end

    test "an extra snapshot the revision never assigned is rejected at commit" do
      rails = publishing_term(vocabulary: @tag, locale: "ja", slug: "rails", name: "Rails")
      version = promote(tags: [@ruby])

      assert_database_rejects do
        PublishingRecord.transaction(requires_new: true) do
          @connection.execute(<<~SQL.squish)
            INSERT INTO publishing_version_multiple_taxonomy_assignments
              (entry_version_id, vocabulary_id, vocabulary_kind, taxonomy_term_id, locale, position,
               vocabulary_public_id_snapshot, vocabulary_key_snapshot, vocabulary_kind_snapshot,
               term_public_id_snapshot, term_slug_snapshot, term_name_snapshot, term_path_snapshot,
               locale_snapshot, position_snapshot, created_at, updated_at)
            VALUES (#{version.id}, #{@tag.id}, 'multiple_ordered_flat', #{rails.id}, 'ja', 1,
               '#{@tag.public_id}', 'tag', 'multiple_ordered_flat',
               '#{rails.public_id}', 'rails', 'Rails', '[]'::jsonb, 'ja', 1, now(), now())
          SQL
          @connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
        end
      end

      assert_equal 1, Docs::App::VersionMultipleTaxonomyAssignment.where(entry_version_id: version.id).count
    end

    test "a snapshot at a position the revision never used is rejected at commit" do
      version = promote(tags: [@ruby])
      assignment = Docs::App::VersionMultipleTaxonomyAssignment.find_by!(entry_version_id: version.id)

      assert_database_rejects do
        PublishingRecord.transaction(requires_new: true) do
          @connection.execute(<<~SQL.squish)
            INSERT INTO publishing_version_multiple_taxonomy_assignments
              (entry_version_id, vocabulary_id, vocabulary_kind, taxonomy_term_id, locale, position,
               vocabulary_public_id_snapshot, vocabulary_key_snapshot, vocabulary_kind_snapshot,
               term_public_id_snapshot, term_slug_snapshot, term_name_snapshot, term_path_snapshot,
               locale_snapshot, position_snapshot, created_at, updated_at)
            VALUES (#{version.id}, #{@tag.id}, 'multiple_ordered_flat', #{assignment.taxonomy_term_id}, 'ja', 7,
               '#{@tag.public_id}', 'tag', 'multiple_ordered_flat',
               '#{@ruby.public_id}', 'ruby', 'Ruby', '[]'::jsonb, 'ja', 7, now(), now())
          SQL
          @connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
        end
      end

      assignments = Docs::App::VersionMultipleTaxonomyAssignment.where(entry_version_id: version.id)
      positions = assignments.order(:position).pluck(:position)

      assert_equal [0], positions
    end

    test "the breadcrumb path rejects extra keys and non-array shapes" do
      assert_not valid_path?("{}")
      assert_not valid_path?(%q({"a": 1}))
      assert_not valid_path?(%q([{"public_id": "x", "slug": "y"}]))
      assert_not valid_path?(%q([{"public_id": "x", "slug": "y", "name": "z", "extra": "no"}]))
      assert valid_path?("[]")
      assert valid_path?(%q([{"public_id": "x", "slug": "y", "name": "z"}]))
    end

    test "revision and version bodies must be JSON objects" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "body-shape", title: "Body Shape")

      %w("a string" [1,2] 12 true null).each do |body|
        assert_database_rejects do
          @connection.execute(<<~SQL.squish)
            INSERT INTO publishing_entry_revisions
              (public_id, entry_id, locale, title, body, schema_version, content_digest, sequence, created_at, updated_at)
            VALUES ('#{SecureRandom.alphanumeric(21)}', #{entry.id}, 'ja', 'T', '#{body}'::jsonb, 1, '#{"a" * 64}', 99, now(), now())
          SQL
        end
      end
    end

    test "as_public_json renders the frozen term identity and no database identifiers" do
      version = promote(category: @leaf, tags: [@ruby])
      single = Docs::App::VersionSingleTaxonomyAssignment.find_by!(entry_version_id: version.id)
      multiple = Docs::App::VersionMultipleTaxonomyAssignment.find_by!(entry_version_id: version.id)

      assert_equal(
        { "public_id" => @leaf.public_id, "slug" => "leaf", "name" => "Leaf" },
        single.as_public_json,
      )
      assert_equal(
        { "public_id" => @ruby.public_id, "slug" => "ruby", "name" => "Ruby" },
        multiple.as_public_json,
      )
    end

    private

    def valid_path?(json)
      @connection.select_value("SELECT publishing_valid_term_path('#{json}'::jsonb)")
    end

    def promote(category: nil, tags: [])
      entry = publishing_draft(
        audience: "app", surface: "docs", slug: "snapshot-#{SecureRandom.alphanumeric(6).downcase}",
        title: "Snapshot",
      )
      if category
        create_single_assignment(
          entry_revision: entry.current_revision, vocabulary: @category, vocabulary_kind: @category.kind,
          taxonomy_term: category, locale: "ja",
        )
      end
      tags.each_with_index do |term, position|
        create_multiple_assignment(
          entry_revision: entry.current_revision, vocabulary: @tag, vocabulary_kind: @tag.kind,
          taxonomy_term: term, locale: "ja", position:,
        )
      end
      PromoteRevisionOperation.call(revision: entry.current_revision)
    end
  end
end

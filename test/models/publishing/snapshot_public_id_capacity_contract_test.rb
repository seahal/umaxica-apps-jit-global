# frozen_string_literal: true

require "test_helper"

module Publishing
  class SnapshotPublicIdCapacityContractTest < ActiveSupport::TestCase
    TARGETS = [
      [
        Docs::App::Entry, Docs::App::EntryRevision,
        Docs::App::RevisionSingleTaxonomyAssignment, Docs::App::VersionSingleTaxonomyAssignment,
        Docs::App::Vocabulary, Docs::App::TaxonomyTerm,
      ],
      [
        Docs::App::Entry, Docs::App::EntryRevision,
        Docs::App::RevisionMultipleTaxonomyAssignment, Docs::App::VersionMultipleTaxonomyAssignment,
        Docs::App::Vocabulary, Docs::App::TaxonomyTerm,
      ],
      [
        Docs::Com::Entry, Docs::Com::EntryRevision,
        Docs::Com::RevisionSingleTaxonomyAssignment, Docs::Com::VersionSingleTaxonomyAssignment,
        Docs::Com::Vocabulary, Docs::Com::TaxonomyTerm,
      ],
      [
        Docs::Com::Entry, Docs::Com::EntryRevision,
        Docs::Com::RevisionMultipleTaxonomyAssignment, Docs::Com::VersionMultipleTaxonomyAssignment,
        Docs::Com::Vocabulary, Docs::Com::TaxonomyTerm,
      ],
      [
        Docs::Org::Entry, Docs::Org::EntryRevision,
        Docs::Org::RevisionSingleTaxonomyAssignment, Docs::Org::VersionSingleTaxonomyAssignment,
        Docs::Org::Vocabulary, Docs::Org::TaxonomyTerm,
      ],
      [
        Docs::Org::Entry, Docs::Org::EntryRevision,
        Docs::Org::RevisionMultipleTaxonomyAssignment, Docs::Org::VersionMultipleTaxonomyAssignment,
        Docs::Org::Vocabulary, Docs::Org::TaxonomyTerm,
      ],
      [
        Help::App::Entry, Help::App::EntryRevision,
        Help::App::RevisionSingleTaxonomyAssignment, Help::App::VersionSingleTaxonomyAssignment,
        Help::App::Vocabulary, Help::App::TaxonomyTerm,
      ],
      [
        Help::App::Entry, Help::App::EntryRevision,
        Help::App::RevisionMultipleTaxonomyAssignment, Help::App::VersionMultipleTaxonomyAssignment,
        Help::App::Vocabulary, Help::App::TaxonomyTerm,
      ],
      [
        Help::Com::Entry, Help::Com::EntryRevision,
        Help::Com::RevisionSingleTaxonomyAssignment, Help::Com::VersionSingleTaxonomyAssignment,
        Help::Com::Vocabulary, Help::Com::TaxonomyTerm,
      ],
      [
        Help::Com::Entry, Help::Com::EntryRevision,
        Help::Com::RevisionMultipleTaxonomyAssignment, Help::Com::VersionMultipleTaxonomyAssignment,
        Help::Com::Vocabulary, Help::Com::TaxonomyTerm,
      ],
      [
        Help::Org::Entry, Help::Org::EntryRevision,
        Help::Org::RevisionSingleTaxonomyAssignment, Help::Org::VersionSingleTaxonomyAssignment,
        Help::Org::Vocabulary, Help::Org::TaxonomyTerm,
      ],
      [
        Help::Org::Entry, Help::Org::EntryRevision,
        Help::Org::RevisionMultipleTaxonomyAssignment, Help::Org::VersionMultipleTaxonomyAssignment,
        Help::Org::Vocabulary, Help::Org::TaxonomyTerm,
      ],
      [
        Info::App::Entry, Info::App::EntryRevision,
        Info::App::RevisionSingleTaxonomyAssignment, Info::App::VersionSingleTaxonomyAssignment,
        Info::App::Vocabulary, Info::App::TaxonomyTerm,
      ],
      [
        Info::App::Entry, Info::App::EntryRevision,
        Info::App::RevisionMultipleTaxonomyAssignment, Info::App::VersionMultipleTaxonomyAssignment,
        Info::App::Vocabulary, Info::App::TaxonomyTerm,
      ],
      [
        Info::Com::Entry, Info::Com::EntryRevision,
        Info::Com::RevisionSingleTaxonomyAssignment, Info::Com::VersionSingleTaxonomyAssignment,
        Info::Com::Vocabulary, Info::Com::TaxonomyTerm,
      ],
      [
        Info::Com::Entry, Info::Com::EntryRevision,
        Info::Com::RevisionMultipleTaxonomyAssignment, Info::Com::VersionMultipleTaxonomyAssignment,
        Info::Com::Vocabulary, Info::Com::TaxonomyTerm,
      ],
      [
        Info::Org::Entry, Info::Org::EntryRevision,
        Info::Org::RevisionSingleTaxonomyAssignment, Info::Org::VersionSingleTaxonomyAssignment,
        Info::Org::Vocabulary, Info::Org::TaxonomyTerm,
      ],
      [
        Info::Org::Entry, Info::Org::EntryRevision,
        Info::Org::RevisionMultipleTaxonomyAssignment, Info::Org::VersionMultipleTaxonomyAssignment,
        Info::Org::Vocabulary, Info::Org::TaxonomyTerm,
      ],
      [
        News::App::Entry, News::App::EntryRevision,
        News::App::RevisionSingleTaxonomyAssignment, News::App::VersionSingleTaxonomyAssignment,
        News::App::Vocabulary, News::App::TaxonomyTerm,
      ],
      [
        News::App::Entry, News::App::EntryRevision,
        News::App::RevisionMultipleTaxonomyAssignment, News::App::VersionMultipleTaxonomyAssignment,
        News::App::Vocabulary, News::App::TaxonomyTerm,
      ],
      [
        News::Com::Entry, News::Com::EntryRevision,
        News::Com::RevisionSingleTaxonomyAssignment, News::Com::VersionSingleTaxonomyAssignment,
        News::Com::Vocabulary, News::Com::TaxonomyTerm,
      ],
      [
        News::Com::Entry, News::Com::EntryRevision,
        News::Com::RevisionMultipleTaxonomyAssignment, News::Com::VersionMultipleTaxonomyAssignment,
        News::Com::Vocabulary, News::Com::TaxonomyTerm,
      ],
      [
        News::Org::Entry, News::Org::EntryRevision,
        News::Org::RevisionSingleTaxonomyAssignment, News::Org::VersionSingleTaxonomyAssignment,
        News::Org::Vocabulary, News::Org::TaxonomyTerm,
      ],
      [
        News::Org::Entry, News::Org::EntryRevision,
        News::Org::RevisionMultipleTaxonomyAssignment, News::Org::VersionMultipleTaxonomyAssignment,
        News::Org::Vocabulary, News::Org::TaxonomyTerm,
      ],
    ].freeze

    TARGETS.each do |entry_class, revision_class, revision_assignment_class, snapshot_class,
                    vocabulary_class, term_class|
      test "#{snapshot_class.name} preserves short supplied IDs and derives the authoritative snapshot" do
        vocabulary = vocabulary_class.create!(
          key: "snapshot_capacity", kind: snapshot_class.expected_kind, internal_name: "Snapshot capacity",
        )
        term = term_class.create!(
          vocabulary: vocabulary, vocabulary_kind: vocabulary.kind, locale: "ja", slug: "snapshot-term",
          name: "Term", depth: 0, position: 0,
        )
        entry = entry_class.create!(locale: "ja")
        ordered = vocabulary.kind == Publishing::TaxonomyKind::MULTIPLE_ORDERED_FLAT

        [["x" * 20, 20], ["x" * 21, 21], [false, 1]].each_with_index do |(supplied, size), index|
          revision = revision_class.create!(
            entry: entry, locale: "ja", title: "Snapshot capacity", summary: "Summary",
            body: { "text" => "Body" }, schema_version: 1, content_digest: "d" * 64, sequence: index + 1,
          )
          assignment_attributes = {
            entry_revision: revision,
            vocabulary: vocabulary,
            vocabulary_kind: vocabulary.kind,
            taxonomy_term: term,
            locale: "ja",
          }
          assignment_attributes[:position] = 0 if ordered
          revision_assignment_class.create!(assignment_attributes)
          version = entry.versions.create!(
            revision.attributes.slice(
              "locale", "title", "summary", "body", "schema_version", "content_digest",
              "sequence",
            )
              .merge("entry_revision" => revision),
          )
          snapshot_attributes = {
            entry_version: version,
            vocabulary: vocabulary,
            vocabulary_kind: vocabulary.kind,
            taxonomy_term: term,
            locale: "ja",
          }
          snapshot_attributes[:position] = 0 if ordered
          snapshot = snapshot_class.new(snapshot_attributes).apply_snapshot(vocabulary: vocabulary, term: term)
          snapshot.assign_attributes(vocabulary_public_id_snapshot: supplied, term_public_id_snapshot: supplied)

          assert_equal size, snapshot.vocabulary_public_id_snapshot.length
          assert_equal size, snapshot.term_public_id_snapshot.length
          snapshot.save!

          assert_equal vocabulary.public_id, snapshot.reload.vocabulary_public_id_snapshot
          assert_equal term.public_id, snapshot.term_public_id_snapshot
          assert_equal term.public_id, snapshot.as_public_json.fetch("public_id")
          assert_equal 21, snapshot.vocabulary_public_id_snapshot.length
          assert_equal 21, snapshot.term_public_id_snapshot.length
          # Exercise existing deferred completeness checks, then restore the transaction mode
          # before preparing the next complete version. No constraint or trigger is introduced.
          snapshot_class.lease_connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
          snapshot_class.lease_connection.execute("SET CONSTRAINTS ALL DEFERRED")
        end
      end

      test "#{snapshot_class.name} rejects references above physical capacity while keeping presence rules" do
        vocabulary = vocabulary_class.create!(
          key: "snapshot_capacity", kind: snapshot_class.expected_kind, internal_name: "Snapshot capacity",
        )
        term = term_class.create!(
          vocabulary: vocabulary, vocabulary_kind: vocabulary.kind, locale: "ja", slug: "snapshot-term",
          name: "Term", depth: 0, position: 0,
        )
        entry = entry_class.create!(locale: "ja")
        ordered = vocabulary.kind == Publishing::TaxonomyKind::MULTIPLE_ORDERED_FLAT
        revision = revision_class.create!(
          entry: entry, locale: "ja", title: "Snapshot capacity", summary: "Summary",
          body: { "text" => "Body" }, schema_version: 1, content_digest: "d" * 64, sequence: 1,
        )
        assignment_attributes = {
          entry_revision: revision,
          vocabulary: vocabulary,
          vocabulary_kind: vocabulary.kind,
          taxonomy_term: term,
          locale: "ja",
        }
        assignment_attributes[:position] = 0 if ordered
        revision_assignment_class.create!(assignment_attributes)
        version = Publishing::PromoteRevisionOperation.call(revision: revision)
        stored = snapshot_class.find_by!(entry_version_id: version.id)

        original_count = snapshot_class.count
        %w(vocabulary_public_id_snapshot term_public_id_snapshot).each do |attribute|
          [22, 25].each do |size|
            candidate = snapshot_class.new(
              stored.attributes.except("id", "created_at", "updated_at").merge(attribute => "x" * size),
            )

            assert_not candidate.valid?
            assert candidate.errors.of_kind?(attribute, :too_long)
            assert_not candidate.save
            assert_not_predicate candidate, :persisted?
            assert_equal original_count, snapshot_class.count
            [:en, :ja].each do |locale|
              I18n.with_locale(locale) { assert_not_empty candidate.errors.full_messages_for(attribute) }
            end
          end
          [nil, ""].each do |missing|
            candidate = snapshot_class.new(
              stored.attributes.except("id", "created_at", "updated_at").merge(attribute => missing),
            )

            assert_not candidate.valid?
            assert candidate.errors.of_kind?(attribute, :blank)
          end
        end
      end

      test "#{snapshot_class.name} independently enforces DB capacity and keeps immutable update refusal" do
        vocabulary = vocabulary_class.create!(
          key: "snapshot_capacity", kind: snapshot_class.expected_kind, internal_name: "Snapshot capacity",
        )
        term = term_class.create!(
          vocabulary: vocabulary, vocabulary_kind: vocabulary.kind, locale: "ja", slug: "snapshot-term",
          name: "Term", depth: 0, position: 0,
        )
        entry = entry_class.create!(locale: "ja")
        ordered = vocabulary.kind == Publishing::TaxonomyKind::MULTIPLE_ORDERED_FLAT
        revision = revision_class.create!(
          entry: entry, locale: "ja", title: "Snapshot capacity", summary: "Summary",
          body: { "text" => "Body" }, schema_version: 1, content_digest: "d" * 64, sequence: 1,
        )
        assignment_attributes = {
          entry_revision: revision,
          vocabulary: vocabulary,
          vocabulary_kind: vocabulary.kind,
          taxonomy_term: term,
          locale: "ja",
        }
        assignment_attributes[:position] = 0 if ordered
        revision_assignment_class.create!(assignment_attributes)
        version = Publishing::PromoteRevisionOperation.call(revision: revision)
        stored = snapshot_class.find_by!(entry_version_id: version.id)

        connection = snapshot_class.lease_connection
        table = connection.quote_table_name(snapshot_class.table_name)
        columns = snapshot_class.column_names - ["id"]
        quoted_columns = columns.map { |column| connection.quote_column_name(column) }.join(", ")
        original = stored.attributes

        %w(vocabulary_public_id_snapshot term_public_id_snapshot).each do |attribute|
          projection = columns.map do |column|
            (column == attribute) ? connection.quote("x" * 22) : connection.quote_column_name(column)
          end.join(", ")
          error =
            assert_raises(ActiveRecord::StatementInvalid) do
              connection.transaction(requires_new: true) do
                # Internal SQL deliberately bypasses Active Record validation and serialization.
                # rubocop:disable I18n/RailsI18n/DecorateString
                connection.execute(
                  snapshot_class.sanitize_sql_array(
                    [
                      "INSERT INTO #{table} (#{quoted_columns}) " \
                      "SELECT #{projection} FROM #{table} WHERE id = ?", stored.id,
                    ],
                  ),
                )
                # rubocop:enable I18n/RailsI18n/DecorateString
              end
            end
          assert_instance_of PG::StringDataRightTruncation, error.cause
          assert_equal original, stored.reload.attributes

          assert_raises(ActiveRecord::ReadOnlyRecord) { stored.update!(attribute => "x" * 22) }
          assert_equal original, stored.reload.attributes

          error =
            assert_raises(ActiveRecord::StatementInvalid) do
              connection.transaction(requires_new: true) do
                connection.execute(
                  snapshot_class.sanitize_sql_array(
                    ["UPDATE #{table} SET #{connection.quote_column_name(attribute)} = ? WHERE id = ?", "x" * 21,
                     stored.id,],
                  ),
                )
              end
            end
          assert_instance_of PG::RaiseException, error.cause
          assert_includes error.message, "immutable"
          assert_equal original, stored.reload.attributes
        end
      end
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module Publishing
  class OrderedTaxonomyPositionContractTest < ActiveSupport::TestCase
    FAMILIES = [
      [
        Docs::App::Entry, Docs::App::EntryRevision,
        Docs::App::RevisionMultipleTaxonomyAssignment, Docs::App::VersionMultipleTaxonomyAssignment,
        Docs::App::Vocabulary, Docs::App::TaxonomyTerm, "docs_app",
      ],
      [
        Docs::Com::Entry, Docs::Com::EntryRevision,
        Docs::Com::RevisionMultipleTaxonomyAssignment, Docs::Com::VersionMultipleTaxonomyAssignment,
        Docs::Com::Vocabulary, Docs::Com::TaxonomyTerm, "docs_com",
      ],
      [
        Docs::Org::Entry, Docs::Org::EntryRevision,
        Docs::Org::RevisionMultipleTaxonomyAssignment, Docs::Org::VersionMultipleTaxonomyAssignment,
        Docs::Org::Vocabulary, Docs::Org::TaxonomyTerm, "docs_org",
      ],
      [
        Help::App::Entry, Help::App::EntryRevision,
        Help::App::RevisionMultipleTaxonomyAssignment, Help::App::VersionMultipleTaxonomyAssignment,
        Help::App::Vocabulary, Help::App::TaxonomyTerm, "help_app",
      ],
      [
        Help::Com::Entry, Help::Com::EntryRevision,
        Help::Com::RevisionMultipleTaxonomyAssignment, Help::Com::VersionMultipleTaxonomyAssignment,
        Help::Com::Vocabulary, Help::Com::TaxonomyTerm, "help_com",
      ],
      [
        Help::Org::Entry, Help::Org::EntryRevision,
        Help::Org::RevisionMultipleTaxonomyAssignment, Help::Org::VersionMultipleTaxonomyAssignment,
        Help::Org::Vocabulary, Help::Org::TaxonomyTerm, "help_org",
      ],
      [
        Info::App::Entry, Info::App::EntryRevision,
        Info::App::RevisionMultipleTaxonomyAssignment, Info::App::VersionMultipleTaxonomyAssignment,
        Info::App::Vocabulary, Info::App::TaxonomyTerm, "info_app",
      ],
      [
        Info::Com::Entry, Info::Com::EntryRevision,
        Info::Com::RevisionMultipleTaxonomyAssignment, Info::Com::VersionMultipleTaxonomyAssignment,
        Info::Com::Vocabulary, Info::Com::TaxonomyTerm, "info_com",
      ],
      [
        Info::Org::Entry, Info::Org::EntryRevision,
        Info::Org::RevisionMultipleTaxonomyAssignment, Info::Org::VersionMultipleTaxonomyAssignment,
        Info::Org::Vocabulary, Info::Org::TaxonomyTerm, "info_org",
      ],
      [
        News::App::Entry, News::App::EntryRevision,
        News::App::RevisionMultipleTaxonomyAssignment, News::App::VersionMultipleTaxonomyAssignment,
        News::App::Vocabulary, News::App::TaxonomyTerm, "news_app",
      ],
      [
        News::Com::Entry, News::Com::EntryRevision,
        News::Com::RevisionMultipleTaxonomyAssignment, News::Com::VersionMultipleTaxonomyAssignment,
        News::Com::Vocabulary, News::Com::TaxonomyTerm, "news_com",
      ],
      [
        News::Org::Entry, News::Org::EntryRevision,
        News::Org::RevisionMultipleTaxonomyAssignment, News::Org::VersionMultipleTaxonomyAssignment,
        News::Org::Vocabulary, News::Org::TaxonomyTerm, "news_org",
      ],
    ].freeze

    FAMILIES.each do |entry_class, revision_class, revision_assignment_class, version_assignment_class,
                     vocabulary_class, term_class, short_name|
      test "#{revision_assignment_class.name} and its version preserve bounded positions and immutable snapshots" do
        vocabulary = vocabulary_class.create!(
          key: "ordered_position", kind: Publishing::TaxonomyKind::MULTIPLE_ORDERED_FLAT, internal_name: "Tags",
        )
        term = term_class.create!(
          vocabulary: vocabulary, vocabulary_kind: vocabulary.kind, locale: "ja", slug: "ordered-tag",
          name: "Tag", depth: 0, position: 0,
        )
        entry = entry_class.create!(locale: "ja")

        [["0", 0], [false, 0], [1, 1], [2_147_483_646, 2_147_483_646],
         [2_147_483_647, 2_147_483_647],].each_with_index do |(position, expected_position), index|
          revision = revision_class.create!(
            entry: entry, locale: "ja", title: "Position contract", summary: "Summary",
            body: { "text" => "Body" }, schema_version: 1,
            content_digest: Digest::SHA256.hexdigest("position-contract"), sequence: index + 1,
          )
          assignment = revision_assignment_class.create!(
            entry_revision: revision, vocabulary: vocabulary, vocabulary_kind: vocabulary.kind,
            taxonomy_term: term, locale: "ja", position: position,
          )
          version = Publishing::PromoteRevisionOperation.call(revision: revision)
          snapshot = version_assignment_class.find_by!(entry_version_id: version.id)

          assert_equal expected_position, assignment.reload.position
          assert_equal expected_position, snapshot.position
          assert_equal expected_position, snapshot.position_snapshot

          [nil, -1, 2_147_483_648].each do |invalid_position|
            snapshot.position = invalid_position

            assert_raises(ActiveRecord::ReadOnlyRecord) { snapshot.save! }
            assert_equal expected_position, snapshot.reload.position
          end
        end
      end

      test "#{revision_assignment_class.name} rejects missing noninteger and out-of-range positions" do
        vocabulary = vocabulary_class.create!(
          key: "ordered_position", kind: Publishing::TaxonomyKind::MULTIPLE_ORDERED_FLAT, internal_name: "Tags",
        )
        term = term_class.create!(
          vocabulary: vocabulary, vocabulary_kind: vocabulary.kind, locale: "ja", slug: "ordered-tag",
          name: "Tag", depth: 0, position: 0,
        )
        entry = entry_class.create!(locale: "ja")
        revision = revision_class.create!(
          entry: entry, locale: "ja", title: "Position contract", summary: "Summary",
          body: { "text" => "Body" }, schema_version: 1,
          content_digest: Digest::SHA256.hexdigest("position-contract"), sequence: 1,
        )

        [nil, "", true, -1, 0.5, "not-a-number", 2_147_483_648].each do |position|
          assignment = revision_assignment_class.new(
            entry_revision: revision, vocabulary: vocabulary, vocabulary_kind: vocabulary.kind,
            taxonomy_term: term, locale: "ja", position: position,
          )

          assert_not assignment.valid?, "position #{position.inspect} must be rejected"
          assert_not_empty assignment.errors[:position]
          assert_not_empty assignment.errors.full_messages
          assert_predicate assignment, :new_record?
        end
      end

      test "#{version_assignment_class.name} rejects invalid positions on creation" do
        vocabulary = vocabulary_class.create!(
          key: "ordered_position", kind: Publishing::TaxonomyKind::MULTIPLE_ORDERED_FLAT, internal_name: "Tags",
        )
        term = term_class.create!(
          vocabulary: vocabulary, vocabulary_kind: vocabulary.kind, locale: "ja", slug: "ordered-tag",
          name: "Tag", depth: 0, position: 0,
        )
        entry = entry_class.create!(locale: "ja")
        revision = revision_class.create!(
          entry: entry, locale: "ja", title: "Position contract", summary: "Summary",
          body: { "text" => "Body" }, schema_version: 1,
          content_digest: Digest::SHA256.hexdigest("position-contract"), sequence: 1,
        )
        assignment = revision_assignment_class.create!(
          entry_revision: revision, vocabulary: vocabulary, vocabulary_kind: vocabulary.kind,
          taxonomy_term: term, locale: "ja", position: 0,
        )
        version = Publishing::PromoteRevisionOperation.call(revision: revision)
        snapshot = version_assignment_class.find_by!(entry_version_id: version.id)

        assert_equal assignment.taxonomy_term_id, snapshot.taxonomy_term_id

        [nil, "", true, -1, 0.5, "not-a-number", 2_147_483_648].each do |position|
          candidate = version_assignment_class.new(
            entry_version: version, vocabulary: vocabulary, vocabulary_kind: vocabulary.kind,
            taxonomy_term: term, locale: "ja", position: position,
          ).apply_snapshot(vocabulary: vocabulary, term: term)

          assert_not candidate.valid?, "position #{position.inspect} must be rejected"
          assert_not_empty candidate.errors[:position]
          assert_not_empty candidate.errors.full_messages
          assert_predicate candidate, :new_record?
        end
      end

      test "#{revision_assignment_class.name} database rejects invalid positions independently" do
        vocabulary = vocabulary_class.create!(
          key: "ordered_position", kind: Publishing::TaxonomyKind::MULTIPLE_ORDERED_FLAT, internal_name: "Tags",
        )
        term = term_class.create!(
          vocabulary: vocabulary, vocabulary_kind: vocabulary.kind, locale: "ja", slug: "ordered-tag",
          name: "Tag", depth: 0, position: 0,
        )
        entry = entry_class.create!(locale: "ja")
        revision = revision_class.create!(
          entry: entry, locale: "ja", title: "Position contract", summary: "Summary",
          body: { "text" => "Body" }, schema_version: 1,
          content_digest: Digest::SHA256.hexdigest("position-contract"), sequence: 1,
        )
        assignment = revision_assignment_class.create!(
          entry_revision: revision, vocabulary: vocabulary, vocabulary_kind: vocabulary.kind,
          taxonomy_term: term, locale: "ja", position: 0,
        )

        revision_assignment_class.connection_pool.with_connection do |connection|
          [[nil, PG::NotNullViolation], [-1, PG::CheckViolation],
           [2_147_483_648, PG::NumericValueOutOfRange],].each do |position, cause_class|
            # Bypass model validation/type serialization and contain each rejected SQL write in a savepoint.
            error =
              assert_raises(ActiveRecord::StatementInvalid) do
                connection.transaction(requires_new: true) do
                  connection.execute(
                    "UPDATE #{connection.quote_table_name(revision_assignment_class.table_name)} " \
                    "SET position = #{connection.quote(position)} WHERE id = #{connection.quote(assignment.id)}",
                  )
                end
              end

            assert_instance_of cause_class, error.cause
            if position.nil?
              assert_equal "position", error.cause.result.error_field(PG::Result::PG_DIAG_COLUMN_NAME)
            elsif position == -1
              assert_equal "chk_#{short_name}_rm_pos",
                           error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
            end

            assert_equal 0, assignment.reload.position
          end
        end
      end

      test "#{version_assignment_class.name} database rejects invalid position inserts independently" do
        vocabulary = vocabulary_class.create!(
          key: "ordered_position", kind: Publishing::TaxonomyKind::MULTIPLE_ORDERED_FLAT, internal_name: "Tags",
        )
        term = term_class.create!(
          vocabulary: vocabulary, vocabulary_kind: vocabulary.kind, locale: "ja", slug: "ordered-tag",
          name: "Tag", depth: 0, position: 0,
        )
        entry = entry_class.create!(locale: "ja")
        revision = revision_class.create!(
          entry: entry, locale: "ja", title: "Position contract", summary: "Summary",
          body: { "text" => "Body" }, schema_version: 1,
          content_digest: Digest::SHA256.hexdigest("position-contract"), sequence: 1,
        )
        assignment = revision_assignment_class.create!(
          entry_revision: revision, vocabulary: vocabulary, vocabulary_kind: vocabulary.kind,
          taxonomy_term: term, locale: "ja", position: 0,
        )
        version = Publishing::PromoteRevisionOperation.call(revision: revision)
        snapshot = version_assignment_class.find_by!(entry_version_id: version.id)

        assert_equal assignment.taxonomy_term_id, snapshot.taxonomy_term_id

        version_assignment_class.connection_pool.with_connection do |connection|
          table = connection.quote_table_name(version_assignment_class.table_name)
          columns = version_assignment_class.column_names - ["id"]
          quoted_columns = columns.map { |column| connection.quote_column_name(column) }.join(", ")
          [[nil, PG::NotNullViolation], [-1, PG::CheckViolation],
           [2_147_483_648, PG::NumericValueOutOfRange],].each do |position, cause_class|
            values = columns.map do |column|
              (column == "position") ? connection.quote(position) : connection.quote_column_name(column)
            end.join(", ")
            # An INSERT exercises the position constraints without hitting the immutable-update guard.
            error =
              assert_raises(ActiveRecord::StatementInvalid) do
                connection.transaction(requires_new: true) do
                  connection.execute(<<~SQL.squish)
                    INSERT INTO #{table} (#{quoted_columns})
                    SELECT #{values} FROM #{table} WHERE id = #{connection.quote(snapshot.id)}
                  SQL
                end
              end

            assert_instance_of cause_class, error.cause
            if position.nil?
              assert_equal "position", error.cause.result.error_field(PG::Result::PG_DIAG_COLUMN_NAME)
            elsif position == -1
              assert_equal "chk_#{short_name}_vm_pos",
                           error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
            end

            assert_equal 0, snapshot.reload.position
            assert_equal 0, snapshot.position_snapshot
          end
        end
      end
    end
  end
end

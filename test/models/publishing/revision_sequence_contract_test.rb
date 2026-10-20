# frozen_string_literal: true

require "test_helper"

module Publishing
  class RevisionSequenceContractTest < ActiveSupport::TestCase
    FAMILIES = [
      [Docs::App::Entry, Docs::App::EntryRevision, "chk_docs_app_rev_seq"],
      [Docs::Com::Entry, Docs::Com::EntryRevision, "chk_docs_com_rev_seq"],
      [Docs::Org::Entry, Docs::Org::EntryRevision, "chk_docs_org_rev_seq"],
      [Help::App::Entry, Help::App::EntryRevision, "chk_help_app_rev_seq"],
      [Help::Com::Entry, Help::Com::EntryRevision, "chk_help_com_rev_seq"],
      [Help::Org::Entry, Help::Org::EntryRevision, "chk_help_org_rev_seq"],
      [Info::App::Entry, Info::App::EntryRevision, "chk_info_app_rev_seq"],
      [Info::Com::Entry, Info::Com::EntryRevision, "chk_info_com_rev_seq"],
      [Info::Org::Entry, Info::Org::EntryRevision, "chk_info_org_rev_seq"],
      [News::App::Entry, News::App::EntryRevision, "chk_news_app_rev_seq"],
      [News::Com::Entry, News::Com::EntryRevision, "chk_news_com_rev_seq"],
      [News::Org::Entry, News::Org::EntryRevision, "chk_news_org_rev_seq"],
    ].freeze

    FAMILIES.each do |entry_class, revision_class, constraint_name|
      test "#{revision_class.name} saves positive sequences at both integer boundaries" do
        entry = entry_class.create!(locale: "ja")

        [1, 2, 2_147_483_646, 2_147_483_647].each do |sequence|
          revision = revision_class.create!(
            entry: entry, locale: "ja", title: "Sequence contract", summary: "Summary",
            body: { "text" => "Body" }, schema_version: 1,
            content_digest: Digest::SHA256.hexdigest("sequence-contract"), sequence: sequence,
          )

          assert_equal sequence, revision.reload.sequence
        end
      end

      test "#{revision_class.name} rejects missing noninteger and out-of-range sequences before persistence" do
        entry = entry_class.create!(locale: "ja")

        [nil, "", false, true, -1, 0, 1.5, "not-a-number", 2_147_483_648].each do |sequence|
          revision = revision_class.new(
            entry: entry, locale: "ja", title: "Sequence contract", summary: "Summary",
            body: { "text" => "Body" }, schema_version: 1,
            content_digest: Digest::SHA256.hexdigest("sequence-contract"), sequence: sequence,
          )

          assert_not revision.valid?, "sequence #{sequence.inspect} must be rejected"
          assert_not_empty revision.errors[:sequence]
          assert_not_empty revision.errors.full_messages
          assert_predicate revision, :new_record?
        end
      end

      test "#{revision_class.name} accepts the existing integer-string assignment contract" do
        entry = entry_class.create!(locale: "ja")
        revision = revision_class.create!(
          entry: entry, locale: "ja", title: "Sequence contract", summary: "Summary",
          body: { "text" => "Body" }, schema_version: 1,
          content_digest: Digest::SHA256.hexdigest("sequence-contract"), sequence: "1",
        )

        assert_equal 1, revision.reload.sequence
      end

      test "#{revision_class.name} database rejects invalid sequences without model validation" do
        entry = entry_class.create!(locale: "ja")
        revision = revision_class.create!(
          entry: entry, locale: "ja", title: "Sequence contract", summary: "Summary",
          body: { "text" => "Body" }, schema_version: 1,
          content_digest: Digest::SHA256.hexdigest("sequence-contract"), sequence: 1,
        )

        revision_class.connection_pool.with_connection do |connection|
          [[nil, PG::NotNullViolation], [-1, PG::CheckViolation], [0, PG::CheckViolation],
           [2_147_483_648, PG::NumericValueOutOfRange],].each do |sequence, cause_class|
            # Direct SQL verifies DB enforcement independently of AR validation and type serialization.
            # The savepoint contains the rejected statement and preserves the original revision.
            error =
              assert_raises(ActiveRecord::StatementInvalid) do
                connection.transaction(requires_new: true) do
                  connection.execute(
                    "UPDATE #{connection.quote_table_name(revision_class.table_name)} " \
                    "SET sequence = #{connection.quote(sequence)} WHERE id = #{connection.quote(revision.id)}",
                  )
                end
              end

            assert_instance_of cause_class, error.cause
            if sequence.nil?
              assert_equal "sequence", error.cause.result.error_field(PG::Result::PG_DIAG_COLUMN_NAME)
            elsif [-1, 0].include?(sequence)
              assert_equal constraint_name, error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
            end

            assert_equal 1, revision.reload.sequence
          end
        end
      end
    end
  end
end

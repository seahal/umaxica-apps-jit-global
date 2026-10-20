# frozen_string_literal: true

require "test_helper"

module Publishing
  class VersionSequenceContractTest < ActiveSupport::TestCase
    FAMILIES = [
      [Docs::App::Entry, Docs::App::EntryRevision, Docs::App::EntryVersion, "chk_docs_app_ver_seq"],
      [Docs::Com::Entry, Docs::Com::EntryRevision, Docs::Com::EntryVersion, "chk_docs_com_ver_seq"],
      [Docs::Org::Entry, Docs::Org::EntryRevision, Docs::Org::EntryVersion, "chk_docs_org_ver_seq"],
      [Help::App::Entry, Help::App::EntryRevision, Help::App::EntryVersion, "chk_help_app_ver_seq"],
      [Help::Com::Entry, Help::Com::EntryRevision, Help::Com::EntryVersion, "chk_help_com_ver_seq"],
      [Help::Org::Entry, Help::Org::EntryRevision, Help::Org::EntryVersion, "chk_help_org_ver_seq"],
      [Info::App::Entry, Info::App::EntryRevision, Info::App::EntryVersion, "chk_info_app_ver_seq"],
      [Info::Com::Entry, Info::Com::EntryRevision, Info::Com::EntryVersion, "chk_info_com_ver_seq"],
      [Info::Org::Entry, Info::Org::EntryRevision, Info::Org::EntryVersion, "chk_info_org_ver_seq"],
      [News::App::Entry, News::App::EntryRevision, News::App::EntryVersion, "chk_news_app_ver_seq"],
      [News::Com::Entry, News::Com::EntryRevision, News::Com::EntryVersion, "chk_news_com_ver_seq"],
      [News::Org::Entry, News::Org::EntryRevision, News::Org::EntryVersion, "chk_news_org_ver_seq"],
    ].freeze

    FAMILIES.each do |entry_class, revision_class, version_class, constraint_name|
      test "#{version_class.name} saves positive sequences at both integer boundaries" do
        entry = entry_class.create!(locale: "ja")

        [1, 2, 2_147_483_646, 2_147_483_647].each do |sequence|
          revision = revision_class.create!(
            entry: entry, locale: "ja", title: "Sequence contract", summary: "Summary",
            body: { "text" => "Body" }, schema_version: 1,
            content_digest: Digest::SHA256.hexdigest("sequence-contract"), sequence: sequence,
          )
          version = version_class.create!(
            entry: entry, entry_revision: revision, locale: "ja", title: revision.title,
            summary: revision.summary, body: revision.body, schema_version: revision.schema_version,
            content_digest: revision.content_digest, sequence: sequence,
          )

          assert_equal sequence, version.reload.sequence
        end
      end

      test "#{version_class.name} rejects missing noninteger and out-of-range sequences on creation" do
        entry = entry_class.create!(locale: "ja")
        revision = revision_class.create!(
          entry: entry, locale: "ja", title: "Sequence contract", summary: "Summary",
          body: { "text" => "Body" }, schema_version: 1,
          content_digest: Digest::SHA256.hexdigest("sequence-contract"), sequence: 1,
        )

        [nil, "", false, true, -1, 0, 1.5, "not-a-number", 2_147_483_648].each do |sequence|
          version = version_class.new(
            entry: entry, entry_revision: revision, locale: "ja", title: revision.title,
            summary: revision.summary, body: revision.body, schema_version: revision.schema_version,
            content_digest: revision.content_digest, sequence: sequence,
          )

          assert_not version.valid?, "sequence #{sequence.inspect} must be rejected"
          assert_not_empty version.errors[:sequence]
          assert_not_empty version.errors.full_messages
          assert_predicate version, :new_record?
        end
      end

      test "#{version_class.name} preserves integer-string assignment and immutable-update refusal" do
        entry = entry_class.create!(locale: "ja")
        revision = revision_class.create!(
          entry: entry, locale: "ja", title: "Sequence contract", summary: "Summary",
          body: { "text" => "Body" }, schema_version: 1,
          content_digest: Digest::SHA256.hexdigest("sequence-contract"), sequence: 1,
        )
        version = version_class.create!(
          entry: entry, entry_revision: revision, locale: "ja", title: revision.title,
          summary: revision.summary, body: revision.body, schema_version: revision.schema_version,
          content_digest: revision.content_digest, sequence: "1",
        )

        assert_equal 1, version.reload.sequence

        [nil, 0, 2_147_483_648].each do |sequence|
          version.sequence = sequence

          assert_raises(ActiveRecord::ReadOnlyRecord) { version.save! }
          assert_equal 1, version.reload.sequence
        end
      end

      test "#{version_class.name} database rejects invalid inserts without model validation" do
        entry = entry_class.create!(locale: "ja")
        revision = revision_class.create!(
          entry: entry, locale: "ja", title: "Sequence contract", summary: "Summary",
          body: { "text" => "Body" }, schema_version: 1,
          content_digest: Digest::SHA256.hexdigest("sequence-contract"), sequence: 1,
        )
        version = version_class.create!(
          entry: entry, entry_revision: revision, locale: "ja", title: revision.title,
          summary: revision.summary, body: revision.body, schema_version: revision.schema_version,
          content_digest: revision.content_digest, sequence: 1,
        )

        version_class.connection_pool.with_connection do |connection|
          table = connection.quote_table_name(version_class.table_name)
          [[nil, PG::NotNullViolation], [-1, PG::CheckViolation], [0, PG::CheckViolation],
           [2_147_483_648, PG::NumericValueOutOfRange],].each do |sequence, cause_class|
            # An INSERT bypasses the immutable-update guard and tests the actual sequence constraints.
            # Copying stored ciphertext keeps encryption outside this independent DB boundary check.
            error =
              assert_raises(ActiveRecord::StatementInvalid) do
                connection.transaction(requires_new: true) do
                  connection.execute(<<~SQL.squish)
                    INSERT INTO #{table}
                      (public_id, entry_id, entry_revision_id, locale, title, summary, body,
                       schema_version, content_digest, sequence, created_at, updated_at)
                    SELECT public_id, entry_id, entry_revision_id, locale, title, summary, body,
                           schema_version, content_digest, #{connection.quote(sequence)}, created_at, updated_at
                    FROM #{table} WHERE id = #{connection.quote(version.id)}
                  SQL
                end
              end

            assert_instance_of cause_class, error.cause
            if sequence.nil?
              assert_equal "sequence", error.cause.result.error_field(PG::Result::PG_DIAG_COLUMN_NAME)
            elsif [-1, 0].include?(sequence)
              assert_equal constraint_name, error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
            end

            assert_equal 1, version.reload.sequence
          end
        end
      end
    end
  end
end

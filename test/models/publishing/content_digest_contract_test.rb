# frozen_string_literal: true

require "test_helper"

module Publishing
  class ContentDigestContractTest < ActiveSupport::TestCase
    FAMILIES = [
      [Docs::App::Entry, Docs::App::EntryRevision, Docs::App::EntryVersion],
      [Docs::Com::Entry, Docs::Com::EntryRevision, Docs::Com::EntryVersion],
      [Docs::Org::Entry, Docs::Org::EntryRevision, Docs::Org::EntryVersion],
      [Help::App::Entry, Help::App::EntryRevision, Help::App::EntryVersion],
      [Help::Com::Entry, Help::Com::EntryRevision, Help::Com::EntryVersion],
      [Help::Org::Entry, Help::Org::EntryRevision, Help::Org::EntryVersion],
      [Info::App::Entry, Info::App::EntryRevision, Info::App::EntryVersion],
      [Info::Com::Entry, Info::Com::EntryRevision, Info::Com::EntryVersion],
      [Info::Org::Entry, Info::Org::EntryRevision, Info::Org::EntryVersion],
      [News::App::Entry, News::App::EntryRevision, News::App::EntryVersion],
      [News::Com::Entry, News::Com::EntryRevision, News::Com::EntryVersion],
      [News::Org::Entry, News::Org::EntryRevision, News::Org::EntryVersion],
    ].freeze

    FAMILIES.each do |entry_class, revision_class, version_class|
      test "#{revision_class.name} and version preserve SHA256 storage and immutable updates" do
        entry = entry_class.create!(locale: "ja")
        digest = PublishingRevisionContentDigest.call(
          schema_version: 1, locale: "ja", title: "Digest contract", summary: nil, body: { "text" => "Body" },
        )
        revision = revision_class.create!(
          entry: entry, locale: "ja", title: "Digest contract", body: { "text" => "Body" },
          schema_version: 1, content_digest: digest, sequence: 1,
        )
        version = PromoteRevisionOperation.new(revision: revision).call

        assert_match(/\A[0-9a-f]{64}\z/, digest)
        assert_equal digest, revision.reload.content_digest
        assert_equal digest, version.reload.content_digest

        [revision, version].each do |record|
          connection = record.class.lease_connection
          table = connection.quote_table_name(record.class.table_name)
          [[nil, PG::NotNullViolation], ["", PG::CheckViolation], ["d" * 63, PG::CheckViolation],
           ["d" * 65, PG::StringDataRightTruncation], ["g" * 64, PG::CheckViolation],
           ["A" * 64, PG::CheckViolation],].each do |value, cause_class|
            # INSERT bypasses immutable UPDATE guards. Invalid digest checks precede duplicate indexes.
            error =
              assert_raises(ActiveRecord::StatementInvalid) do
                connection.transaction(requires_new: true) do
                  columns = %w(public_id entry_id locale title summary body schema_version sequence
                               created_at updated_at)
                  columns << "entry_revision_id" if record == version
                  quoted = columns.map { |column| connection.quote_column_name(column) }.join(", ")
                  connection.execute(<<~SQL.squish)
                    INSERT INTO #{table} (#{quoted}, content_digest)
                    SELECT #{quoted}, #{connection.quote(value)} FROM #{table} WHERE id = #{connection.quote(record.id)}
                  SQL
                end
              end
            assert_instance_of cause_class, error.cause
            assert_equal digest, record.reload.content_digest
          end
        end

        [nil, "", "d" * 63, "g" * 64, "e" * 64].each do |value|
          revision.content_digest = value
          error =
            assert_raises(ActiveRecord::StatementInvalid) do
              revision_class.transaction(requires_new: true) { revision.save! }
            end
          assert_instance_of PG::RestrictViolation, error.cause
          assert_equal digest, revision.reload.content_digest
        end

        [nil, "", "d" * 63, "d" * 65, "g" * 64].each do |value|
          version.content_digest = value
          assert_raises(ActiveRecord::ReadOnlyRecord) { version.save! }
          assert_equal digest, version.reload.content_digest
        end
      end

      test "#{revision_class.name} and version reject malformed digests before insertion" do
        entry = entry_class.create!(locale: "ja")
        revision = revision_class.create!(
          entry: entry, locale: "ja", title: "Digest contract", body: { "text" => "Body" },
          schema_version: 1, content_digest: "d" * 64, sequence: 1,
        )
        [revision_class, version_class].each do |model|
          [nil, "", false, true, 0, "d" * 63, "d" * 65, "g" * 64, "A" * 64, " " * 64].each do |value|
            record = model.new(
              entry: entry, locale: "ja", title: "Digest contract", body: { "text" => "Body" },
              schema_version: 1, content_digest: value, sequence: 2,
            )
            record.entry_revision = revision if model == version_class

            assert_not record.valid?, "#{model.name} must reject #{value.inspect}"
            assert_not_empty record.errors[:content_digest]
            [:en, :ja].each do |locale|
              I18n.with_locale(locale) { assert_not_empty record.errors.full_messages }
            end

            assert_raises(ActiveRecord::RecordInvalid) { record.save! }
            assert_predicate record, :new_record?
          end
        end
      end
    end
  end
end

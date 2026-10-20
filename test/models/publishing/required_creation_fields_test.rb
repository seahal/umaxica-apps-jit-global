# frozen_string_literal: true

require "test_helper"

module Publishing
  class RequiredCreationFieldsTest < ActiveSupport::TestCase
    FAMILIES = [
      [Docs::App::Entry, Docs::App::EntryRevision, Docs::App::EntryVersion,
       Docs::App::EntrySlug, Docs::App::Publication,],
      [Docs::Com::Entry, Docs::Com::EntryRevision, Docs::Com::EntryVersion,
       Docs::Com::EntrySlug, Docs::Com::Publication,],
      [Docs::Org::Entry, Docs::Org::EntryRevision, Docs::Org::EntryVersion,
       Docs::Org::EntrySlug, Docs::Org::Publication,],
      [Help::App::Entry, Help::App::EntryRevision, Help::App::EntryVersion,
       Help::App::EntrySlug, Help::App::Publication,],
      [Help::Com::Entry, Help::Com::EntryRevision, Help::Com::EntryVersion,
       Help::Com::EntrySlug, Help::Com::Publication,],
      [Help::Org::Entry, Help::Org::EntryRevision, Help::Org::EntryVersion,
       Help::Org::EntrySlug, Help::Org::Publication,],
      [Info::App::Entry, Info::App::EntryRevision, Info::App::EntryVersion,
       Info::App::EntrySlug, Info::App::Publication,],
      [Info::Com::Entry, Info::Com::EntryRevision, Info::Com::EntryVersion,
       Info::Com::EntrySlug, Info::Com::Publication,],
      [Info::Org::Entry, Info::Org::EntryRevision, Info::Org::EntryVersion,
       Info::Org::EntrySlug, Info::Org::Publication,],
      [News::App::Entry, News::App::EntryRevision, News::App::EntryVersion,
       News::App::EntrySlug, News::App::Publication,],
      [News::Com::Entry, News::Com::EntryRevision, News::Com::EntryVersion,
       News::Com::EntrySlug, News::Com::Publication,],
      [News::Org::Entry, News::Org::EntryRevision, News::Org::EntryVersion,
       News::Org::EntrySlug, News::Org::Publication,],
    ].freeze

    FAMILIES.each do |entry_class, revision_class, version_class, slug_class, publication_class|
      test "#{entry_class.name} family preserves nonnull locale partitions and SQL null refusal" do
        ["ja", "en", "", " ", false, 0].each_with_index do |locale, index|
          entry = entry_class.create!(locale: locale)
          revision = revision_class.create!(
            entry: entry, locale: locale, title: "Required fields", body: {},
            schema_version: 1, content_digest: "d" * 64, sequence: 1,
          )
          version = PromoteRevisionOperation.new(revision: revision).call
          slug = slug_class.create!(entry: entry, locale: locale, slug: "required-#{index}", state: "reserved")
          expected = entry.reload.locale

          assert_equal({ false => "f", 0 => "0" }.fetch(locale, locale), expected)

          [entry, revision, version, slug].each do |record|
            assert_equal expected, record.reload.locale
            connection = record.class.lease_connection
            table = connection.quote_table_name(record.class.table_name)
            columns = record.attributes.keys - ["id", "locale"]
            quoted = columns.map { |column| connection.quote_column_name(column) }.join(", ")
            error =
              assert_raises(ActiveRecord::NotNullViolation) do
                connection.transaction(requires_new: true) do
                  connection.execute(<<~SQL.squish)
                    INSERT INTO #{table} (#{quoted}, locale)
                    SELECT #{quoted}, NULL FROM #{table} WHERE id = #{connection.quote(record.id)}
                  SQL
                end
              end
            assert_equal "locale", error.cause.result.error_field(PG::Result::PG_DIAG_COLUMN_NAME)
            assert_equal expected, record.reload.locale
          end

          version.locale = nil
          assert_raises(ActiveRecord::ReadOnlyRecord) { version.save! }
          assert_equal expected, version.reload.locale
        end
      end

      test "#{entry_class.name} family rejects nil locale before creation" do
        entry = entry_class.create!(locale: "ja")
        revision = revision_class.create!(
          entry: entry, locale: "ja", title: "Required fields", body: {},
          schema_version: 1, content_digest: "d" * 64, sequence: 1,
        )
        records = [
          entry_class.new,
          revision_class.new(
            entry: entry, title: "Required fields", body: {},
            schema_version: 1, content_digest: "d" * 64, sequence: 2,
          ),
          version_class.new(
            entry: entry, entry_revision: revision, title: "Required fields", body: {},
            schema_version: 1, content_digest: "d" * 64, sequence: 1,
          ),
          slug_class.new(entry: entry, slug: "required", state: "reserved"),
        ]
        records.each do |record|
          assert_not record.valid?, "#{record.class.name} must reject nil locale"
          assert_not_empty record.errors[:locale]
          assert_raises(ActiveRecord::RecordInvalid) { record.save! }
          assert_predicate record, :new_record?
        end
      end

      test "#{publication_class.name} requires a start while preserving nullable end and updates" do
        entry = entry_class.create!(locale: "ja")
        revision = revision_class.create!(
          entry: entry, locale: "ja", title: "Required fields", body: {},
          schema_version: 1, content_digest: "d" * 64, sequence: 1,
        )
        version = PromoteRevisionOperation.new(revision: revision).call
        publication = publication_class.new(entry: entry, entry_version: version)

        assert_not publication.valid?
        assert_not_empty publication.errors[:effective_from]
        assert_raises(ActiveRecord::RecordInvalid) { publication.save! }
        error =
          assert_raises(ActiveRecord::NotNullViolation) do
            publication_class.transaction(requires_new: true) { publication.save!(validate: false) }
          end
        assert_equal "effective_from", error.cause.result.error_field(PG::Result::PG_DIAG_COLUMN_NAME)

        start = Time.utc(2026, 1, 1)
        publication.effective_from = start
        publication.save!

        assert_equal start, publication.reload.effective_from
        assert_nil publication.effective_until
        publication.update!(effective_from: start + 1)

        assert_equal start + 1, publication.reload.effective_from

        projected = publication_class.select(:id, :public_id, :entry_id, :entry_version_id).find(publication.id)
        projected.update!(effective_until: start + 3600)

        assert_equal start + 3600, publication.reload.effective_until
      end
    end
  end
end

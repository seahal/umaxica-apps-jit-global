# frozen_string_literal: true

require "test_helper"

# Committed `db/*_structure.sql` files are generated SQL schema authorities.
# Version-controlled migrations remain the authoring path; the dump must be a
# complete, schema-only replay artifact and must not silently become a mixed
# data export.
class DatabaseReconstructionAuthorityTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  SCHEMA_TABLE_MARKER = /CREATE (?:UNLOGGED )?TABLE public\./

  def structure_dumps
    dumps = Rails.root.glob("db/*_structure.sql")
    dumps << Rails.root.join("db/structure.sql") if Rails.root.join("db/structure.sql").exist?
    dumps.uniq
  end

  test "committed structure dumps contain real table definitions" do
    offenders =
      structure_dumps.filter_map do |path|
        content = path.read
        next if content.match?(SCHEMA_TABLE_MARKER)

        path.relative_path_from(Rails.root).to_s
      end

    assert_empty offenders,
                 "structure.sql dumps must contain table definitions:\n" \
                 "#{offenders.join("\n")}"
  end

  test "structure dumps contain no business data" do
    structure_dumps.each do |path|
      content = path.read

      business_inserts = content.lines.grep(/^INSERT INTO /).reject { |line| line.match?(/schema_migrations/) }
      assert_empty business_inserts, "#{path.basename} contains business data"
    end
  end

  test "publishing reconstructs from migrations rather than publishing_structure.sql" do
    dump = Rails.root.join("db/publishing_structure.sql").read

    assert_match(SCHEMA_TABLE_MARKER, dump)

    migration_bodies =
      (Rails.root.glob("db/publishing_migrate/*.rb") + Rails.root.glob("db/migration_support/publishing_schema.rb"))
        .map(&:read).join("\n")

    assert_match(/_entries/, migration_bodies)
    assert_match(/FAMILIES/, migration_bodies)
    assert_match(/publishing_media_files/, migration_bodies)
    assert_match(/revision_media_usages/, migration_bodies)
    assert_match(/version_media_usages/, migration_bodies)
    assert_no_match(/create_table\(?\s*:publishing_media_usages\b/, migration_bodies)
    assert_no_match(/publishing_editions/, migration_bodies)
    assert PublishingRecord.connection.table_exists?("publishing_docs_app_entries")
    assert PublishingRecord.connection.table_exists?("publishing_docs_app_revision_media_usages")
    assert PublishingRecord.connection.table_exists?("publishing_docs_app_version_media_usages")
    assert_not PublishingRecord.connection.table_exists?("publishing_editions")
    assert_not PublishingRecord.connection.table_exists?("publishing_media_usages")
  end

  test "schema_format remains sql but dump_schema_after_migration is disabled" do
    assert_equal :sql, Rails.application.config.active_record.schema_format
    assert_not Rails.application.config.active_record.dump_schema_after_migration
  end

  test "primary uses the conventional db/structure.sql dump path" do
    assert_predicate Rails.root.join("db/structure.sql"), :exist?
    assert_not Rails.root.join("db/platform_structure.sql").exist?
    assert_match(SCHEMA_TABLE_MARKER, Rails.root.join("db/structure.sql").read)
  end
end

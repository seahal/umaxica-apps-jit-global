# frozen_string_literal: true

require "test_helper"

# Committed `db/*_structure.sql` files are currently session-setting stubs.
# Reconstruction of development and test databases is from version-controlled
# migrations (`db/*_migrate`), not from those dumps. This test pins that
# authority so a stub dump cannot silently become the load path.
class DatabaseReconstructionAuthorityTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  STUB_MARKER = "PostgreSQL database dump complete"

  test "committed structure dumps contain no CREATE TABLE statements" do
    dumps = Rails.root.glob("db/*_structure.sql")

    assert_predicate dumps, :any?

    offenders =
      dumps.filter_map do |path|
        content = path.read
        next unless content.match?(/\bCREATE TABLE\b/i)

        path.relative_path_from(Rails.root).to_s
      end

    assert_empty offenders,
                 "structure.sql dumps currently are not schema authority; " \
                 "CREATE TABLE in a dump means dumps must be regenerated as a separate decision:\n" \
                 "#{offenders.join("\n")}"
  end

  test "structure dumps are header stubs rather than reconstructable schemas" do
    dumps = Rails.root.glob("db/*_structure.sql")

    dumps.each do |path|
      content = path.read

      assert_includes content, STUB_MARKER, "#{path.basename} is not a pg_dump stub"
    end
  end

  test "publishing reconstructs from migrations rather than publishing_structure.sql" do
    dump = Rails.root.join("db/publishing_structure.sql").read

    assert_no_match(/\bCREATE TABLE\b/i, dump)

    migration_bodies =
      (Rails.root.glob("db/publishing_migrate/*.rb") + Rails.root.glob("db/migration_support/publishing_schema.rb"))
        .map(&:read).join("\n")

    assert_match(/publishing_editions/, migration_bodies)
    assert_match(/publishing_entries/, migration_bodies)
    assert_match(/publishing_revision_media_usages/, migration_bodies)
    assert_match(/publishing_version_media_usages/, migration_bodies)
    assert_no_match(/create_table\(?\s*:publishing_media_usages\b/, migration_bodies)
    assert PublishingRecord.connection.table_exists?("publishing_editions")
    assert PublishingRecord.connection.table_exists?("publishing_entries")
    assert PublishingRecord.connection.table_exists?("publishing_revision_media_usages")
    assert PublishingRecord.connection.table_exists?("publishing_version_media_usages")
    assert_not PublishingRecord.connection.table_exists?("publishing_media_usages")
  end

  test "schema_format remains sql but dump_schema_after_migration is disabled" do
    assert_equal :sql, Rails.application.config.active_record.schema_format
    assert_not Rails.application.config.active_record.dump_schema_after_migration
  end
end

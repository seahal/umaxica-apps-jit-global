# frozen_string_literal: true

require "test_helper"

# Hot standbys cannot read UNLOGGED tables. Principal records connect with
# `reading: :*_zenith_replica`, so identity tables used on GET request paths
# must not remain UNLOGGED after the latest migration that changes persistence.
class ReplicaReadableUnloggedTablesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  REPLICA_READABLE_TABLES = %w(client_external_identities).freeze

  test "replica-readable identity tables are not left UNLOGGED" do
    migrations = Rails.root.glob("db/app_principals_migrate/*.rb").sort

    REPLICA_READABLE_TABLES.each do |table|
      last_persistence_change =
        migrations.reverse.find do |path|
          File.read(path).match?(/ALTER TABLE #{Regexp.escape(table)} SET (UN)?LOGGED/)
        end

      assert last_persistence_change,
             "#{table} must have an explicit SET LOGGED migration because AppPrincipalRecord reads replicas"

      contents = File.read(last_persistence_change)

      assert_match(
        /ALTER TABLE #{Regexp.escape(table)} SET LOGGED/,
        contents,
        "#{table} last persistence change must SET LOGGED (#{last_persistence_change.basename})",
      )
      assert_no_match(
        /ALTER TABLE #{Regexp.escape(table)} SET UNLOGGED/,
        contents.split("def down").first,
        "#{table} up path must not SET UNLOGGED (#{last_persistence_change.basename})",
      )
    end
  end
end

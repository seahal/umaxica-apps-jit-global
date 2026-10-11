# frozen_string_literal: true

require "test_helper"

# Configured `migrations_paths` must exist on disk. Rails will otherwise skip
# or mis-own a database's schema without a loud failure. Search and storage are
# reserved empty databases; their directories must still exist.
class DatabaseMigrationPathOwnershipTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "every configured migrations_paths directory exists" do
    missing = []

    ActiveRecord::Base.configurations.configs_for(env_name: "test").each do |config|
      Array(config.migrations_paths).each do |path|
        full = Rails.root.join(path)
        next if full.directory?

        missing << "#{config.name}: #{path}"
      end
    end

    assert_empty missing,
                 "Configured migrations_paths must exist so schemas cannot be skipped:\n#{missing.join("\n")}"
  end

  test "search and storage keep their reserved empty migration directories" do
    %w(db/searches_migrate db/storages_migrate).each do |path|
      assert_predicate Rails.root.join(path), :directory?, "#{path} must exist as the configured owner"
    end
  end

  test "primary owns db/migrate and no database uses db/platform_migrate" do
    configs = ActiveRecord::Base.configurations.configs_for(env_name: "test")
    names = configs.map(&:name)

    assert_includes names, "primary"
    assert_not_includes names, "platform"

    primary = configs.find { |config| config.name == "primary" }

    assert_equal ["db/migrate"], Array(primary.migrations_paths)
    assert_predicate Rails.root.join("db/migrate"), :directory?
    assert_not Rails.root.join("db/platform_migrate").exist?

    offenders =
      configs.filter_map do |config|
        paths = Array(config.migrations_paths)
        next unless paths.any? { |path| path.to_s.include?("platform_migrate") }

        "#{config.name}: #{paths.join(", ")}"
      end

    assert_empty offenders, "no configured database may own db/platform_migrate:\n#{offenders.join("\n")}"
  end
end

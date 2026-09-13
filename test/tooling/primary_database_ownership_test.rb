# frozen_string_literal: true

require "test_helper"

# Pins the restored Rails `primary` connection so the retired `platform`
# database cannot return through configuration or Flipper ownership.
class PrimaryDatabaseOwnershipTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "primary is configured for test and owns db/migrate" do
    config = ActiveRecord::Base.configurations.configs_for(env_name: "test", name: "primary")

    assert config
    # Rails appends a worker suffix (test_primary_db_4) when the suite runs
    # parallelized, so the base name is asserted rather than the literal.
    assert_match(/\Atest_primary_db(_\d+)?\z/, config.database)
    assert_equal ["db/migrate"], Array(config.migrations_paths)
    assert_not config.replica?
  end

  test "the retired platform connection is gone" do
    names = ActiveRecord::Base.configurations.configs_for(env_name: "test", include_hidden: true).map(&:name)

    assert_includes names, "primary"
    assert_not_includes names, "platform"
    assert_not_includes names, "platform_replica"
    assert_not_includes names, "primary_replica"
  end

  test "Flipper Active Record models stay on primary while the suite uses memory" do
    assert_equal "primary", Flipper::Adapters::ActiveRecord::Model.connection_db_config.name

    adapter = Flipper.adapter
    adapter = adapter.adapter while adapter.respond_to?(:adapter)

    assert_kind_of Flipper::Adapters::Memory, adapter
  end

  test "specialized record classes keep their existing databases" do
    assert_equal "publishing", PublishingRecord.connection_db_config.name
    assert_equal "app_setting", AppSettingRecord.connection_db_config.name
    assert_equal "com_setting", ComSettingRecord.connection_db_config.name
    assert_equal "org_setting", OrgSettingRecord.connection_db_config.name
    assert_equal "chronicle", ChronicleRecord.connection_db_config.name
    assert_equal "occurrence", OccurrenceRecord.connection_db_config.name
    assert_equal "avatar", AvatarRecord.connection_db_config.name
  end
end

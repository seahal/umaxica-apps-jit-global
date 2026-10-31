# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class DatabasePasswordConfigTest < ActiveSupport::TestCase
  test "development queue pools can serve every Solid Queue worker thread" do
    configurations = Rails.application.config.database_configuration.fetch("development")
    configuration = configurations.fetch("queue")

    assert_operator configuration.fetch("pool"), :>=, 5, "queue"
  end

  test "no Solid Cache connection remains and Solid Queue defines no read replica" do
    Rails.application.config.database_configuration.each_value do |configurations|
      assert_not configurations.key?("cache")
      assert_not configurations.key?("cache_replica")
      assert_not configurations.key?("queue_replica")
    end
  end

  test "production database connections require the shared Neon connection settings" do
    database_yml = Rails.root.join("config/database.yml").read

    # 17, not 18: the com realm writers that shared the Neon instance (com_zenith,
    # com_signal, op_base_com) were removed with the WU-5 realm retirement; the
    # Solid Cache `cache` connection was removed earlier with Solid Cache itself.
    # The retained com_setting writer still shares the Neon connection.
    assert_equal 17, database_yml.scan('host: <%= production_value.call("NEON_PGHOST") %>').size
    assert_equal 17, database_yml.scan('username: <%= production_value.call("NEON_PGUSER") %>').size
    assert_equal 17, database_yml.scan('password: <%= production_value.call("NEON_PGPASSWORD") %>').size
    assert_equal 15, database_yml.scan('host: <%= production_value.call("NEON_REPLICA_PGHOST") %>').size
    assert_equal 15, database_yml.scan('username: <%= production_value.call("NEON_REPLICA_PGUSER") %>').size
    assert_equal 15, database_yml.scan('password: <%= production_value.call("NEON_REPLICA_PGPASSWORD") %>').size
    assert_equal 15, database_yml.scan('sslmode: <%= production_value.call("NEON_REPLICA_PGSSLMODE") %>').size
    channel_binding_pattern =
      /channel_binding: <%= production_value\.call\("NEON_REPLICA_PGCHANNELBINDING"\) %>/

    assert_equal 15, database_yml.scan(channel_binding_pattern).size
    assert_includes database_yml, 'sslmode: <%= production_value.call("NEON_PGSSLMODE") %>'
    assert_includes database_yml, 'channel_binding: <%= production_value.call("NEON_PGCHANNELBINDING") %>'
    assert_includes database_yml, 'name.end_with?("PGSSLMODE") && value != "verify-full"'
    assert_includes database_yml, "Rails.env.production? ? ENV.fetch(name) : ENV[name]"
  end
end

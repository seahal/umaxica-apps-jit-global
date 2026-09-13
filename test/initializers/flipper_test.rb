# typed: false
# frozen_string_literal: true

require "test_helper"

class FlipperInitializerTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "uses the in-memory adapter so the suite needs no flag storage backend" do
    adapter = Flipper.adapter
    adapter = adapter.adapter while adapter.respond_to?(:adapter)

    assert_kind_of Flipper::Adapters::Memory, adapter
  end

  test "outside test the flag tables resolve to the primary database" do
    assert_equal(
      "primary",
      Flipper::Adapters::ActiveRecord::Model.connection_db_config.name,
    )
  end

  test "the primary database is configured without a replica" do
    replica_names = ActiveRecord::Base.configurations
      .configs_for(env_name: Rails.env, include_hidden: true)
      .select(&:replica?)
      .map(&:name)

    assert_not_includes replica_names, "primary_replica"
  end

  test "the ActiveRecord adapter reads flags inside a reading-role request" do
    # The DatabaseSelector middleware wraps GET requests in this role, so the flag
    # model must have a reading pool even though the primary database has no replica.
    Flipper::Adapters::ActiveRecord::Model.connected_to(role: :reading) do
      assert_nothing_raised do
        Flipper::Adapters::ActiveRecord.new.get(
          Flipper::Feature.new(
            :flipper_reading_role_test_feature,
            Flipper::Adapters::Memory.new,
          ),
        )
      end
    end
  end

  test "the ActiveRecord adapter preloads every flag" do
    # `config.flipper.preload` calls get_all on each request, and the Flipper UI lists
    # features through the same call, so this path must work against the real adapter.
    assert_nothing_raised do
      Flipper::Adapters::ActiveRecord.new.get_all
    end
  end

  test "features default to disabled and follow enable and disable" do
    feature = :flipper_initializer_test_feature

    assert_not Flipper.enabled?(feature)

    Flipper.enable(feature)

    assert Flipper.enabled?(feature)

    Flipper.disable(feature)

    assert_not Flipper.enabled?(feature)
  ensure
    Flipper.remove(feature)
  end
end

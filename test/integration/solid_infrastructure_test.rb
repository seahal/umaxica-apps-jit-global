# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Solid Queue stays; Solid Cache is gone. Both are Rails "Solid" components, so
# the two decisions are easy to conflate -- these assertions keep them apart.
#
# Solid Cache was removed because a database-backed cache is indistinguishable at
# the call site from durable storage, which is what let replay-prevention state
# and one-shot secrets accumulate in `Rails.cache`. The cache now lives in Valkey,
# where eviction is visible and expected. Solid Queue is not a cache: job state is
# durable workflow state and stays in PostgreSQL.
class SolidInfrastructureTest < ActiveSupport::TestCase
  test "solid cache is not loadable" do
    assert_not defined?(SolidCache),
               "SolidCache is loaded; the gem and its configuration were meant to be removed"
  end

  test "no database connection is configured for a solid cache store" do
    offenders =
      # include_hidden: replicas are hidden by default, and `cache_replica` is
      # exactly the connection this asserts is gone.
      ActiveRecord::Base.configurations
        .configs_for(env_name: "test", include_hidden: true)
        .filter_map { |config| config.name if config.name.match?(/\Acache(_replica)?\z/) }

    assert_empty offenders, "cache-only database connections must not exist: #{offenders.join(", ")}"
  end

  test "solid cache configuration and migrations are deleted" do
    %w(config/cache.yml db/caches_migrate db/cache_structure.sql).each do |path|
      assert_not Rails.root.join(path).exist?, "#{path} is a Solid Cache leftover and must not exist"
    end
  end

  test "test environment persists neither cache nor rate limit state" do
    assert_instance_of ActiveSupport::Cache::NullStore, Rails.cache

    store = Rails.configuration.x.rate_limit.fetch(:store)

    assert_instance_of SwappableCacheStore, store
    assert_instance_of ActiveSupport::Cache::NullStore, store.__getobj__
  end

  test "null cache reads are safe inside reading role" do
    ActiveRecord::Base.connected_to(role: :reading, prevent_writes: true) do
      assert_nil Rails.cache.read("reading_role_test_key")
    end
  end

  test "solid queue keeps its own PostgreSQL databases" do
    assert_equal(
      { database: { writing: :queue, reading: :queue_replica } },
      Rails.configuration.solid_queue.connects_to,
    )

    names = ActiveRecord::Base.configurations.configs_for(env_name: "test", include_hidden: true).map(&:name)

    assert_includes names, "queue"
    assert_includes names, "queue_replica"
    assert_predicate Rails.root.join("db/queues_migrate"), :directory?
  end
end

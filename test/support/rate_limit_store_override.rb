# typed: false
# frozen_string_literal: true

# The test environment's rate-limit store is an `ActiveSupport::Cache::NullStore`
# by default (config/environments/test.rb): its counters are keyed by request IP,
# which is 127.0.0.1 for every test, and they survive the per-test transaction
# rollback. A counting store shared by the whole suite therefore makes unrelated
# controller tests fail with 429 depending on suite order and parallel worker
# assignment.
#
# A test whose subject *is* rate limiting needs real counters. It declares
# `counts_rate_limits!`, which swaps a MemoryStore in for the duration of each of
# its tests and restores the null default afterwards, so threshold, window,
# bucket, and 429 behaviour are asserted against a store that actually counts.
module RateLimitStoreOverride
  extend ActiveSupport::Concern

  class_methods do
    def counts_rate_limits!
      setup { start_counting_rate_limits! }
      teardown { stop_counting_rate_limits! }
    end
  end

  def start_counting_rate_limits!
    @previous_rate_limit_store = rate_limit_store_wrapper.swap(ActiveSupport::Cache::MemoryStore.new)
  end

  def stop_counting_rate_limits!
    return if @previous_rate_limit_store.nil?

    rate_limit_store_wrapper.swap(@previous_rate_limit_store)
    @previous_rate_limit_store = nil
  end

  # The wrapper installed by config/environments/test.rb, not the store it
  # currently points at: swapping has to mutate the object controllers captured.
  def rate_limit_store_wrapper
    store = Rails.configuration.x.rate_limit.fetch(:store)
    unless store.is_a?(SwappableCacheStore)
      raise TypeError, "expected config.x.rate_limit.store to be a SwappableCacheStore, got #{store.class}"
    end

    store
  end
end

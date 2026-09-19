# typed: false
# frozen_string_literal: true

module TestSupport
  # Test-only indirection in front of a cache store.
  #
  # The default test policy is that neither `Rails.cache` nor the rate-limit
  # store persists anything (`NullStore`), so ordinary controller and request
  # tests cannot accumulate rate-limit counters and cannot depend on cached
  # state. Tests whose *subject* is rate-limit behavior still have to exercise
  # real counters, which means swapping in a deterministic `MemoryStore`.
  #
  # A plain reassignment of `Rails.configuration.x.rate_limit[:store]` does not
  # reach every consumer: `rate_limit ..., store: rate_limit_store` in a
  # controller class body captures the object once, at class-load time. This
  # wrapper is that captured object, so redirecting it here is visible to eager
  # captures and late lookups alike.
  #
  # Not for use outside the test environment.
  class SwappableCacheStore < SimpleDelegator
    def initialize(default_backend)
      @default_backend = default_backend
      super(default_backend)
    end

    attr_accessor :default_backend

    def backend
      __getobj__
    end

    def backend=(store)
      __setobj__(store || default_backend)
    end

    # Run the block with `store` (default: a fresh MemoryStore) in place, then
    # restore the previous backend. Nesting is safe.
    def with(store = ActiveSupport::Cache::MemoryStore.new)
      previous = backend
      self.backend = store
      yield store
    ensure
      __setobj__(previous)
    end

    def reset!
      __setobj__(default_backend)
    end
  end
end

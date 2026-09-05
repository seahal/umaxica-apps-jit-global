# typed: false
# frozen_string_literal: true

require "delegate"

# Indirection for the test environment's `config.x.rate_limit.store`.
#
# Rails' `rate_limit` DSL captures its `store:` argument inside the
# `before_action` closure it builds while the controller class body runs, so
# reassigning `Rails.configuration.x.rate_limit.store` afterwards never reaches
# a controller that has already loaded. Controllers therefore capture this
# wrapper once and keep it; a test changes what the wrapper points at instead of
# replacing the object controllers hold.
#
# This exists only in the test environment. Development and production assign a
# real `ActiveSupport::Cache::RedisCacheStore` directly, with no indirection.
class SwappableCacheStore < SimpleDelegator
  # Points the wrapper at `store` and returns the previous target so a caller can
  # restore it.
  def swap(store)
    previous = __getobj__
    __setobj__(store)
    previous
  end
end

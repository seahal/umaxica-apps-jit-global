# typed: false
# frozen_string_literal: true

module Umaxica
  module Valkey
    module StoreErrorHandler
      public

      module_function

      # RedisCacheStore swallows a connection error and returns nil. The exception
      # message is omitted on purpose: it can carry the store URL, and these URLs
      # may embed credentials.
      def lambda_for(store)
        lambda do |method:, exception:, returning:|
          Rails.logger.error(
            JitLogEvent.format(
              "valkey.store.unavailable",
              store: store,
              op: method.to_s,
              error_class: exception.class.name,
              degraded_to: returning.inspect,
            ),
          )
        end
      end
    end
  end
end

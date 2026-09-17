# typed: false
# frozen_string_literal: true

require_relative "jit_log_event"

# Keeps a Valkey outage in the performance dashboard from becoming an outage of the application it
# observes.
#
# `RailsPerformance::Rails::Middleware` records a request by calling `RequestRecord#save` *after*
# the downstream app has produced its response, and `save` reaches Valkey through
# `RailsPerformance::Utils.save_to_redis`, which calls `redis.set` with nothing around it. When
# Valkey is unreachable that raises `Redis::CannotConnectError` inside the middleware, and a
# request the application already answered correctly turns into a 500. An observability dependency
# must not be able to do that.
#
# `save_to_redis` is the single write chokepoint -- every record type the gem persists goes through
# it -- so wrapping it once covers request records, trace records, and anything a later version
# adds.
#
# Reads are deliberately not wrapped. `fetch_from_redis` only runs while somebody is looking at the
# dashboard, and a dashboard that renders an empty page during an outage is worse than one that
# fails visibly: the empty page reads as "no traffic".
#
# The failure is not swallowed. It is logged through `JitLogEvent.format`, in the same shape and
# under the same event name the cache and rate-limit error handlers in config/environments use, so
# a degraded store is greppable next to every other degraded store. The exception message is
# omitted on purpose -- it can carry the store URL, and these URLs may embed credentials -- and the
# class name is kept, which is what distinguishes a connection refusal from a timeout or an OOM.
module RailsPerformanceStoreResilience
  module UtilsPatch
    def save_to_redis(...)
      super
    rescue Redis::BaseError => e
      Rails.logger.error(
        JitLogEvent.format(
          "valkey.store.unavailable",
          store: "rails_performance",
          op: "save_to_redis",
          error_class: e.class.name,
          degraded_to: "record dropped",
        ),
      )
      nil
    end
  end
end

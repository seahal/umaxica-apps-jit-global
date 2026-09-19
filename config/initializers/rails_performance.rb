# typed: false
# frozen_string_literal: true

# `rails_performance` is a `group :development` gem, required from config/application.rb (it has to
# be loaded before the routing paths are collected). This file only configures it, so everything
# here stays behind the same development guard.
if Rails.env.development?
  require_relative "../../lib/diagnostic_surface_credentials"
  require_relative "../../lib/rails_performance_record_sanitizer"
  require_relative "../../lib/rails_performance_store_resilience"
  require_relative "../../lib/umaxica/valkey/error"
  require_relative "../../lib/umaxica/valkey/configuration_error"
  require_relative "../../lib/umaxica/valkey/settings"

  # Independently switchable, as the three diagnostic surfaces must be. Disabled, the gem records
  # nothing, opens no Valkey connection, and its middleware returns immediately; the route stays
  # drawn but the dashboard has no data to show.
  RailsPerformance.enabled = ENV.fetch("RAILS_PERFORMANCE_ENABLED", "true") == "true"

  if RailsPerformance.enabled
    # Fails the boot when diagnostic Valkey settings are missing. The gem's default is
    # `Redis.new` with no arguments -- redis://127.0.0.1:6379/0, which is the application
    # cache -- so without this a missing host would not fail, it would quietly write
    # request records into Rails.cache.
    performance_valkey = Umaxica::Valkey::Settings.current.performance
    RailsPerformance.redis = Redis.new(url: performance_valkey.url, driver: :hiredis)

    # Retention. RailsPerformance::Utils.save_to_redis writes every record with
    # `redis.set(key, value, ex: RailsPerformance.duration.to_i)`, so this is a real per-key TTL
    # rather than a trim the dashboard applies at read time: each request record expires four hours
    # after it is written and the keyspace cannot grow without bound. The cost model is one Valkey
    # key per request plus one trace key, which is why this responsibility has its own logical
    # database -- the gem reads with `redis.keys("performance|*")`, an O(keyspace) blocking scan.
    RailsPerformance.duration = 4.hours
    RailsPerformance.slow_requests_time_window = 4.hours

    # HTTP requests only, which is the stated initial scope. Rake task timing would record task
    # names and arguments from processes this dashboard is not meant to observe; Sidekiq, Delayed
    # Job, and Grape are not used by this application. Solid Queue job measurement is deliberately
    # out of scope and is not assumed to work by default.
    RailsPerformance.include_rake_tasks = false
    RailsPerformance.include_custom_events = false

    # No custom payload. The gem's documented example for this hook reads the signed-in user's
    # email address out of the request env, which is precisely the kind of personal data that must
    # not accumulate in a diagnostic store.
    RailsPerformance.custom_data_proc = nil

    # Do not measure the diagnostic hosts themselves. `mount_at` is inert here -- the self-mount it
    # names is suppressed in config/application.rb -- but the gem's middleware also uses it to
    # decide what to skip, so it must still name a path that exists.
    RailsPerformance.mount_at = "/"

    # The gem's own Basic Auth is left off: `http_basic_authentication_enabled` defaults to false
    # with the literal credentials "rails_performance"/"password12" already assigned, so relying on
    # it would mean trusting a gem default to have been overridden. The guard below fails closed
    # when the credentials are unset instead.
    RailsPerformance.http_basic_authentication_enabled = false

    # `verify_access_proc` defaults to `proc { true }`. It is not the control that protects this
    # surface -- Rack::Auth::Basic below is -- but leaving a default-open hook in place next to a
    # dashboard is how the next reader concludes the dashboard is protected by something it is not.
    RailsPerformance.verify_access_proc = proc { |_controller| true }

    # Strip secrets out of every record on the way into Valkey. config.filter_parameters does not
    # cover the Referer or the exception message, and only partially covers the path; see
    # lib/rails_performance_record_sanitizer.rb for the field-by-field reasoning.
    RailsPerformance::Models::RequestRecord.prepend(
      RailsPerformanceRecordSanitizer::RequestRecordPatch,
    )

    # Keep a Valkey outage inside the dashboard. The gem records a request *after* the application
    # has already produced its response, so an unhandled Redis::CannotConnectError there turns a
    # correctly answered request into a 500. `save_to_redis` is a singleton method and the single
    # write chokepoint for every record type. The failure is logged, not swallowed; see
    # lib/rails_performance_store_resilience.rb.
    RailsPerformance::Utils.singleton_class.prepend(
      RailsPerformanceStoreResilience::UtilsPatch,
    )

    # Cloudflare Access fronts performance.umaxica.dev, but the mounted engine must not depend on
    # the edge alone: RailsPerformance::Engine subclasses nothing of this application, so
    # enforce_access_policy! and surface isolation never run for it, and any request that reached
    # the origin directly would get unauthenticated read access to every observed request path,
    # controller, status, and crash backtrace.
    #
    # The check lives in the engine's own middleware stack rather than wrapping the engine at the
    # mount point (config/routes/performance.rb explains why). Fails closed: when the credentials
    # are not configured the block returns false and every request is answered with 401, rather
    # than defaulting to open access.
    RailsPerformance::Engine.middleware.use(
      Rack::Auth::Basic,
      "Rails Performance",
      &DiagnosticSurfaceCredentials.guard(
        user_key: :RAILS_PERFORMANCE_USERNAME,
        password_key: :RAILS_PERFORMANCE_PASSWORD,
      )
    )
  end
end

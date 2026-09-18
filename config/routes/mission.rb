# typed: false
# frozen_string_literal: true

# Mission owns the Solid Queue job-monitoring surface (Mission Control Jobs) for this
# application's own Global job queue. Public canonical host: mission.umaxica.dev.
# Development host: mission.core.dev.localhost.
constraints host: [ENV["PUBLIC_MISSION_URL"], ENV["PRIVATE_MISSION_URL"], "mission.core.dev.localhost"].compact do
  # Cloudflare Access fronts this host, but the mounted engine's controllers are not this
  # application's own: MissionControl::Jobs::ApplicationController inherits ::ApplicationController
  # directly and never runs FqdnAvailabilityGate or RateLimit. HTTP Basic Auth
  # (config/initializers/mission_control_jobs.rb) is what stands between an unauthenticated caller
  # and full read/write control over the job queue if this host is reached directly. Fails closed:
  # MissionControl::Jobs answers every request with 401 when its credentials are not configured,
  # rather than defaulting to open access.
  # `mission_control-jobs` is a development/production-only gem (Gemfile); it is not in the test
  # group's load path, so the engine constant does not exist while running the test suite.
  mount MissionControl::Jobs::Engine, at: "/" if defined?(MissionControl::Jobs::Engine)
end

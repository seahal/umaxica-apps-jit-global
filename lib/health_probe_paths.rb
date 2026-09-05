# frozen_string_literal: true

# The exact request paths that are exempt from Host Authorization.
#
# Host Authorization is this application's DNS rebinding defence: it compares the `Host` header
# against `config.hosts` and refuses anything else. A browser cannot forge `Host` from JavaScript, so
# an attacker who rebinds a hostname they control to an internal address still arrives carrying their
# own name and is rejected.
#
# Anything listed here gives that defence up for that path. A rebinding attacker can reach these
# paths and read the response. That is accepted for the health probes specifically, because their
# public JSON is deliberately limited to `status`, the probe name, `{ "database": "ok" }`, and a
# surface label and revision -- never exception classes, messages, credentials, or topology (see
# `docs/reference/health-endpoints.md`). It is not acceptable for anything else.
#
# Why an exemption is needed at all: orchestrator, container-engine and load-balancer probes reach
# the origin internally and address it by container name or pod IP. Those names are deliberately
# absent from `config.hosts` -- adding them would let anyone in under that name -- so without this
# list a probe is answered by Host Authorization instead of by the probe endpoint.
#
# Why exact matches and not `start_with?("/health/")`: a prefix test hands the exemption to every
# future path under `/health/`, silently and at the moment it is added. A new probe that returned
# richer diagnostics would lose DNS rebinding protection without anyone deciding that it should. The
# list below is the four text probe endpoints `config/routes/*.rb` actually mounts today; a fifth
# must be added here on purpose, with the same consideration of what it exposes.
#
# The machine-JSON endpoints `/api/v0/health.json` and `/api/v0/revision.json` are deliberately
# NOT listed: they are edge-blocked JSON API routes reached through the tunnel with a real `Host`
# that is already in `config.hosts`, not orchestrator probes addressing the origin by container
# name, so they need no Host Authorization exemption.
# `HealthProbePathsTest` pins both the exact-match behaviour and the current path set.
module HealthProbePaths
  PATHS = [
    "/health",
    "/health/liveness",
    "/health/readiness",
    "/health/startup",
  ].freeze

  module_function

  # @param request [ActionDispatch::Request]
  def probe?(request) = PATHS.include?(request.path)
end

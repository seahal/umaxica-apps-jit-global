# typed: false
# frozen_string_literal: true

# Shared rendering for the health endpoints. Every health response derives from a
# `Health::CheckResult` (or the three of them) through this concern, so no controller hand-rolls
# a health body or duplicates the status mapping.
#
# Three representations:
#
# - `render_probe`         -> text/plain. `"ok\n"` and HTTP 200 when the probe passes; a short
#   `"unavailable\n"` and HTTP 503 when it does not. `GET /health/{startup,liveness,readiness}`.
# - `render_snapshot`      -> text/plain aggregate. Four lines, always in the order
#   `status`, `startup`, `liveness`, `readiness`. `GET /health`.
# - `render_health_status` -> application/json machine aggregate for `/api/v0/health.json`. The
#   `pass|warn|fail` vocabulary and the HTTP status decision live in `HealthStatusSerializer`.
#
# None of these negotiate on `Accept`: `render plain:` and `render json:` set the media type
# outright. The machine JSON endpoint additionally refuses a non-JSON `Accept` with 406, enforced
# by `MachineJsonNegotiation` in the controller.
module HealthCheckRendering
  extend ActiveSupport::Concern

  included do
    before_action :disable_health_response_cache
  end

  # Probe endpoints (liveness/readiness/startup): text/plain, no redirect, no layout, no
  # negotiation. `result.ok?` already folds the probe-specific rule that liveness tolerates a
  # "starting" process while startup and readiness do not.
  def render_probe(result)
    if result.ok?
      render plain: "ok\n"
    else
      render plain: "unavailable\n", status: :service_unavailable
    end
  end

  # Aggregate endpoint (`GET /health`): text/plain block. `status` is the overall verdict; the
  # other three lines are the individual probe verdicts, taken from the same nested results the
  # snapshot check already aggregated.
  def render_snapshot(result)
    snapshot = result.as_public_json(namespace: health_namespace)
    dependencies = snapshot.fetch(:dependencies)

    body = [
      "status: #{snapshot.fetch(:status)}",
      "startup: #{probe_line(dependencies, "startup")}",
      "liveness: #{probe_line(dependencies, "liveness")}",
      "readiness: #{probe_line(dependencies, "readiness")}",
    ].join("\n") + "\n"

    render plain: body, status: result.http_status
  end

  # Machine aggregate (`/api/v0/health.json`): application/json. The three probe results are
  # mapped and aggregated by the serializer, which also owns the HTTP status.
  def render_health_status(liveness:, readiness:, startup:)
    serialized = HealthStatusSerializer.call(liveness: liveness, readiness: readiness, startup: startup)

    render json: serialized.body, status: serialized.http_status
  end

  private

  # Fails loudly if the snapshot check did not produce the expected nested probe
  # (`generic/no-silent-fallback.mdc`): a blank line would misreport health.
  def probe_line(dependencies, name)
    entry =
      dependencies.fetch(name) do
        raise Health::MalformedSnapshotError, "health snapshot is missing the #{name.inspect} probe result"
      end

    entry.fetch(:status)
  end

  # A health response is a verdict about this instance at this instant, so a stored copy is a
  # stale verdict: a cached 200 keeps an orchestrator sending traffic to an instance that has
  # since failed its readiness probe, and a cached 503 keeps traffic away from one that has
  # recovered. Rails otherwise defaults these to `max-age=0, private, must-revalidate`, which
  # permits storage. Applied as a callback so it also covers a 406 refused by the machine JSON
  # endpoint.
  def disable_health_response_cache
    response.set_header("Cache-Control", "no-store")
  end

  # The routed surface that answered, as "<realm>/<surface>". `controller_path` is the path Rails
  # resolved for the request (for example "core/app/health/livenesses"), so this follows whichever
  # `constraints(host:)` block matched instead of restating it.
  def health_namespace
    segments = controller_path.split("/")

    if segments.length < 2
      raise Health::MissingNamespaceError,
            "#{self.class.name} is not nested under a <realm>/<surface> namespace, so the " \
            "answering surface cannot be named in its health response"
    end

    segments.first(2).join("/")
  end

  def health_profile
    unless self.class.const_defined?(:HEALTH_PROFILE, false)
      raise Health::MissingProfileError, "#{self.class.name} must define its own HEALTH_PROFILE"
    end

    self.class.const_get(:HEALTH_PROFILE, false)
  end
end

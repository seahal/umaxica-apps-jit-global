# typed: false
# frozen_string_literal: true

# Content negotiation for the machine-only JSON endpoints (`/api/v0/health.json`,
# `/api/v0/revision.json`).
#
# These endpoints answer `application/json` and nothing else. They never fall back to HTML or
# text/plain: a request whose `Accept` excludes JSON is answered `406` with an empty body rather
# than a representation the caller did not ask for. A request with no `Accept`, or one sending
# `*/*`, accepts anything (RFC 9110 12.5.1) and is served normally. `application/*` is served too,
# because Rails expands a trailing-star range into the concrete registered types and
# `application/json` is one of them.
#
# They are unauthenticated, edge-blocked probes reached through the tunnel with a real `Host`, so
# they follow the internal probe contract (`docs/reference/health-endpoints.md`) rather than the
# `/api/v0` Problem Details error format; hence a bare `head :not_acceptable`.
module MachineJsonNegotiation
  extend ActiveSupport::Concern

  # Matched against `request.accepts`, which holds the types Rails parsed out of the header.
  # `*/*` survives parsing as itself, so it is listed. A range such as `application/*` does not:
  # `Mime::Type.parse` expands it into the twelve concrete registered types, `application/json`
  # among them, so it is accepted by the first entry and listing the range here would be dead.
  ACCEPTABLE = %w(application/json */*).freeze

  included do
    # A machine health or revision answer is a point-in-time value; a stored copy is a stale one.
    # Set on every response, including a 406, so nothing caches the refusal either.
    before_action { response.set_header("Cache-Control", "no-store") }
  end

  private

  def refuse_unless_machine_json_acceptable
    head :not_acceptable unless machine_json_acceptable?
  end

  def machine_json_acceptable?
    accepted = request.accepts.filter_map { |mime| mime.to_s.presence }

    # Rails yields an empty list when the header is absent; RFC 9110 12.5.1 treats that as
    # accepting anything.
    return true if accepted.empty?

    accepted.any? { |value| ACCEPTABLE.include?(value) }
  end
end

# typed: false
# frozen_string_literal: true

# Shapes the machine-readable health aggregate for `GET /api/v0/health.json`.
#
# It maps the internal Health status vocabulary (`:ok`, `:degraded_acceptable`, `:starting`,
# `:unready` -- `Health::STATUSES`) onto the wire vocabulary this endpoint publishes
# (`"pass"` | `"warn"` | `"fail"`), aggregates the three probe verdicts, and owns the HTTP status
# decision (`fail` -> 503, otherwise 200).
#
# Startup, liveness, and readiness are mapped independently, so a readiness failure never changes
# the liveness entry -- liveness is dependency-free and a downstream outage only makes the
# instance unready.
#
# Nothing internal crosses this boundary: no hostname, dependency name, exception, path, or
# environment value -- only the two enum-bounded strings `status` and `checks.*.status`.
class HealthStatusSerializer
  Result = Data.define(:body, :http_status)

  # Emission order matches docs/reference/health-endpoints.md: startup, liveness, readiness.
  CHECK_ORDER = %i(startup liveness readiness).freeze

  def self.call(liveness:, readiness:, startup:)
    new(liveness: liveness, readiness: readiness, startup: startup).call
  end

  def initialize(liveness:, readiness:, startup:)
    @results = { startup: startup, liveness: liveness, readiness: readiness }
  end

  def call
    mapped = CHECK_ORDER.index_with { |name| vocab_for(@results.fetch(name)) }
    overall = aggregate(mapped.values)

    Result.new(
      body: {
        status: overall,
        checks: mapped.transform_values { |status| { status: status } },
      },
      http_status: (overall == "fail") ? 503 : 200,
    )
  end

  private

  # Exhaustive over `Health::STATUSES`; an unmapped status raises rather than defaulting
  # (`generic/no-silent-fallback.mdc`).
  def vocab_for(result)
    case result.status
    when :ok
      "pass"
    when :degraded_acceptable
      "warn"
    when :starting
      # Liveness tolerates a starting process (HTTP 200); startup and readiness do not (HTTP 503).
      result.ok? ? "warn" : "fail"
    when :unready
      "fail"
    else
      raise ArgumentError, "unmapped health status: #{result.status.inspect}"
    end
  end

  def aggregate(statuses)
    return "fail" if statuses.include?("fail")
    return "warn" if statuses.include?("warn")

    "pass"
  end
end

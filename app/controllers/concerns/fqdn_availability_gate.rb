# typed: false
# frozen_string_literal: true

# Per-FQDN availability kill switch.
#
# This is the first application-layer callback on every gated surface. It runs ahead of the
# `rate_limit` declaration, ahead of context and preference hydration, and ahead of authentication,
# so switching an FQDN off stops the request before it can consume a rate-limit budget, touch a
# session, or reach a controller action.
#
# On Global and Publishing policy roots, `DefaultNoStore#apply_default_no_store` runs one step
# earlier. It only marks the response `no-store` (no request input, budget, or state), which is what
# lets the 503 rendered here carry that directive. See
# adr/global-and-publishing-default-no-store-policy.md.
#
#   request
#     -> default no-store          (Global / Publishing policy roots only)
#     -> FQDN availability gate    (here)
#     -> rate limit
#     -> current context / preference
#     -> authentication / authorization
#     -> controller action
#
# Fail-closed by construction:
#
#   * The feature name comes from `FqdnAvailabilityRegistry`, an explicit allowlist. A `Host` header
#     that is not served resolves to no slot and is refused; no feature name is ever derived from
#     request input.
#   * The flags carry `:availability` polarity, so a feature that was never written reads as off.
#     Losing the flag store closes the service rather than opening it.
#   * A flag store that raises is treated as unavailable, not as permission to continue.
#
# Health endpoints are exempt. `adr/internal-health-endpoint-edge-isolation.md` defines `/health` and
# everything beneath it as internal orchestrator and container probes rather than a user-facing
# contract; an operator switching a public FQDN off must not also blind the probes that report why.
module FqdnAvailabilityGate
  extend ActiveSupport::Concern

  HEALTH_PATH_PREFIX = "/health"

  # Flipper's ActiveRecord adapter reaches the `platform` database. Every failure it can raise is an
  # ActiveRecordError (including the connection errors, which subclass it). Naming the boundary keeps
  # this from swallowing unrelated bugs the way `rescue StandardError` would.
  FLAG_STORE_ERRORS = [ActiveRecord::ActiveRecordError].freeze

  included do
    prepend_before_action(:enforce_fqdn_availability!)
  end

  class_methods do
    # A `prepend_before_action` declared in a subclass lands ahead of one declared in its parent, so
    # any controller that prepends its own callback would otherwise push the availability switch
    # into second place. Calling this after such a declaration restores the switch to the front.
    # `Security::Invariants::FqdnAvailabilityGateOrderInvariantTest` fails when a controller forgets.
    def ensure_fqdn_gate_first!
      prepend_before_action(:enforce_fqdn_availability!)
    end
  end

  private

  def enforce_fqdn_availability!
    return if fqdn_availability_exempt_path?

    slot = FqdnAvailabilityRegistry.slot_for(request.host)

    return render_fqdn_unavailable(reason: "unknown_fqdn") if slot.nil?
    return if fqdn_slot_available?(slot)

    render_fqdn_unavailable(reason: "fqdn_unavailable", slot: slot)
  end

  def fqdn_availability_exempt_path?
    path = request.path.to_s

    path == HEALTH_PATH_PREFIX || path.start_with?("#{HEALTH_PATH_PREFIX}/")
  end

  def fqdn_slot_available?(slot)
    FeatureFlags.enabled?(FqdnAvailabilityRegistry.flag_name_for(slot))
  rescue *FLAG_STORE_ERRORS => e
    Rails.logger.error(
      "fqdn availability flag store unavailable; failing closed " \
      "(slot: #{slot}, error: #{e.class})",
    )
    false
  end

  def render_fqdn_unavailable(reason:, slot: nil)
    response.headers["Retry-After"] = fqdn_unavailable_retry_after.to_s

    payload = {
      error: reason,
      surface: slot&.to_s,
      message: I18n.t("errors.fqdn_availability.unavailable"),
    }.compact

    respond_to do |format|
      format.json { render(json: payload, status: :service_unavailable) }
      format.any do
        render(
          plain: payload.fetch(:message),
          content_type: "text/plain",
          status: :service_unavailable,
        )
      end
    end
  end

  def fqdn_unavailable_retry_after = 60
end

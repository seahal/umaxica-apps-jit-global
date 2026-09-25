# typed: false
# frozen_string_literal: true

# Enforces the "current actor is in withdrawal lifecycle" gate: actors
# in `closing` / `suspended` / `terminated` / `deactivated` states are
# restricted to the withdrawal flow itself. Anything else gets a redirect (HTML) or a 403 with
# `WITHDRAWAL_REQUIRED` (JSON / non-HTML).
#
# Lives as its own concern (extracted from the very large
# `AuthenticationBase`) so the rule is reviewable in isolation and
# to make it obvious where the allowlist gets edited.
module AuthenticationWithdrawalGate
  extend ActiveSupport::Concern

  private

  def enforce_withdrawal_gate!
    return unless logged_in?
    return unless current_resource
    return unless withdrawal_restricted_resource?(current_resource)

    # Allowlist: withdrawal flow
    return if withdrawal_gate_allowlisted?

    # API/JSON: return 403 Forbidden
    if request.format.json? || !request.format.html?
      render json: { error: "WITHDRAWAL_REQUIRED" }, status: :forbidden
      return
    end

    # HTML: redirect to the withdrawal lifecycle surface
    safe_redirect_to(withdrawal_gate_redirect_path, fallback: acme_withdrawal_gate_redirect_path, status: :found)
  end

  def withdrawal_gate_allowlisted?
    return true if withdrawal_controller_allowlisted?

    # Allowlist: health/assets (rarely needed but safe)
    return true if controller_path == "rails/health"

    false
  end

  def withdrawal_controller_allowlisted?
    %w(
      base/app/identity/withdrawals
      base/com/identity/withdrawals
    ).include?(controller_path) && %w(show new edit update create destroy).include?(action_name)
  end

  def withdrawal_restricted_resource?(resource)
    return true if resource.respond_to?(:closing?) && resource.closing?
    return true if resource.respond_to?(:suspended?) && resource.suspended?
    return true if resource.respond_to?(:terminated?) && resource.terminated?

    resource.respond_to?(:deactivated?) && resource.deactivated?
  end

  def withdrawal_gate_redirect_path
    ri = params[AuthIoKeys::Params::RI]

    case withdrawal_gate_surface_family
    when "app" then edit_base_app_identity_withdrawal_path(ri: ri)
    when "com" then edit_base_com_identity_withdrawal_path(ri: ri)
    when "org" then base_org_identity_withdrawal_path(ri: ri)
    else
      raise ArgumentError, "no withdrawal redirect path configured for controller_path=#{controller_path}"
    end
  end

  # Derives the app/com/org family from the surface/family/... controller_path shape shared by
  # every surface (auth, base, core, warp). A rescued default here would silently cross surfaces
  # (e.g. redirect an org request to the app withdrawal page), so unknown families raise instead.
  def withdrawal_gate_surface_family
    controller_path.split("/")[1]
  end

  def acme_withdrawal_gate_redirect_path
    edit_base_app_identity_withdrawal_path(ri: params[AuthIoKeys::Params::RI])
  end
end

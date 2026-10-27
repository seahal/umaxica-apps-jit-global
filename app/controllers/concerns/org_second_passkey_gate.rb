# typed: false
# frozen_string_literal: true

# D-132 (2026-10-23): every Operator is ADVANCED, which requires two active Passkeys. An Operator
# who signed in with only one may register a second Passkey and sign out; every other ORG Base
# action is refused until the second Passkey exists. Protocol, sign-in and Step-Up paths stay
# reachable because the registration needs them.
module OrgSecondPasskeyGate
  extend ActiveSupport::Concern

  ALLOWED_CONTROLLER_PREFIXES = %w(
    base/org/identity/passkeys base/org/verification base/org/verifications base/org/sign_outs
    visa/org/sign/ visa/org/oauth/ visa/org/oidc/ visa/org/well_known
    visa/org/edge/ visa/org/health visa/org/ceremony_binding_confirmations
  ).freeze
  MINIMUM_ACTIVE_PASSKEYS = 2

  private

  def enforce_second_passkey_gate!
    operator = current_resource
    return unless operator.is_a?(::Operator) && operator.security_mode_advanced?
    return if second_passkey_gate_allowlisted?
    return if active_operator_passkey_count(operator) >= MINIMUM_ACTIVE_PASSKEYS

    if request.format.json? || !request.format.html?
      render json: { error: "SECOND_PASSKEY_REQUIRED" }, status: :forbidden
    else
      redirect_to(
        Rails.application.routes.url_helpers.new_base_org_identity_passkey_path(ri: params[AuthIoKeys::Params::RI]),
        status: :see_other,
      )
    end
  end

  def second_passkey_gate_allowlisted?
    ALLOWED_CONTROLLER_PREFIXES.any? { |prefix| controller_path == prefix || controller_path.start_with?(prefix) }
  end

  def active_operator_passkey_count(operator)
    OperatorPasskey.where(staff_id: operator.id, status_id: OperatorPasskeyStatus::ACTIVE).count
  end
end

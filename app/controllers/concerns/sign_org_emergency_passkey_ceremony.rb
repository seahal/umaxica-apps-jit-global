# typed: false
# frozen_string_literal: true

# The org Emergency Access (Restricted Mode) passkey ceremony.
#
# Emergency Access is a different authentication policy, not a different
# cryptographic implementation. Every security-sensitive mechanic -- option
# construction, challenge issue/persistence/expiry/one-shot consumption,
# actor and credential-ownership binding, RP ID and origin validation, UV,
# signature and sign-count verification, timestamp updates, CSRF, Turnstile,
# rate limits, timing defences, normalised errors, and risk emission -- comes
# from PasskeySignInFlow and Webauthn::AssertionVerifier, exactly as the normal
# ceremony does. Duplicating any of it here would mean a future fix could land
# in one path and not the other.
#
# What differs is narrow and lives below: the ceremony purpose, the eligibility
# decision, and the authentication context the resulting session carries.
module SignOrgEmergencyPasskeyCeremony
  extend ActiveSupport::Concern

  include ::PasskeySignInFlow
  include ::AuthenticationModeSwitchGuard
  include ::SessionLimitGate

  included do
    declare_authentication_mode! :guest

    # Named per including controller so the options and verification endpoints
    # keep their own budgets, as they did when each declared its own limits.
    # A shared counter would let one endpoint's retries exhaust the other's.
    endpoint = name.demodulize.underscore.delete_suffix("_controller")

    before_action :start_minimum_response_budget
    after_action :enforce_minimum_response_budget

    # Emergency Access is reachable without Entra, so it is the org sign-in
    # entry with the least prior friction. It carries the same per-IP budget as
    # the normal passkey ceremony rather than a looser one.
    rate_limit(
      to: 5,
      within: 1.minute,
      by: -> { request.remote_ip },
      scope: "auth_org_sign_in_emergency",
      name: "emergency_passkey_#{endpoint}_ip_burst",
      store: rate_limit_store,
      with: -> { render_rate_limited(retry_after: 60) },
    )
    rate_limit(
      to: 20,
      within: 15.minutes,
      by: -> { request.remote_ip },
      scope: "auth_org_sign_in_emergency",
      name: "emergency_passkey_#{endpoint}_ip_sustained",
      store: rate_limit_store,
      with: -> { render_rate_limited(retry_after: 900) },
    )
  end

  private

  # A separate purpose namespace. A challenge issued here is rejected by the
  # normal sign-in and step-up verifiers, and theirs are rejected here
  # (Webauthn::ChallengeStore#consume_with_actor!).
  def passkey_ceremony_purpose
    :emergency_sign_in
  end

  def before_passkey_options_request!
    verify_turnstile_stealth!
  end

  def passkey_identifier_required_error_key
    "errors.webauthn.identifier_required"
  end

  def normalized_passkey_identifier
    Operator.normalize_public_id(params[:identifier])
  end

  def valid_passkey_identifier?(identifier)
    Operator::PUBLIC_ID_FORMAT.match?(identifier)
  end

  def passkey_identifier_invalid_error_key
    "errors.webauthn.identifier_invalid"
  end

  # Ineligibility is indistinguishable from "no such Operator" on the wire: the
  # flow issues the same padded, anonymised allowCredentials set either way, so
  # this must not become an enumeration oracle for who holds Emergency Access.
  def find_active_passkey_actor(identifier)
    normalized_identifier = Operator.normalize_public_id(identifier)
    return if normalized_identifier.blank?

    operator = Operator.find_by(public_id: normalized_identifier)
    operator if OrgEmergencyAccessPolicy.eligible?(operator)
  end

  # Re-checked at verification because eligibility can be withdrawn between the
  # two requests of the ceremony, and because the credential is only now known.
  def allow_passkey_sign_in?(passkey)
    return true if OrgEmergencyAccessPolicy.eligible?(passkey.staff)

    emit_passkey_auth_failed(reason: "emergency_access_ineligible")
    render_error("errors.webauthn.verification_failed", :unauthorized)
    false
  end

  def perform_passkey_sign_in(passkey)
    establish_signed_in_session!(
      passkey.staff,
      pt: retrieve_pt_for_checkpoint,
      ri: current_region_identifier,
      auth_method: "passkey",
      authentication_context: AuthenticationContextValue::EMERGENCY_KEY,
    )
  end

  def handle_domain_specific_login_status(result)
    case result[:status]
    when :session_limit_hard_reject
      render_session_limit_hard_reject(message: result[:message], http_status: result[:http_status])
      true
    when :session_limit_exceeded
      issue_session_limit_gate!(pt: request.fullpath, flow: "in.emergency.passkeys.session")
      render json: {
        status: "session_limit_exceeded",
        redirect_url: new_auth_org_sign_in_emergency_passkey_path,
      }, status: :ok
      true
    else
      false
    end
  end

  def render_passkey_restricted_success(_result)
    render json: {
      status: "session_restricted",
      redirect_url: auth_org_sign_in_session_path,
    }, status: :ok
  end

  def passkey_checkpoint_redirect_url
    auth_org_sign_in_check_path(pt: retrieve_pt_for_checkpoint, ri: current_region_identifier)
  end

  def passkey_default_redirect_url
    auth_org_root_path(ri: current_region_identifier)
  end

  def minimum_response_budget_enabled?
    action_name == "create"
  end
end

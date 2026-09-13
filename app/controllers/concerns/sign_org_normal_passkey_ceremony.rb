# typed: false
# frozen_string_literal: true

# The org Normal sign-in passkey ceremony -- the second stage of
# Entra ID -> Passkey.
#
# It is the same PasskeySignInFlow implementation the Emergency ceremony uses,
# under the ordinary `authentication` challenge purpose. The one substantive
# difference is where the Operator comes from: the Entra transaction selected
# them, and nothing the browser sends may change that. The identifier parameter
# is not read at all here, so an attacker who completes Entra as Operator A
# cannot present Operator B's credential -- the challenge is issued against A,
# the challenge store returns A at consumption, and credential ownership is
# checked against A.
module SignOrgNormalPasskeyCeremony
  extend ActiveSupport::Concern

  include ::PasskeySignInFlow
  include ::OrgNormalSignInTransaction
  include ::SessionLimitGate
  include ::AuthenticationModeSwitchGuard

  included do
    declare_authentication_mode! :guest

    # Named per including controller so the options and verification endpoints
    # keep their own budgets, as they did when each declared its own limits.
    # A shared counter would let one endpoint's retries exhaust the other's.
    endpoint = name.demodulize.underscore.delete_suffix("_controller")

    rate_limit(
      to: 5,
      within: 1.minute,
      by: -> { request.remote_ip },
      scope: "auth_org_sign_in",
      name: "passkey_#{endpoint}_ip_burst",
      store: rate_limit_store,
      with: -> { render_rate_limited(retry_after: 60) },
    )
    rate_limit(
      to: 20,
      within: 15.minutes,
      by: -> { request.remote_ip },
      scope: "auth_org_sign_in",
      name: "passkey_#{endpoint}_ip_sustained",
      store: rate_limit_store,
      with: -> { render_rate_limited(retry_after: 900) },
    )

    before_action :require_org_normal_sign_in_transaction!
    before_action :start_minimum_response_budget
    after_action :enforce_minimum_response_budget
  end

  private

  # Entra authentication alone completes nothing, and the passkey stage alone
  # authenticates nobody: without the pending transaction there is no Operator
  # to authenticate, so the ceremony is refused before any challenge is issued.
  def require_org_normal_sign_in_transaction!
    return if org_normal_sign_in_operator.present?

    clear_org_normal_sign_in_transaction!
    render_error("errors.webauthn.sign_in_transaction_required", :unprocessable_content)
  end

  def before_passkey_options_request!
    verify_turnstile_stealth!
  end

  # The identifier the browser sends is never consulted. The public id below is
  # the Entra-selected Operator's own, so the flow's identifier checks pass on a
  # value the server chose.
  def normalized_passkey_identifier
    org_normal_sign_in_operator&.public_id.to_s
  end

  def valid_passkey_identifier?(identifier)
    Operator::PUBLIC_ID_FORMAT.match?(identifier)
  end

  def passkey_identifier_required_error_key
    "errors.webauthn.sign_in_transaction_required"
  end

  def passkey_identifier_invalid_error_key
    "errors.webauthn.sign_in_transaction_required"
  end

  def find_active_passkey_actor(_identifier)
    org_normal_sign_in_operator
  end

  # Second binding check, independent of the challenge's own actor binding: the
  # credential presented at verification must belong to the Operator the Entra
  # transaction still names.
  def allow_passkey_sign_in?(passkey)
    operator = org_normal_sign_in_operator
    return true if operator.present? && passkey.staff_id == operator.id

    emit_passkey_auth_failed(reason: "sign_in_transaction_actor_mismatch")
    render_error("errors.webauthn.credential_not_found", :unauthorized)
    false
  end

  def perform_passkey_sign_in(passkey)
    transaction = consume_org_normal_sign_in_transaction!

    establish_signed_in_session!(
      passkey.staff,
      pt: transaction&.dig(:pt).presence || retrieve_pt_for_checkpoint,
      ri: current_region_identifier,
      auth_method: "passkey",
      # The primary factor was Entra; the passkey is the second stage of one
      # ceremony, so the session is attributed to the credential that completed
      # it and carries the ordinary Normal context.
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
  end

  def handle_domain_specific_login_status(result)
    case result[:status]
    when :session_limit_hard_reject
      render_session_limit_hard_reject(message: result[:message], http_status: result[:http_status])
      true
    when :session_limit_exceeded
      issue_session_limit_gate!(pt: request.fullpath, flow: "in.passkeys.session")
      render json: {
        status: "session_limit_exceeded",
        redirect_url: new_auth_org_sign_in_passkey_path,
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

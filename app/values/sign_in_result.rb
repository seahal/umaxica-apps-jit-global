# typed: false
# frozen_string_literal: true

TERMINAL_HTTP_STATUSES = {
  session_limit_hard_reject: :forbidden,
  guardrail_blocked: :forbidden,
  login_forbidden: :forbidden,
  access_locked: :forbidden,
  credential_rejected: :unauthorized,
  identity_unavailable: :unauthorized,
  transaction_expired: :gone,
  failure: :bad_request,
  credential_failed: :unauthorized,
  invalid_request: :bad_request,
}.freeze

SIGN_IN_NON_TERMINAL_STATUSES = %i(success session_limit_pending authentication_evidence_recorded mfa_required).freeze

# The outcome of handing a verified credential to the session issuance
# boundary (adr/root-login-establishment-boundary.md). Each status means one
# thing; no flag on a success modifies it:
#
# - `:success` -- a root login was committed and this browser holds it.
# - `:session_limit_pending` -- nothing was issued; the sign-in flow waits for
#   session-limit resolution.
# - `:authentication_evidence_recorded` -- Auth recorded ceremony evidence for
#   an OIDC-started sign-in; Base has not issued a session yet.
# - `:mfa_required` -- nothing was issued; a second factor is pending.
# - a terminal status -- refused; nothing was issued.
SignInResult =
  Data.define(
    :status,
    :actor,
    :token,
    :sequence_id,
    :redirect_to,
    :response_status,
    :message,
  ) do
    def self.from_session_result(result, actor: nil, sequence_id: nil, session_management_path: nil)
      data = result.to_h.symbolize_keys
      status = normalized_status(data)

      new(
        status: status,
        actor: actor,
        token: (data[:access_token].present? && status == :success) ? data : nil,
        sequence_id: sequence_id,
        redirect_to: redirect_target(data, status: status, session_management_path: session_management_path),
        response_status: response_status(data, status: status),
        message: data[:message] || data[:error],
      )
    end

    def success?
      status == :success
    end

    # The browser continues to the next sign-in step. True for a committed
    # session and for recorded OIDC evidence; never for a pending or refused
    # attempt.
    def proceed?
      %i(success authentication_evidence_recorded).include?(status)
    end

    def terminal?
      TERMINAL_HTTP_STATUSES.key?(status)
    end

    def session_limit_pending?
      status == :session_limit_pending
    end

    def mfa_required?
      status == :mfa_required
    end

    def self.normalized_status(data)
      status = data[:status]&.to_sym
      return status if SIGN_IN_NON_TERMINAL_STATUSES.include?(status) || TERMINAL_HTTP_STATUSES.key?(status)

      :invalid_request
    end
    private_class_method :normalized_status

    def self.redirect_target(data, status:, session_management_path:)
      return data[:redirect_path] if data[:redirect_path].present?
      return session_management_path if status == :session_limit_pending

      nil
    end
    private_class_method :redirect_target

    def self.response_status(data, status:)
      return data[:http_status] if data[:http_status].present?
      return :found if SIGN_IN_NON_TERMINAL_STATUSES.include?(status)

      TERMINAL_HTTP_STATUSES.fetch(status, :bad_request)
    end
    private_class_method :response_status
  end

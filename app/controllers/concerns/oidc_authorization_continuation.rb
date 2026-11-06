# typed: false
# frozen_string_literal: true

# Design D GET resources only display a same-origin POST continuation. Authentication
# finalization, cancellation, and switching happen only on the existing authorization POST.
module OidcAuthorizationContinuation
  extend ActiveSupport::Concern

  include BrowserNavigationRequest

  public

  def show
    apply_base_browser_continuation_headers!
    return render_continuation_refusal! unless browser_navigation_request?

    claims = continuation_claims_for_get!
    token = issue_authorization_continuation(
      operation: claims.fetch(:operation), payload: claims.fetch(:payload),
      expires_at: claims.fetch(:expires_at),
    )
    render_authorization_continuation_form!(token)
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound,
         OidcClientRegistry::ClientNotFound, OidcClientRegistry::InvalidRedirectUri,
         FlowInvalidTransition, ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError
    render_continuation_refusal!
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError => e
    Rails.logger.error(
      JitLogEvent.format(
        "oidc.authorization_continuation.backend_failure",
        surface: oidc_result_surface,
        continuation_kind: self.class::OIDC_CONTINUATION_KIND,
        error_class: e.class.name,
        request_id: request.request_id,
      ),
    )
    render json: {
      error: "temporarily_unavailable",
      error_description: I18n.t("errors.rate_limit.backend_unavailable"),
    }, status: :service_unavailable
  end

  private

  def continuation_claims_for_get!
    case self.class::OIDC_CONTINUATION_KIND
    when :result then result_continuation_claims_for_get!
    when :cancellation then cancellation_continuation_claims_for_get!
    when :switch then switch_continuation_claims_for_get!
    else
      raise ArgumentError, "unsupported OIDC continuation kind"
    end
  end

  def result_continuation_claims_for_get!
    transaction_ref = params[:transaction_ref]
    result_ref = params[:result_ref]
    raise ArgumentError unless transaction_ref.is_a?(String) && transaction_ref.present? &&
      result_ref.is_a?(String) && result_ref.match?(AuthAdmissionBinding::REFERENCE_PATTERN)

    transaction = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
      surface: oidc_result_surface, transaction_id: transaction_ref,
    )
    validate_base_result_browser_binding!(transaction)
    validate_authorization_request!(transaction.authorize_params)
    validate_authorization_transaction_ready!(transaction)
    payload = BaseAuthAdmissionCoordinator.read_result_reference!(
      reference: result_ref, surface: oidc_result_surface,
      transaction_ref:, expected_intent: transaction.intent,
    )
    {
      operation: :result,
      expires_at: [transaction.expires_at, transaction.login_challenge_expires_at].compact.min,
      payload: {
        "transaction_ref" => transaction_ref,
        "result_ref" => result_ref,
        "result_generation" => payload.fetch("result_generation"),
      },
    }
  end

  def cancellation_continuation_claims_for_get!
    transaction_ref = params[:transaction_ref]
    cancellation_ref = params[:cancellation_ref]
    raise ArgumentError unless transaction_ref.is_a?(String) && cancellation_ref.is_a?(String)

    transaction = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
      surface: oidc_result_surface, transaction_id: transaction_ref,
    )
    validate_base_result_browser_binding!(transaction, cancellation: true)
    validate_authorization_request!(transaction.authorize_params)
    handoff = transaction.cancellation_handoff_ciphertext
    raise ArgumentError unless transaction.cancellation_handoff_ref == cancellation_ref && handoff.present?

    BaseAuthAdmissionCoordinator.read_authorization_cancellation_handoff!(
      handoff:, surface: oidc_result_surface, transaction_ref: transaction.transaction_id,
    )
    {
      operation: :cancellation,
      expires_at: transaction.expires_at,
      payload: { "transaction_ref" => transaction_ref, "cancellation_ref" => cancellation_ref },
    }
  end

  def switch_continuation_claims_for_get!
    switch_handoff = params[:switch_handoff]
    raise ArgumentError unless switch_handoff.is_a?(String) && switch_handoff.present?

    transaction, = BaseAuthAdmissionCoordinator.read_switch_handoff!(
      handoff: switch_handoff, surface: oidc_result_surface,
    )
    validate_base_result_browser_binding!(transaction)
    validate_authorization_request!(transaction.authorize_params)
    {
      operation: :switch,
      expires_at: transaction.expires_at,
      payload: { "switch_handoff" => switch_handoff },
    }
  end

  def render_continuation_refusal!
    render json: {
      error: "invalid_request",
      error_description: "invalid continuation request",
    }, status: :bad_request
  end
end

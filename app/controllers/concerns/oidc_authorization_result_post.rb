# typed: false
# frozen_string_literal: true

# Auth navigates to the matching Visa host with a non-authorizing result lookup.
# Continuation resources call the private jobs below after their own GET and browser
# binding checks. Durable transaction binding and finalization state live in PostgreSQL.
# Neither an Auth Origin nor a null Origin substitutes for the continuation contract.
module OidcAuthorizationResultPost
  extend ActiveSupport::Concern

  def create
    raise ArgumentError, "authorization start is required" unless params[:ceremony_action].present?

    start_authorization_from_post!
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound,
         OidcClientRegistry::ClientNotFound, OidcClientRegistry::InvalidRedirectUri,
         FlowInvalidTransition, ArgumentError
    render json: { error: "invalid_request", error_description: "invalid authorization request" },
           status: :bad_request
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError => e
    # A Valkey failure says nothing about the request, so it must not read as a rejected result.
    # The result stays unconsumed and may be retried while it is valid.
    Rails.logger.error(
      JitLogEvent.format(
        "oidc.authorization_result.backend_failure",
        surface: oidc_result_surface,
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

  def start_authorization_from_post!
    raise ArgumentError unless params[:ceremony_action].is_a?(String) && params[:ceremony_action] == "start" &&
      params[:result_ref].blank? && params[:transaction_ref].blank? && params[:result].blank?

    validate_authorization_request!
    return issue_authorization_code!(current_resource_for_oidc_authorization) if authorization_session_sufficient?

    start_authorization_ceremony!
  end

  def complete_authorization_from_post!
    raise ArgumentError unless params[:result_ref].is_a?(String) &&
      params.expect(:result_ref).match?(AuthAdmissionBinding::REFERENCE_PATTERN) &&
      params[:transaction_ref].is_a?(String) && params[:transaction_ref].present? && params[:result].blank?

    transaction = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
      surface: oidc_result_surface, transaction_id: params[:transaction_ref],
    )
    validate_base_result_browser_binding!(transaction)
    validate_authorization_request!(transaction.authorize_params)
    validate_authorization_transaction_ready!(transaction)
    payload = BaseAuthAdmissionCoordinator.read_result_reference!(
      reference: params[:result_ref], surface: oidc_result_surface,
      transaction_ref: params[:transaction_ref], expected_intent: transaction.intent,
    )
    resume_authorization!(transaction, result_generation: payload.fetch("result_generation"))
  end

  def cancel_authorization_from_post!
    raise ArgumentError unless params[:cancellation_ref].is_a?(String) && params[:transaction_ref].is_a?(String)

    transaction = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
      surface: oidc_result_surface, transaction_id: params[:transaction_ref],
    )
    validate_base_result_browser_binding!(transaction, cancellation: true)
    validate_authorization_request!(transaction.authorize_params)
    handoff = transaction.cancellation_handoff_ciphertext
    raise ArgumentError, "cancellation reference mismatch" unless
      transaction.cancellation_handoff_ref.present? && transaction.cancellation_handoff_ref == params[:cancellation_ref]

    BaseAuthAdmissionCoordinator.read_authorization_cancellation_handoff!(
      handoff:, surface: oidc_result_surface, transaction_ref: transaction.transaction_id,
    )
    transaction.cancel!(cancellation_handoff_digest: BaseAuthAdmissionCoordinator.cancellation_handoff_digest(handoff))
    redirect_to_same_origin_or_jump_url(
      ::OidcAuthorizeCoordinator.error_redirect_url(
        redirect_uri: transaction.redirect_uri, resource_type: resource_type, error: "access_denied",
        state: transaction.state,
      ),
      status: :see_other,
    )
  end

  def switch_authorization_from_post!
    transaction, target = BaseAuthAdmissionCoordinator.read_switch_handoff!(
      handoff: params[:switch_handoff], surface: oidc_result_surface,
    )
    validate_base_result_browser_binding!(transaction)
    validate_authorization_request!(transaction.authorize_params)
    handoff = BaseAuthAdmissionCoordinator.issue_switch_admission!(
      transaction:, base_browser_nonce: base_admission_browser_nonce, base_token: current_session_token, target:,
    )
    redirect_to_jump_url(authorization_switch_url(target:, entry_ref: handoff.reference), status: :see_other)
  end

  def current_resource_for_oidc_authorization
    case oidc_result_surface
    when "app" then current_client
    when "com" then current_visitor
    when "org" then current_operator
    else raise ArgumentError, "unsupported OIDC surface"
    end
  end

  def validate_authorization_transaction_ready!(transaction)
    decision_time = transaction.class.database_now
    if transaction.login_challenge_expired?(now: decision_time) || transaction.expired?(now: decision_time)
      raise ArgumentError, "authorization transaction expired"
    end
    return if transaction.authenticated?
    return if transaction.consumed? && transaction.base_finalized_at.present?

    raise ArgumentError, "authorization transaction is not ready"
  end

  # Includers also define authorization_switch_url(target:, entry_ref:) and resource_type.
  def oidc_result_surface
    raise NotImplementedError, "#{self.class} must define #oidc_result_surface"
  end
end

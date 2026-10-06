# typed: false
# frozen_string_literal: true

# OIDC results are posted from the Auth host to the matching Base host. The
# result is a short-lived, surface-bound transport capability whose durable
# transaction binding and finalization state live in PostgreSQL; it may be
# retried while valid. The request also requires an exact Auth origin (or the
# existing same-site proxy null-origin case). This is intentionally not a
# forgery-protection bypass.
module OidcAuthorizationResultPost
  extend ActiveSupport::Concern

  public

  def render_oidc_result_continuation!
    apply_base_browser_continuation_headers!
    result_reference = params[:result_ref]
    transaction_reference = params[:transaction_ref]
    unless result_reference.is_a?(String) && result_reference.match?(BaseAuthAdmissionCoordinator::ADMISSION_REFERENCE_PATTERN) &&
        transaction_reference.is_a?(String) && transaction_reference.present?
      raise ArgumentError, "invalid authorization result reference"
    end

    render "base/shared/result_continuation", layout: false,
                                              locals: { action_url: request.path,
                                                        result_ref: result_reference,
                                                        transaction_ref: transaction_reference,
                                                        ri: params[:ri], }
  end

  def create
    if params[:ceremony_action].present?
      raise ArgumentError unless params[:ceremony_action].is_a?(String) && params[:ceremony_action] == "start" &&
        params[:result_ref].blank? && params[:transaction_ref].blank? && params[:result].blank?

      validate_authorization_request!
      return issue_authorization_code!(current_resource_for_oidc_authorization) if authorization_session_sufficient?

      start_authorization_ceremony!
      return
    end

    if params[:result_ref].present? || params[:transaction_ref].present?
      raise ArgumentError unless params[:result_ref].is_a?(String) &&
        params.expect(:result_ref).match?(BaseAuthAdmissionCoordinator::ADMISSION_REFERENCE_PATTERN) &&
        params[:transaction_ref].is_a?(String) && params[:transaction_ref].present? && params[:result].blank?

      transaction =
        OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
          surface: oidc_result_surface, transaction_id: params[:transaction_ref].to_s,
        )
      validate_authorization_request!(transaction.authorize_params)
      validate_authorization_transaction_ready!(transaction)
      result_payload = BaseAuthAdmissionCoordinator.read_result_reference!(
        reference: params[:result_ref], surface: oidc_result_surface,
        transaction_ref: params[:transaction_ref], expected_intent: transaction.intent,
      )
      resume_authorization!(transaction, result_generation: result_payload.fetch("result_generation"))
      return
    end

    raise ArgumentError, "result reference is required" if params[:result].present?

    raise ArgumentError, "authorization start is required"
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

  def render_authorization_ceremony_start!
    render "base/shared/authorization_ceremony_start", layout: false,
                                                       locals: { action_url: request.path, fields: authorize_params.to_h }
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

  def oidc_result_surface
    raise NotImplementedError, "#{self.class} must define #oidc_result_surface"
  end
end

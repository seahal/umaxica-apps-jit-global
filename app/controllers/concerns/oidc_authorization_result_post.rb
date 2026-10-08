# typed: false
# frozen_string_literal: true

# Auth navigates to the matching Base host with a non-authorizing result lookup.
# Base renders its own confirmation form; only a receiver-local POST with standard
# Rails forgery protection accepts the stored evidence. Durable transaction binding
# and finalization state live in PostgreSQL, permitting exact retries while valid.
# Neither an Auth Origin nor a null Origin substitutes for Base's CSRF protection.
module OidcAuthorizationResultPost
  extend ActiveSupport::Concern

  public

  def render_oidc_result_continuation!
    apply_base_browser_continuation_headers!
    result_reference = params[:result_ref]
    transaction_reference = params[:transaction_ref]
    unless result_reference.is_a?(String) &&
        result_reference.match?(BaseAuthAdmissionCoordinator::ADMISSION_REFERENCE_PATTERN) &&
        transaction_reference.is_a?(String) && transaction_reference.present?
      raise ArgumentError, "invalid authorization result reference"
    end

    transaction = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
      surface: oidc_result_surface, transaction_id: transaction_reference,
    )
    validate_base_result_browser_binding!(transaction)

    render "base/shared/result_continuation", layout: false,
                                              locals: { action_url: request.path,
                                                        result_ref: result_reference,
                                                        transaction_ref: transaction_reference,
                                                        ri: params[:ri], }
  end

  def create
    if params[:ceremony_action].present?
      return start_authorization_from_post!
    end

    if params[:result_ref].present? || params[:transaction_ref].present?
      return complete_authorization_from_post!
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

  def start_authorization_from_post!
    raise ArgumentError unless params[:ceremony_action].is_a?(String) && params[:ceremony_action] == "start" &&
      params[:result_ref].blank? && params[:transaction_ref].blank? && params[:result].blank?

    validate_authorization_request!
    return issue_authorization_code!(current_resource_for_oidc_authorization) if authorization_session_sufficient?

    start_authorization_ceremony!
  end

  def complete_authorization_from_post!
    raise ArgumentError unless params[:result_ref].is_a?(String) &&
      params.expect(:result_ref).match?(BaseAuthAdmissionCoordinator::ADMISSION_REFERENCE_PATTERN) &&
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
    browser_nonce = base_admission_browser_nonce
    resume_authorization!(transaction, result_generation: payload.fetch("result_generation"))
    # Root issuance rotates the Rails session against fixation. Retain only this already-proven
    # nonce so the exact browser can retry a finalized result without creating a second root.
    return if transaction.reload.base_finalized_at.blank?

    session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] = browser_nonce
  end

  def render_authorization_ceremony_start!
    # The region is display context, not an authorization input, but the start POST builds the
    # Auth entry URL from it; dropping it here sends the ceremony to the credential gateway
    # region-less.
    region = RequestContextContract.normalize_region(params[:ri])
    fields = authorize_params.to_h
    fields = fields.merge("ri" => region) if region.present?
    render "base/shared/authorization_ceremony_start", layout: false,
                                                       locals: { action_url: request.path, fields: fields }
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

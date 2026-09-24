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

  def create
    transaction =
      OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
        surface: oidc_result_surface,
        transaction_id: params[:transaction_ref].to_s,
      )
    validate_authorization_request!(transaction.authorize_params)
    validate_authorization_transaction_ready!(transaction)
    result_payload = BaseAuthAdmissionCoordinator.read_result!(
      raw_code: params[:result].to_s,
      surface: oidc_result_surface,
      transaction_ref: params[:transaction_ref].to_s,
      expected_intent: transaction.intent,
    )
    resume_authorization!(transaction, result_generation: result_payload.fetch("result_generation"))
  rescue BaseAuthAdmissionCoordinator::Denied, Umaxica::Valkey::Unavailable,
         Umaxica::Valkey::OperationError, ActiveRecord::RecordNotFound,
         OidcClientRegistry::ClientNotFound, OidcClientRegistry::InvalidRedirectUri, ArgumentError
    render json: { error: "invalid_request", error_description: "invalid authorization request" },
           status: :bad_request
  end

  private

  def valid_request_origin?
    return true if oidc_result_same_site_opaque_origin?

    super
  end

  def oidc_result_same_site_opaque_origin?
    request.origin.to_s == "null" && sec_fetch_site_value == "same-site"
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

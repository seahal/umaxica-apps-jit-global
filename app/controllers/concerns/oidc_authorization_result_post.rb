# typed: false
# frozen_string_literal: true

# OIDC results are posted from the Auth host to the matching Base host. The
# result is still a one-shot, surface-bound protocol proof; the request also
# requires an exact Auth origin (or the existing same-site proxy null-origin
# case). This is intentionally not a forgery-protection bypass.
module OidcAuthorizationResultPost
  extend ActiveSupport::Concern

  public

  def create
    transaction =
      OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
        surface: oidc_result_surface,
        transaction_id: params[:transaction_ref].to_s,
      )
    BaseAuthAdmissionCoordinator.consume_result!(
      raw_code: params[:result].to_s,
      surface: oidc_result_surface,
      transaction_ref: params[:transaction_ref].to_s,
      expected_intent: transaction.intent,
    )
    validate_authorization_request!(transaction.authorize_params)
    resume_authorization!(transaction)
  rescue BaseAuthAdmissionCoordinator::Denied, Umaxica::Valkey::Unavailable,
         Umaxica::Valkey::OperationError, ActiveRecord::RecordNotFound, ArgumentError
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

  def oidc_result_surface
    raise NotImplementedError, "#{self.class} must define #oidc_result_surface"
  end
end

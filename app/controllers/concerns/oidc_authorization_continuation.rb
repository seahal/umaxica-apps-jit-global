# typed: false
# frozen_string_literal: true

# Design D GET resources for the Visa-side authorization result, Cancel and Switch
# continuations. The request is a browser navigation, never a HEAD or an arbitrary
# programmatic GET, and the inherited jobs perform the durable binding/CAS checks.
module OidcAuthorizationContinuation
  extend ActiveSupport::Concern

  public

  def show
    apply_base_browser_continuation_headers!
    return render_continuation_refusal! unless continuation_navigation_request?

    @oidc_continuation_request = true
    case self.class::OIDC_CONTINUATION_KIND
    when :result
      complete_authorization_from_post!
    when :cancellation
      cancel_authorization_from_post!
    when :switch
      switch_authorization_from_post!
    else
      raise ArgumentError, "unsupported OIDC continuation kind"
    end
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound,
         OidcClientRegistry::ClientNotFound, OidcClientRegistry::InvalidRedirectUri,
         FlowInvalidTransition, ArgumentError
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

  def continuation_navigation_request?
    request.get? && !request.head? &&
      request.headers["Sec-Fetch-Mode"].to_s == "navigate" &&
      request.headers["Sec-Fetch-Dest"].to_s == "document"
  end

  def render_continuation_refusal!
    render json: {
      error: "invalid_request",
      error_description: "invalid continuation request",
    }, status: :bad_request
  end
end

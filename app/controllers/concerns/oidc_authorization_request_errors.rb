# typed: false
# frozen_string_literal: true

# Delivery of authorization-request errors once `client_id` and `redirect_uri` are valid (D-147,
# D-148): ordinary errors go back to the registered `redirect_uri` with `error`, `state` and `iss`;
# an unsupported or combined `prompt` is a direct HTTP 400 from the OP. Errors about the client or
# the redirect URI themselves stay local (RFC 6749 4.1.2.1 MUST NOT redirect).
module OidcAuthorizationRequestErrors
  extend ActiveSupport::Concern

  private

  def redirect_authorization_request_error!(error)
    redirect_to_same_origin_or_jump_url(
      ::OidcAuthorizeCoordinator.error_redirect_url(
        redirect_uri: authorize_params[:redirect_uri].to_s,
        resource_type: resource_type,
        error: error.error,
        state: authorize_params[:state],
      ),
    )
  end

  def render_unsupported_prompt!(error)
    render json: { error: "invalid_request", error_description: "prompt: #{error.message}" }, status: :bad_request
  end
end

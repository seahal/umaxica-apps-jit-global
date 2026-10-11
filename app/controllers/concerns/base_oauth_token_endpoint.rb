# typed: false
# frozen_string_literal: true

module BaseOauthTokenEndpoint
  extend ActiveSupport::Concern

  def create
    result = ::OidcTokenExchangeCoordinator.call(
      grant_type: params[:grant_type],
      code: params[:code],
      refresh_token: params[:refresh_token],
      redirect_uri: params[:redirect_uri],
      client_id: params[:client_id],
      client_secret: params[:client_secret],
      client_assertion_type: params[:client_assertion_type],
      client_assertion: params[:client_assertion],
      code_verifier: params[:code_verifier],
      dpop_proof: request.headers["DPoP"],
      token_endpoint_uri: request.original_url,
      request_method: request.request_method,
      expected_resource_type: oauth_token_resource_type,
    )

    if result.success?
      response.headers["Cache-Control"] = "no-store"
      response.headers["Pragma"] = "no-cache"
      render json: result.token_response, status: :ok
    else
      render json: { error: result.error, error_description: result.error_description },
             status: :bad_request
    end
  end

  private

  def oauth_token_resource_type
    self.class.const_get(:OIDC_RESOURCE_TYPE, false)
  rescue NameError
    raise NameError, "#{self.class.name} must define OIDC_RESOURCE_TYPE"
  end
end

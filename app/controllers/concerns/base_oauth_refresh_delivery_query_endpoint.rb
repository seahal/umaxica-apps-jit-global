# typed: false
# frozen_string_literal: true

# POST /oauth/refresh-deliveries/query (R5-WU08). Server-to-server only: the caller proves itself
# with a private_key_jwt assertion bound to this exact URL; there is no browser session or cookie.
module BaseOauthRefreshDeliveryQueryEndpoint
  extend ActiveSupport::Concern

  public

  def create
    result = ::OidcRefreshDeliveryQuery.call(
      refresh_token: params[:refresh_token].to_s,
      attempt_ref: params[:attempt_ref].to_s,
      client_id: params[:client_id].to_s,
      client_assertion: params[:client_assertion].to_s,
      endpoint_uri: request.original_url,
      resource_type: self.class.const_get(:OIDC_RESOURCE_TYPE, false),
    )
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
    if result.success?
      render json: result.token_response, status: :ok
    else
      status = (result.error == "invalid_client") ? :unauthorized : :bad_request
      render json: { error: result.error }, status:
    end
  end
end

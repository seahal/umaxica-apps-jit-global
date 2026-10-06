# typed: false
# frozen_string_literal: true

module BaseOauthEndpoint
  extend ActiveSupport::Concern

  private

  def skip_oauth_session!
    request.session_options[:skip] = true
  end

  def set_oauth_cache_headers
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
  end

  def render_oauth_userinfo(resource_type:)
    authorization = oauth_userinfo_authorization
    return render_oauth_bearer_error(authorization.fetch(:error)) if authorization[:error]

    result = ::OidcAccessTokenAuthenticator.call(
      access_token: authorization.fetch(:access_token),
      resource_type: resource_type,
      host: request.host,
      authorization_scheme: "Bearer",
      dpop_proof: request.headers["DPoP"],
      request_method: request.request_method,
      request_uri: request.original_url,
    )
    return render_oauth_bearer_error(result.error) unless result.success?

    render json: ::OidcUserInfoResponseSerializer.build(resource: result.resource, payload: result.payload)
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error(
      JitLogEvent.format("oidc.userinfo.dependency_unavailable", error_class: e.class.name),
    )
    render json: { error: "temporarily_unavailable" }, status: :service_unavailable
  end

  def oauth_userinfo_authorization
    header = ::AuthAuthorizationHeader.value(request).to_s
    if header.blank?
      return { error: "invalid_request" } if oauth_userinfo_alternate_transport?

      return { error: "missing_token" }
    end

    match = /\ABearer[ \t]+([^\s]+)\z/i.match(header)
    return { error: "invalid_request" } unless match

    { access_token: match[1] }
  end

  def render_oauth_bearer_error(error)
    case error
    when "missing_token"
      response.set_header("WWW-Authenticate", "Bearer")
      render json: {}, status: :unauthorized
    when "invalid_request"
      response.set_header("WWW-Authenticate", 'Bearer error="invalid_request"')
      render json: { error: error }, status: :bad_request
    when "insufficient_scope"
      response.set_header("WWW-Authenticate", 'Bearer error="insufficient_scope", scope="openid"')
      render json: { error: error }, status: :forbidden
    when "invalid_token"
      response.set_header("WWW-Authenticate", 'Bearer error="invalid_token"')
      render json: { error: error }, status: :unauthorized
    else
      response.set_header("WWW-Authenticate", "Bearer")
      render json: { error: error }, status: :unauthorized
    end
  end

  def oauth_userinfo_alternate_transport?
    query_token = params.key?(:access_token) || params.key?("access_token")
    cookies = request.cookies
    cookie_token =
      cookies.key?("access_token") ||
      cookies.key?(::OidcRpBrowserCredentialContract::ACCESS_COOKIE)
    query_token || cookie_token
  end
end

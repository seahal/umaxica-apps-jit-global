# typed: false
# frozen_string_literal: true

# Cookie transport for credentials issued by Base's RP Session authority.
# This boundary is deliberately separate from root Browser Session cookie
# helpers: an RP Access/Refresh credential must never be made to look like a
# root ClientToken, VisitorToken, or OperatorToken.
module OidcRpBrowserCredentialContract
  ACCESS_COOKIE = OidcRpCookieName.access
  REFRESH_COOKIE = OidcRpCookieName.refresh

  module_function

  def access_cookie_options(expires_at: nil)
    cookie_options(expires_at: expires_at)
  end

  def refresh_cookie_options(expires_at: nil)
    cookie_options(expires_at: expires_at)
  end

  def access_cookie_deletion_options
    cookie_options.except(:expires, :httponly)
  end

  def refresh_cookie_deletion_options
    cookie_options.except(:expires, :httponly)
  end

  def access_expires_at(access_token)
    payload = JWT.decode(access_token.to_s, nil, false).first
    exp = payload["exp"]
    return if exp.blank?

    Time.at(Integer(exp, 10)).utc
  rescue JWT::DecodeError, ArgumentError, TypeError, RangeError
    nil
  end

  def decode_access_token(token:, host:, resource_type:, client_id:, allow_expired: false)
    client = OidcClientRegistry.find(client_id)
    return if client.blank?
    return unless OidcIssuer.resource_type_for_client(client) == resource_type.to_s

    decoder =
      if allow_expired
        AuthenticationTokenService.method(:decode_allow_expired)
      else
        AuthenticationTokenService.method(:decode)
      end
    payload = decoder.call(
      token,
      host: host,
      resource_type: resource_type,
      issuer: OidcIssuer.for_resource_type(resource_type),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
    )
    return if payload.blank?
    return unless AuthorizationTokenClaims.client_id(payload) == client.client_id
    return if AuthorizationTokenClaims.session_id(payload).blank?

    payload
  end

  def require_token_response!(token_response)
    access_token = token_response[:access_token] || token_response["access_token"]
    refresh_token = token_response[:refresh_token] || token_response["refresh_token"]
    raise ArgumentError, "RP token response is incomplete" if access_token.blank? || refresh_token.blank?

    [access_token.to_s, refresh_token.to_s]
  end

  def cookie_options(expires_at: nil)
    {
      secure: JitSessionCookieConfig.force_secure?,
      httponly: true,
      same_site: :lax,
      path: "/",
      domain: false,
      expires: expires_at,
    }.compact
  end
  private_class_method :cookie_options
end

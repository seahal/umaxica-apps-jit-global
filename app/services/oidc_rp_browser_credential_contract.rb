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

  def access_cookie_options(expires_in: nil, expires_at: nil, now: Time.current)
    expiry = expiry_from(expires_in, expires_at:, now:)
    raise ArgumentError, "RP access cookie expiry is required" unless expiry

    cookie_options(expires_at: expiry)
  end

  def refresh_cookie_options(expires_in: nil, expires_at: nil, now: Time.current)
    expiry = expiry_from(expires_in, expires_at:, now:)
    raise ArgumentError, "RP refresh cookie expiry is required" unless expiry

    cookie_options(expires_at: expiry)
  end

  def access_cookie_deletion_options
    cookie_options.except(:expires, :httponly)
  end

  def refresh_cookie_deletion_options
    cookie_options.except(:expires, :httponly)
  end

  def access_expires_at_from_response(token_response, now: Time.current)
    expires_at_from_response(token_response, :expires_in, now:)
  end

  def refresh_expires_at_from_response(token_response, now: Time.current)
    expires_at_from_response(token_response, :refresh_token_expires_in, now:)
  end

  def cookie_expiries_from_response(token_response, now: Time.current)
    access_expires_at = access_expires_at_from_response(token_response, now:)
    refresh_expires_at = refresh_expires_at_from_response(token_response, now:)
    if refresh_expires_at < access_expires_at
      raise ArgumentError, "RP refresh expiry precedes access expiry"
    end

    { access_expires_at: access_expires_at, refresh_expires_at: refresh_expires_at }
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

  def expiry_from(expires_in, expires_at:, now:)
    return expires_at.to_time if expires_at
    return if expires_in.nil?

    seconds =
      case expires_in
      when Integer then expires_in
      when String then Integer(expires_in, 10)
      end
    raise ArgumentError, "RP token expiry is invalid" unless seconds && seconds >= 0

    now.to_time + seconds.seconds
  rescue ArgumentError, TypeError, NoMethodError
    raise ArgumentError, "RP token expiry is invalid"
  end

  def expires_at_from_response(token_response, key, now:)
    raise ArgumentError, "RP token response must be a Hash" unless token_response.is_a?(Hash)

    value = token_response[key] || token_response[key.to_s]
    raise ArgumentError, "RP token response is missing #{key}" if value.nil?

    seconds =
      case value
      when Integer then value
      when String then Integer(value, 10)
      end
    raise ArgumentError, "RP token response #{key} is invalid" unless seconds && seconds >= 0

    now.to_time + seconds.seconds
  rescue ArgumentError, TypeError, NoMethodError
    raise ArgumentError, "RP token response #{key} is invalid"
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

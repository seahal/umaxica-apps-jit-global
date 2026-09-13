# typed: false
# frozen_string_literal: true

module CoreBrowserCredentialContract
  ACCESS_COOKIE = AuthenticationCookieName.access
  REFRESH_COOKIE = AuthenticationCookieName.refresh
  OIDC_COOKIE = "_umaxica_session"
  ACCESS_AUDIENCE = "core-browser"
  ACCESS_TTL = 10.minutes
  REFRESH_PATH = "/"
  OIDC_PATH = "/"

  module_function

  def enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("CORE_BROWSER_JWT_COOKIE_ENABLED", false))
  end

  def access_cookie_options(expires_at:)
    auth_cookie_service_options(expires_at: expires_at)
  end

  def refresh_cookie_options(expires_at:)
    auth_cookie_service_options(expires_at: expires_at)
  end

  def oidc_cookie_options(expires_at:)
    secure_http_only_options.merge(
      same_site: :lax,
      path: OIDC_PATH,
      expires: expires_at,
    )
  end

  def access_cookie_deletion_options
    auth_cookie_service_options.except(:expires, :httponly)
  end

  def refresh_cookie_deletion_options
    auth_cookie_service_options.except(:expires, :httponly)
  end

  def oidc_cookie_deletion_options
    secure_http_only_options.merge(same_site: :lax, path: OIDC_PATH)
  end

  def encode_access_token(resource:, token_record:, host:, resource_type:, expires_at: ACCESS_TTL.from_now)
    expires_at = SessionAbsoluteExpiryValue.cap(
      proposed_expiry: expires_at,
      absolute_expiry: token_record.discarded_at,
    )

    AuthenticationTokenService.encode(
      resource,
      host: host,
      resource_type: resource_type,
      session_public_id: token_record.public_id,
      session_id: token_record.public_id,
      oidc_sid: token_record.try(:oidc_sid),
      oidc_jti: token_record.try(:oidc_jti),
      expires_at: expires_at,
      scopes: %w(openid profile:read self:read),
      issuer: AuthenticationJwtConfiguration.issuer,
      audiences: [ACCESS_AUDIENCE],
      jwt_issuer_id: core_jwt_issuer_id(resource_type),
    )
  end

  def access_token_expires_at_for(token_record:, now: Time.current)
    SessionAbsoluteExpiryValue.cap(
      proposed_expiry: now + ACCESS_TTL,
      absolute_expiry: token_record.discarded_at,
    )
  end

  def decode_access_token(token:, host:, resource_type:)
    AuthenticationTokenService.decode(
      token,
      host: host,
      resource_type: resource_type,
      issuer: AuthenticationJwtConfiguration.issuer,
      audiences: [ACCESS_AUDIENCE],
      jwt_issuer_id: core_jwt_issuer_id(resource_type),
    )
  end

  def native_or_side_audience?(payload)
    Array(AuthorizationTokenClaims.audiences(payload)).any? do |audience|
      %w(palm-api side-service side:ssr:read).include?(audience.to_s)
    end
  end

  def core_jwt_issuer_id(_resource_type)
    client_id = "core-next-rp"

    namespace = OidcClientRegistry.jwt_namespace_for(client_id)
    namespace.present? ? "surface:#{namespace}" : nil
  end

  def auth_cookie_service_options(expires_at: nil)
    {
      secure: true,
      httponly: true,
      same_site: :strict,
      path: "/",
      expires: expires_at,
    }.compact
  end
  private_class_method :auth_cookie_service_options

  def secure_http_only_options
    {
      secure: true,
      httponly: true,
    }
  end
  private_class_method :secure_http_only_options
end

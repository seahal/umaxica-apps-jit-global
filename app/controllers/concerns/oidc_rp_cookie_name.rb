# typed: false
# frozen_string_literal: true

module OidcRpCookieName
  HOST_COOKIE_PREFIX = "__Host-"
  ACCESS_BASENAME = "oidc_rp_access"
  REFRESH_BASENAME = "oidc_rp_refresh"

  module_function

  def access(production: JitSessionCookieConfig.force_secure?)
    with_host_prefix(ACCESS_BASENAME, production: production)
  end

  def refresh(production: JitSessionCookieConfig.force_secure?)
    with_host_prefix(REFRESH_BASENAME, production: production)
  end

  def with_host_prefix(basename, production:)
    production ? "#{HOST_COOKIE_PREFIX}#{basename}" : basename
  end
end

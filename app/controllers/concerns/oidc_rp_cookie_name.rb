# typed: false
# frozen_string_literal: true

module OidcRpCookieName
  HOST_COOKIE_PREFIX = "__Host-"
  ACCESS_BASENAME = "rp-access"
  REFRESH_BASENAME = "rp-refresh"
  # Opaque local session handle of an RP cell (R5-WU17); never a credential by itself.
  SESSION_BASENAME = "rp-session"

  module_function

  def access(production: JitSessionCookieConfig.force_secure?)
    with_host_prefix(ACCESS_BASENAME, production: production)
  end

  def refresh(production: JitSessionCookieConfig.force_secure?)
    with_host_prefix(REFRESH_BASENAME, production: production)
  end

  def session(production: JitSessionCookieConfig.force_secure?)
    with_host_prefix(SESSION_BASENAME, production: production)
  end

  def with_host_prefix(basename, production:)
    production ? "#{HOST_COOKIE_PREFIX}#{basename}" : basename
  end
end

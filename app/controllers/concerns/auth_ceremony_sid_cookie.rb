# typed: false
# frozen_string_literal: true

# Writes/reads random-only __Host-auth_sid. Cookie value is the opaque sid only.
# The __Host- prefix is gated on JitSessionCookieConfig.force_secure? so the
# Secure+Path=/+no Domain invariant holds whenever the prefix is applied.
module AuthCeremonySidCookie
  extend ActiveSupport::Concern

  COOKIE_BASENAME = "auth_sid"
  COOKIE_TTL = AuthCeremonySession::DEFAULT_TTL

  public

  def auth_ceremony_sid_cookie_name
    if JitSessionCookieConfig.force_secure?
      "#{AuthIoKeys::HOST_COOKIE_PREFIX}#{COOKIE_BASENAME}"
    else
      COOKIE_BASENAME
    end
  end

  def write_auth_ceremony_sid_cookie!(raw_sid, expires_at: COOKIE_TTL.from_now)
    cookies[auth_ceremony_sid_cookie_name] = {
      value: raw_sid,
      expires: expires_at,
      secure: JitSessionCookieConfig.force_secure?,
      httponly: true,
      same_site: :lax,
      path: "/",
    }
  end

  def read_auth_ceremony_sid_cookie
    cookies[auth_ceremony_sid_cookie_name].presence
  end

  def clear_auth_ceremony_sid_cookie!
    cookies.delete(auth_ceremony_sid_cookie_name, path: "/")
  end
end

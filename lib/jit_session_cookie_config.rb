# typed: false
# frozen_string_literal: true

module JitSessionCookieConfig
  module_function

  # Determines whether to force secure cookie settings.
  # Returns true outside development/test, or when FORCE_SECURE_COOKIES=1.
  # `id_service_host` is currently unused but kept for caller compatibility and
  # potential host-based policy; it is optional so non-session callers
  # (auth/verification cookie naming) can reuse this predicate.
  def force_secure?(id_service_host: nil, rails_env: Rails.env)
    _ = id_service_host
    return false if rails_env.test?

    return true if rails_env.production?
    return true if ENV["FORCE_SECURE_COOKIES"] == "1"
    return true unless rails_env.development?

    false
  end

  # Returns the session cookie key based on secure mode.
  # Production uses __Host- prefix for strict cookie binding.
  def cookie_key(force_secure:)
    force_secure ? "__Host-session" : "session"
  end

  # The session cookie is host-only in every environment: no Domain attribute (the Rails and Rack
  # default, RFC 6265bis 4.1.2.3). Each FQDN owns its own Rails session, so one host's
  # `reset_session` or a different `secret_key_base` cannot erase or overwrite another host's
  # session. Not shared across subdomains, and not Partitioned (CHIPS is for embedded third-party
  # contexts, not a top-level first-party session).
  def session_options(force_secure:)
    {
      expire_after: 14.days,
      key: cookie_key(force_secure: force_secure),
      secure: force_secure,
      httponly: true,
      same_site: :lax,
    }
  end
end

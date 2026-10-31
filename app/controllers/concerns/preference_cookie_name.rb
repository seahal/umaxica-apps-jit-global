# typed: false
# frozen_string_literal: true

module PreferenceCookieName
  module_function

  # Shared anonymous preference JWT. It is surface-scoped; the display pair is shared within a
  # realm domain and the binding remains host-only.
  def anonymous_jwt
    "__Secure-preference"
  end

  def anonymous_experience
    "__Secure-experience"
  end

  def binding
    "__Host-preference_binding"
  end
end

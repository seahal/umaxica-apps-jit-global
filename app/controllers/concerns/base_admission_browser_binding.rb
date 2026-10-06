# typed: false
# frozen_string_literal: true

require "base64"

# Base keeps one random browser marker in its host-only Rails session while an
# admission crosses to Auth. The marker is never placed in a URL, form, page
# prop, cookie value, or log; only its per-entry digest reaches Ticket storage.
module BaseAdmissionBrowserBinding
  extend ActiveSupport::Concern

  BROWSER_NONCE_SESSION_KEY = "auth_admission_browser_nonce"
  BROWSER_NONCE_BYTES = 32

  included do
    class_attribute :base_admission_surface_name, instance_accessor: false
  end

  class_methods do
    public

    def base_admission_surface(surface = nil)
      self.base_admission_surface_name = surface.to_s if surface
      base_admission_surface_name
    end
  end

  public

  # Call only from a CSRF-protected Base initiation POST. Retries in the same
  # browser preserve this value so another tab cannot silently become a new
  # browser proof.
  def ensure_base_admission_browser_nonce!
    current = session[BROWSER_NONCE_SESSION_KEY].to_s.presence
    return current if current.present?

    session[BROWSER_NONCE_SESSION_KEY] = Base64.urlsafe_encode64(
      SecureRandom.random_bytes(BROWSER_NONCE_BYTES), padding: false,
    )
  end

  def base_admission_browser_nonce
    value = session[BROWSER_NONCE_SESSION_KEY].to_s.presence
    return if value.blank?
    return value if value.match?(/\A[A-Za-z0-9_-]{43}\z/)

    nil
  end

  def base_admission_browser_digest(entry_ref)
    nonce = base_admission_browser_nonce
    raise BaseAuthAdmissionCoordinator::Denied.new(
      "browser binding is missing",
      code: "session_binding_mismatch",
    ) if nonce.blank?

    AuthAdmissionBinding.browser_digest(
      surface: self.class.base_admission_surface_name, entry_ref: entry_ref, nonce: nonce,
    )
  end

  def apply_base_browser_continuation_headers!
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Content-Security-Policy"] = "frame-ancestors 'none'"
  end

  # Used by an explicit restart to prevent the previous browser marker from
  # confirming a newly issued entry.
  def reset_base_admission_browser_nonce!
    session.delete(BROWSER_NONCE_SESSION_KEY)
    ensure_base_admission_browser_nonce!
  end
end

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

  public

  # Call only from a CSRF-protected Base initiation POST. Every initiation
  # issues a fresh marker: a value already in the session may have been planted
  # with a fixed session cookie, so it is never adopted as this browser's proof.
  def ensure_base_admission_browser_nonce!
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

  def validate_base_result_browser_binding!(transaction)
    BaseAuthAdmissionCoordinator.validate_result_browser_binding!(
      transaction:, surface: self.class.base_admission_surface_name,
      base_browser_nonce: base_admission_browser_nonce, base_token: current_session_token,
    )
  end

  def base_registration_restart_binding!(scope:, method:)
    return if params[:restart_of].nil?

    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: self.class.base_admission_surface_name, reference: params[:restart_of],
    )
    BaseAuthAdmissionCoordinator.validate_registration_restart_browser!(
      binding:, surface: self.class.base_admission_surface_name,
      base_browser_nonce: base_admission_browser_nonce, base_token: current_session_token, scope:, method:,
    )
  end
end

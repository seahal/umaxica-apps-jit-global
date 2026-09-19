# typed: false
# frozen_string_literal: true

# Ordinary "sign out" flow. Revokes only the **current** session token,
# clears auth cookies, and resets the Rails session.
#
# "Sign out from all devices" must be invoked explicitly via
# `logout_all_sessions_for!` from a dedicated endpoint (settings UI,
# password rotation, lifecycle transition, etc.). Do NOT call it from this
# path: a user clicking "Sign out" expects only the current browser to be
# signed out.
#
# Note: `Oidc::SingleLogoutService` is intentionally NOT invoked here. Its
# current implementation revokes every active token for the actor and is
# closer to an admin-side "revoke all sessions" routine than an OIDC SLO
# protocol notifier. Re-introducing it on this path would silently downgrade
# ordinary logout to a global logout (which was the bug fixed in this file).
module AuthenticationLogoutable
  extend ActiveSupport::Concern

  class ResolutionError < StandardError; end

  private

  def logout_current_session!(reason: "user_logout")
    begin
      resource = safe_current_resource_for_logout
      AuthenticationLogoutCurrentSession.call(
        current: Actor,
        resource: resource,
        token: safe_current_session_for_logout,
        token_class: safe_token_class_for_logout,
        session_public_id: safe_current_session_public_id_for_logout,
        reason: reason,
      )
      record_logout_audit(resource)
    ensure
      # Detach the browser from the signed-out principal's preference
      # credential before ending the auth session (target semantics section 6.1;
      # see memos/2026-07-21-preference-lifecycle-sign-out-audit.md section 4 for
      # the gap this closes). Non-fatal by construction: never allowed to
      # block or fail ordinary sign-out.
      rotate_preference_after_sign_out! if respond_to?(:rotate_preference_after_sign_out!, true)
      clear_auth_cookies! if respond_to?(:clear_auth_cookies!, true)
      Actor.clear if defined?(Actor)
      reset_session_and_clear_inertia_history!
    end
    LogoutResult.success
  end

  # Explicit "sign out from all devices". Callers must be dedicated
  # endpoints (settings UI, admin tools, lifecycle hooks) -- never the
  # ordinary "Sign out" button.
  #
  # Preference credential scope on this path: `rotate_preference_after_sign_out!`
  # only ever touches the *current* request's browser-scoped preference
  # cookie/row -- there is no server-side mechanism to push a new cookie
  # into a browser that isn't making the current request, so a remote
  # device's still-valid `preference_access`/`preference_refresh`/
  # `preference_dbsc` credential is not retired by this call. This is an
  # accepted, deliberate limitation, not a gap:
  #   - AuthenticationLogoutAllSessions revokes every *auth* session for the
  #     resource, so a remote device's next authenticated request fails
  #     auth regardless of its Preference cookie state.
  #   - Preference is never an authentication/authorization authority (see
  #     security invariant 9 in
  #     memos/2026-07-21-preference-lifecycle-hardening-implementation.md):
  #     an un-retired remote Preference credential can still resolve display
  #     preferences for that device but cannot grant access to the account.
  #   - Preference tokens are not enumerable per-account server-side (they
  #     are looked up by opaque public_id/refresh digest carried in a
  #     cookie, not by a resource foreign key), so there is nothing this
  #     method could iterate to retire "the other devices'" rows even if it
  #     tried.
  def logout_all_sessions_for!(resource:, reason:)
    begin
      AuthenticationLogoutAllSessions.call(resource: resource, reason: reason)
      record_logout_all_sessions_audit(resource)
    ensure
      rotate_preference_after_sign_out! if respond_to?(:rotate_preference_after_sign_out!, true)
      clear_auth_cookies! if respond_to?(:clear_auth_cookies!, true)
      Actor.clear if defined?(Actor)
      reset_session_and_clear_inertia_history!
    end
    LogoutResult.success
  end

  # Ends the browser's Rails session and asks Inertia to clear its history on the next page this
  # origin renders. `encrypt_history` only encrypts history entries; the key lives in the tab's
  # sessionStorage, which `reset_session` cannot reach, so without the clear a same-document Back
  # restores the signed-in page from history without asking the server. The flag is written
  # after the reset, so it is the only thing the new session carries; inertia_rails keeps it
  # across redirects and drops it once a page is rendered.
  def reset_session_and_clear_inertia_history!
    reset_session
    session[:inertia_clear_history] = true
  end

  def safe_current_resource_for_logout
    current_resource if respond_to?(:current_resource, true)
  rescue StandardError => e
    raise_logout_resolution_error!(:current_resource, e)
  end

  def safe_current_session_for_logout
    current_session || session_token_from_refresh_cookie_for_logout
  rescue StandardError => e
    raise_logout_resolution_error!(:current_session, e)
  end

  def safe_token_class_for_logout
    token_class if respond_to?(:token_class, true)
  rescue StandardError => e
    raise_logout_resolution_error!(:token_class, e)
  end

  def safe_current_session_public_id_for_logout
    session_token = safe_current_session_for_logout
    return session_token.public_id if session_token.respond_to?(:public_id) && session_token.public_id.present?

    return current_session_public_id if respond_to?(:current_session_public_id, true)

    current_session_public_id_from_refresh_cookie_for_logout
  rescue StandardError => e
    raise_logout_resolution_error!(:current_session_public_id, e)
  end

  def session_token_from_refresh_cookie_for_logout
    return nil unless respond_to?(:cookies, true)
    return nil unless respond_to?(:token_class, true)
    return nil unless respond_to?(:find_refresh_token_record, true)

    refresh_plain = cookies[AuthenticationBase::REFRESH_COOKIE_KEY].to_s
    refresh_public_id, = token_class.parse_refresh_token(refresh_plain)
    find_refresh_token_record(refresh_public_id)
  rescue StandardError
    nil
  end

  def current_session_public_id_from_refresh_cookie_for_logout
    session_token_from_refresh_cookie_for_logout&.public_id
  end

  def raise_logout_resolution_error!(component, exception)
    Rails.logger.warn(
      JitLogEvent.format(
        "auth.logout.resolution.failed",
        component: component,
        error_class: exception.class.name,
      ),
    )

    raise ResolutionError.new("Logout #{component} resolution failed"), cause: exception
  end

  def record_logout_audit(resource)
    return if resource.blank?
    return unless respond_to?(:record_audit, true)

    record_audit(AuthenticationBase::AUDIT_EVENTS[:logout_current_session], resource: resource)
  end

  def record_logout_all_sessions_audit(resource)
    return if resource.blank?
    return unless respond_to?(:record_audit, true)

    record_audit(AuthenticationBase::AUDIT_EVENTS[:logout_all_sessions], resource: resource)
  end
end

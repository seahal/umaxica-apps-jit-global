# typed: false
# frozen_string_literal: true

# Refuses to start or complete a new sign-in ceremony for a browser that is
# already authenticated.
#
# There is no supported transition between the Normal and Emergency
# authentication contexts inside a session. A Normal session cannot be
# downgraded into Restricted Mode in place, and an Emergency session cannot be
# upgraded into a Normal one -- not by completing Entra, not by re-running the
# Passkey or Secret ceremony, not by Step-Up, and not by any token rotation or
# session renewal. Changing mode means signing out and signing in again.
#
# The guest-only access-policy pipeline remains the primary entry guard. This
# concern gives every sign-in surface the same deliberately minimal response
# and prevents both successful pages and refusals from being cached.
module AuthenticationModeSwitchGuard
  extend ActiveSupport::Concern

  SIGN_IN_UNAVAILABLE_MESSAGE = AlreadyAuthenticatedError::MESSAGE

  included do
    before_action :prevent_sign_in_response_storage!
  end

  private

  def handle_guest_only_json(_options)
    render_sign_in_unavailable_while_authenticated
  end

  def handle_guest_only_html(_options)
    render_sign_in_unavailable_while_authenticated
  end

  # Reached for non-GET, non-JSON guest-only rejections. Same answer: the
  # request is refused, and the way forward is sign-out.
  def handle_guest_only_with_status_checks(options)
    _ = options
    render_sign_in_unavailable_while_authenticated
  end

  def reject_new_sign_in_if_authenticated!
    return unless logged_in?

    render_sign_in_unavailable_while_authenticated
  end

  def render_sign_in_unavailable_while_authenticated(_exception = nil)
    prevent_sign_in_response_storage!
    render plain: SIGN_IN_UNAVAILABLE_MESSAGE, status: :conflict
  end

  def prevent_sign_in_response_storage!
    response.set_header("Cache-Control", "no-store")
  end
end

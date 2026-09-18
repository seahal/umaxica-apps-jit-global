# typed: false
# frozen_string_literal: true

# Provides methods for enforcing isolation mode for restricted sessions.
# Controllers must explicitly enable this by calling:
#   before_action :enforce_restricted_session_guard!
#
# This concern does NOT automatically add any callbacks when included,
# avoiding surprise side effects. Controllers opt-in to the behavior.
module RestrictedSessionGuard
  extend ActiveSupport::Concern

  BLOCKED_MESSAGE = "きんそくじこうです"

  # Note: No automatic before_action is added here.
  # Controllers must explicitly add: before_action :enforce_restricted_session_guard!

  private

  def enforce_restricted_session_guard!
    current_resource if respond_to?(:current_resource, true)
    return unless respond_to?(:current_session_restricted?, true)

    restricted = current_session_restricted?
    return unless restricted

    allowlisted = allowlisted_for_restricted_session?
    return if allowlisted

    handle_restricted_session_block
  end

  def allowlisted_for_restricted_session?
    return false if restricted_session_expired?

    controller_path.end_with?("in/sessions", "in/session/cancellations") ||
      controller_path == "base/app/identity/mfa/resets"
  end

  def restricted_session_expired?
    session = current_session
    return false unless session&.restricted?

    expired =
      session.discarded_at.present? &&
      !session.discarded_at.respond_to?(:infinite?) &&
      session.discarded_at <= Time.current
    return false unless expired

    return true if session.respond_to?(:revoked?) && session.revoked?

    # Find the nearest abstract base record that defines the database
    # connection (e.g., AppTicketRecord, OrgTicketRecord)
    base_class = session.class.connection_class_for_self

    base_class.connected_to(role: :writing) do
      session.revoke!
    end

    Rails.logger.info(
      JitLogEvent.format(
        "session.restricted.expired",
        user_token_id: session.public_id,
        user_id: session.respond_to?(:user_id) ? session.user_id : nil,
      ),
    )

    true
  end

  def handle_restricted_session_block
    Rails.logger.info(
      JitLogEvent.format(
        "session.restricted.blocked_route",
        path: request.path,
        method: request.request_method,
        user_token_id: current_session&.public_id,
        user_id: current_session.respond_to?(:user_id) ? current_session.user_id : nil,
      ),
    )

    render plain: BLOCKED_MESSAGE, status: :locked
  end
end

# typed: false
# frozen_string_literal: true

module Base
  module Identity
    class SessionPresenter
      include ::SessionTimestampHelper

      public

      def present(session, current:, surface:)
        status_key = "base.shared.identity.sessions.#{current ? "current_session" : "active"}"
        attributes = {
          device: I18n.t("base.shared.identity.sessions.unknown_device"),
          last_activity: localized_session_timestamp(session.last_used_at || session.created_at),
          created: localized_session_timestamp(session.created_at),
          expires_at: localized_session_timestamp(session.discarded_at),
          status: I18n.t(status_key),
        }
        attributes[:mode] = emergency_mode(session) if surface.to_sym == :org
        attributes
      end

      private

      def emergency_mode(session)
        context = session.authentication_context_value
        mode_type =
          if context.emergency?
            "emergency"
          elsif context.normal?
            "normal"
          else
            "unknown_mode"
          end
        mode_key = "base.shared.identity.sessions.#{mode_type}"
        I18n.t(mode_key)
      end
    end
  end
end

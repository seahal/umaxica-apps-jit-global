# typed: false
# frozen_string_literal: true

module Base
  module Identity
    class ActivityLogPresenter
      include ::SessionTimestampHelper
      RISK_RANKS = { "none" => 0, "low" => 1, "medium" => 2, "high" => 3, "critical" => 4 }.freeze

      def self.client_events
        {
          ClientChronicleEvent::LOGGED_IN => classification("sign_in", "low", "user"),
          ClientChronicleEvent::LOGIN_SUCCESS => classification("sign_in", "low", "user"),
          ClientChronicleEvent::LOGGED_OUT => classification("sign_out", "low", "user"),
          ClientChronicleEvent::LOGOUT => classification("sign_out", "low", "user"),
          ClientChronicleEvent::LOGIN_FAILED => classification("sign_in_failed", "medium", "user_attention"),
          ClientChronicleEvent::AUTHORIZATION_FAILED => classification("sign_in_failed", "medium", "user_attention"),
          ClientChronicleEvent::SIGNED_UP_WITH_GOOGLE => classification("google_account_created", "low", "user"),
          ClientChronicleEvent::SIGNED_UP_WITH_APPLE => classification("apple_account_created", "low", "user"),
          ClientChronicleEvent::SIGNED_UP_WITH_EMAIL => classification("email_account_created", "low", "user"),
          ClientChronicleEvent::SIGNED_UP_WITH_TELEPHONE => classification("telephone_account_created", "low", "user"),
          ClientChronicleEvent::TOKEN_REFRESHED => classification("token_refreshed", "none", "internal"),
          ClientChronicleEvent::STEP_UP_VERIFIED => classification("step_up_completed", "low", "user"),
          ClientChronicleEvent::STEP_UP_FAILED => classification("step_up_failed", "medium", "user_attention"),
          ClientChronicleEvent::SESSION_REVOKED => classification("session_revoked", "low", "user"),
          ClientChronicleEvent::SOCIAL_LINKED => classification("security_change", "medium", "user"),
          ClientChronicleEvent::SOCIAL_UNLINKED => classification("security_change", "medium", "user"),
          ClientChronicleEvent::CREDENTIAL_SECURITY_TRANSITION => classification("security_change", "medium", "user"),
          ClientChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED => classification("session_security_alert", "high", "user_attention"),
        }.freeze
      end
      public_class_method :client_events

      def self.operator_events
        {
          OperatorChronicleEvent::LOGGED_IN => classification("sign_in", "low", "user"),
          OperatorChronicleEvent::LOGIN_SUCCESS => classification("sign_in", "low", "user"),
          OperatorChronicleEvent::LOGGED_OUT => classification("sign_out", "low", "user"),
          OperatorChronicleEvent::LOGOUT => classification("sign_out", "low", "user"),
          OperatorChronicleEvent::LOGIN_FAILED => classification("sign_in_failed", "medium", "user_attention"),
          OperatorChronicleEvent::AUTHORIZATION_FAILED => classification("sign_in_failed", "medium", "user_attention"),
          OperatorChronicleEvent::TOKEN_REFRESHED => classification("token_refreshed", "none", "internal"),
          OperatorChronicleEvent::STEP_UP_VERIFIED => classification("step_up_completed", "low", "user"),
          OperatorChronicleEvent::STEP_UP_FAILED => classification("step_up_failed", "medium", "user_attention"),
          OperatorChronicleEvent::SOCIAL_UNLINKED => classification("security_change", "medium", "user"),
          OperatorChronicleEvent::CREDENTIAL_SECURITY_TRANSITION => classification("security_change", "medium", "user"),
          OperatorChronicleEvent::PASSKEY_REGISTERED => classification("security_change", "medium", "user"),
          OperatorChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED => classification("session_security_alert", "high", "user_attention"),
        }.freeze
      end
      public_class_method :operator_events

      def self.classification(activity_key, risk, visibility)
        { activity_key: activity_key, risk: risk, visibility: visibility }.freeze
      end
      private_class_method :classification

      public

      def initialize(surface:)
        @surface = surface.to_sym
        raise ArgumentError, "unsupported identity activity surface" unless %i(app com org).include?(@surface)
      end

      def visible_event_ids
        classifications.filter_map do |event_id, values|
          event_id if values.fetch(:visibility) != "internal"
        end
      end

      def activities(scope)
        scope.where(event_id: visible_event_ids).recent_activity_first
      end

      def present(activity)
        values = classifications[activity.event_id]
        return if values.nil? || values.fetch(:visibility) == "internal"

        risk = values.fetch(:risk)
        {
          occurred_at: localized_session_timestamp(activity.occurred_at || activity.created_at),
          activity: I18n.t("base.shared.identity.activities.events.#{activity_key(activity, values)}"),
          device: device_summary(activity),
          source: I18n.t("base.shared.identity.activities.unknown_location"),
          risk: I18n.t("base.shared.identity.activities.risks.#{risk}"),
          risk_rank: risk_rank(risk),
        }
      end

      def risk_rank(risk)
        RISK_RANKS.fetch(risk.to_s)
      end

      private

      def classifications
        @classifications ||= @surface == :org ? self.class.operator_events : self.class.client_events
      end

      def activity_key(activity, values)
        return values.fetch(:activity_key) unless values.fetch(:activity_key) == "sign_in"

        provider = context(activity)["provider"].to_s.downcase
        return "google_sign_in" if provider == "google"
        return "apple_sign_in" if provider == "apple"

        values.fetch(:activity_key)
      end

      def device_summary(activity)
        user_agent = context(activity)["user_agent"].to_s
        return I18n.t("base.shared.identity.activities.unknown_device") if user_agent.blank?

        browser = detect_browser(user_agent)
        operating_system = detect_operating_system(user_agent)
        return I18n.t("base.shared.identity.activities.unknown_device") if browser.nil? || operating_system.nil?

        "#{browser} / #{operating_system}"
      end

      def context(activity)
        activity.context.is_a?(Hash) ? activity.context.deep_stringify_keys : {}
      end

      def detect_browser(user_agent)
        return "Edge" if user_agent.include?("Edg/")
        return "Chrome" if user_agent.include?("Chrome/")
        return "Safari" if user_agent.include?("Safari/") && !user_agent.include?("Chrome/")
        return "Firefox" if user_agent.include?("Firefox/")

        nil
      end

      def detect_operating_system(user_agent)
        return "iOS" if user_agent.match?(/iPhone|iPad|iPod/i)
        return "Android" if user_agent.match?(/Android/i)
        return "Windows" if user_agent.match?(/Windows/i)
        return "macOS" if user_agent.match?(/Mac OS X|Macintosh/i)
        return "Linux" if user_agent.match?(/Linux|X11/i)

        nil
      end
    end
  end
end

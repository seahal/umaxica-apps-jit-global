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
          ClientChronicleEvent::PASSKEY_REGISTERED => classification("passkey_registered", "medium", "user"),
          ClientChronicleEvent::PASSKEY_REMOVED => classification("passkey_removed", "medium", "user"),
          ClientChronicleEvent::CREDENTIAL_SECURITY_TRANSITION => classification("security_change", "medium", "user"),
          ClientChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED => classification(
            "session_security_alert", "high",
            "user_attention",
          ),
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
          OperatorChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED => classification(
            "session_security_alert", "high",
            "user_attention",
          ),
        }.freeze
      end
      public_class_method :operator_events

      def self.classification(activity_key, risk, visibility)
        { activity_key: activity_key, risk: risk, visibility: visibility }.freeze
      end
      private_class_method :classification

      APP_PASSKEY_EVENTS = {
        "passkey.registered.signup" => classification("passkey_registered", "medium", "user"),
        "passkey.registered.settings" => classification("passkey_registered", "medium", "user"),
        "passkey.description_changed" => classification("passkey_description_changed", "medium", "user"),
        "passkey.removed" => classification("passkey_removed", "medium", "user"),
      }.freeze

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

      # APP retains the historical ClientChronicle read path while new Passkey lifecycle facts
      # arrive in the common Chronicle store. Both stores are read under the current Client's
      # ownership boundary and are merged only for presentation; no second audit write is made.
      def app_activities(scope, client:, limit: 100)
        validate_activity_limit!(limit)

        legacy = activities(scope).order(id: :desc).limit(limit).to_a
        common = common_app_passkey_activities(client).limit(limit).to_a
        merge_activity_records(legacy, common).first(limit)
      end

      def present(activity)
        values = classification_for(activity)
        return if values.nil? || values.fetch(:visibility) == "internal"

        risk = values.fetch(:risk)
        activity_key_str = "base.shared.identity.activities.events.#{activity_key(activity, values)}"
        risk_key_str = "base.shared.identity.activities.risks.#{risk}"
        {
          occurred_at: localized_session_timestamp(activity.occurred_at),
          activity: I18n.t(activity_key_str),
          device: device_summary(activity),
          source: I18n.t("base.shared.identity.activities.unknown_location"),
          risk: I18n.t(risk_key_str),
          risk_rank: risk_rank(risk),
        }
      end

      def risk_rank(risk)
        RISK_RANKS.fetch(risk.to_s)
      end

      private

      def classification_for(activity)
        if common_chronicle?(activity)
          return nil unless @surface == :app

          APP_PASSKEY_EVENTS[activity.action.to_s]
        else
          classifications[activity.event_id]
        end
      end

      def common_chronicle?(activity)
        activity.is_a?(Chronicle) ||
          (activity.respond_to?(:action) && activity.respond_to?(:metadata) && !activity.respond_to?(:event_id))
      end

      def common_app_passkey_activities(client)
        Chronicle
          .where(action: APP_PASSKEY_EVENTS.keys)
          .where("metadata ->> 'surface' = ?", "app")
          .where("metadata ->> 'actor_ref' = ?", client.public_id.to_s)
          .order(occurred_at: :desc, created_at: :desc, id: :desc)
      end

      def merge_activity_records(legacy, common)
        seen = {}
        (legacy + common).sort_by do |activity|
          [-activity.occurred_at.to_f, -activity.created_at.to_f, -activity.id.to_i]
        end
          .filter do |activity|
            key = activity_identity(activity)
            next false if seen[key]

            seen[key] = true
            true
          end
      end

      def activity_identity(activity)
        if common_chronicle?(activity)
          metadata = activity.metadata.is_a?(Hash) ? activity.metadata.deep_stringify_keys : {}
          external_id = metadata["external_id"].to_s.presence
          if external_id
            operation_ref = activity.respond_to?(:request_id) ? activity.request_id.to_s.presence : nil
            occurrence = activity.occurred_at&.iso8601(6)
            return [:passkey, passkey_event_family(activity.action), external_id, operation_ref || occurrence]
          end

          return [:chronicle, activity.event_uuid.to_s]
        end

        context = activity.context.is_a?(Hash) ? activity.context.deep_stringify_keys : {}
        external_id = context["external_id"].to_s.presence
        if external_id
          operation_ref = context["operation_ref"].to_s.presence
          occurrence = activity.occurred_at&.iso8601(6)
          return [
            :passkey, passkey_event_family(legacy_passkey_action(activity)), external_id, operation_ref || occurrence,
          ]
        end

        [:legacy, activity.id]
      end

      def legacy_passkey_action(activity)
        case activity.event_id
        when ClientChronicleEvent::PASSKEY_REGISTERED then "passkey.registered"
        when ClientChronicleEvent::PASSKEY_REMOVED then "passkey.removed"
        else activity.event_id
        end
      end

      def passkey_event_family(action)
        return "passkey.registered" if action.to_s.start_with?("passkey.registered")
        return "passkey.description_changed" if action.to_s == "passkey.description_changed"
        return "passkey.removed" if action.to_s == "passkey.removed"

        action.to_s
      end

      def validate_activity_limit!(limit)
        return if limit.is_a?(Integer) && limit.positive?

        raise ArgumentError, "activity limit must be a positive integer"
      end

      def classifications
        @classifications ||= (@surface == :org) ? self.class.operator_events : self.class.client_events
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
        return {} if common_chronicle?(activity)

        activity.context.is_a?(Hash) ? activity.context.deep_stringify_keys : {}
      end

      def detect_browser(user_agent)
        return "Edge" if user_agent.include?("Edg/")
        return "Chrome" if user_agent.include?("Chrome/")
        return "Safari" if user_agent.include?("Safari/") && user_agent.exclude?("Chrome/")
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

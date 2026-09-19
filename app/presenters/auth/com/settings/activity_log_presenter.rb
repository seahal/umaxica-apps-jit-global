# frozen_string_literal: true

class Auth::Com::Settings::ActivityLogPresenter
  LOGIN_EVENT_IDS = [ClientChronicleEvent::LOGGED_IN, ClientChronicleEvent::LOGIN_SUCCESS].freeze
  EVENT_LABELS = {
    ClientChronicleEvent::LOGGED_IN => "logged_in",
    ClientChronicleEvent::LOGIN_SUCCESS => "login_success",
  }.freeze
  SENSITIVE_CONTEXT_PATTERNS = %w(user_agent authorization token secret_credential code email telephone phone
                                  otp).freeze

  def initialize(visitor)
    @visitor = visitor
  end

  def activities
    ClientChronicle
      .includes(:user_chronicle_event)
      .where(subject_type: "Visitor", subject_id: visitor.id, event_id: LOGIN_EVENT_IDS)
      .recent_activity_first
  end

  def occurred_at(activity) = activity.occurred_at

  def event_label(activity)
    key = EVENT_LABELS[activity.event_id]
    return I18n.t("auth.com.settings.activity.events.unknown", event_id: activity.event_id) if key.blank?

    translation_key = "auth.com.settings.activity.events.#{key}"
    I18n.t(translation_key)
  end

  def ip_address(activity)
    raw = activity.ip_address.to_s
    return "-" if raw.blank?

    parts = raw.split(".")
    return raw unless parts.size == 4

    "#{parts[0]}.#{parts[1]}.#{parts[2]}.x"
  end

  def context_text(activity)
    context = activity.context
    return "{}" unless context.is_a?(Hash)

    JSON.generate(context.deep_stringify_keys.reject { |key, _| sensitive_context_key?(key) })
  rescue JSON::GeneratorError, TypeError
    "{}"
  end

  def user_agent_summary(activity)
    user_agent = context_value(activity, "user_agent")
    return "-" if user_agent.blank?

    "#{detect_browser(user_agent)} / #{detect_device_type(user_agent)}"
  end

  def login_method(activity)
    method = context_value(activity, "auth_method") || context_value(activity, "method")
    method.present? ? method.to_s : "-"
  end

  private

  attr_reader :visitor

  def sensitive_context_key?(key)
    SENSITIVE_CONTEXT_PATTERNS.any? { |pattern| key.to_s.downcase.include?(pattern) }
  end

  def context_value(activity, key)
    context = activity.context
    return nil unless context.is_a?(Hash)

    context.deep_stringify_keys[key]
  end

  def detect_browser(user_agent)
    ua = user_agent.to_s
    return "Edge" if ua.include?("Edg/")
    return "Chrome" if ua.include?("Chrome/")
    return "Safari" if ua.include?("Safari/") && ua.exclude?("Chrome/")
    return "Firefox" if ua.include?("Firefox/")

    "Other"
  end

  def detect_device_type(user_agent)
    ua = user_agent.to_s
    return "Mobile" if ua.match?(/Mobile|iPhone|Android/i)
    return "Tablet" if ua.match?(/iPad|Tablet/i)

    "Desktop"
  end
end

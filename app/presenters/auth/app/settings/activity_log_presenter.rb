# frozen_string_literal: true

class Auth::App::Settings::ActivityLogPresenter
  VISIBLE_EVENT_IDS = [
    ClientChronicleEvent::LOGGED_IN,
    ClientChronicleEvent::LOGIN_SUCCESS,
    ClientChronicleEvent::LOGGED_OUT,
    ClientChronicleEvent::LOGOUT,
    ClientChronicleEvent::SIGNED_UP_WITH_APPLE,
    ClientChronicleEvent::SIGNED_UP_WITH_EMAIL,
    ClientChronicleEvent::SIGNED_UP_WITH_GOOGLE,
    ClientChronicleEvent::SIGNED_UP_WITH_TELEPHONE,
    ClientChronicleEvent::SOCIAL_LINKED,
    ClientChronicleEvent::SOCIAL_UNLINKED,
    ClientChronicleEvent::SESSION_REVOKED,
    ClientChronicleEvent::EMAIL_REGISTERED,
    ClientChronicleEvent::EMAIL_REMOVED,
    ClientChronicleEvent::TELEPHONE_REGISTERED,
    ClientChronicleEvent::TELEPHONE_REMOVED,
    ClientChronicleEvent::TOTP_ENABLED,
    ClientChronicleEvent::PASSKEY_REGISTERED,
    ClientChronicleEvent::USER_SECRET_CREATED,
    ClientChronicleEvent::RECOVERY_CODES_GENERATED,
  ].freeze
  EVENT_LABELS = {
    ClientChronicleEvent::LOGGED_IN => "logged_in",
    ClientChronicleEvent::LOGIN_SUCCESS => "login_success",
    ClientChronicleEvent::LOGGED_OUT => "logged_out",
    ClientChronicleEvent::LOGOUT => "logout",
    ClientChronicleEvent::SIGNED_UP_WITH_APPLE => "signed_up_with_apple",
    ClientChronicleEvent::SIGNED_UP_WITH_EMAIL => "signed_up_with_email",
    ClientChronicleEvent::SIGNED_UP_WITH_GOOGLE => "signed_up_with_google",
    ClientChronicleEvent::SIGNED_UP_WITH_TELEPHONE => "signed_up_with_telephone",
    ClientChronicleEvent::SOCIAL_LINKED => "social_linked",
    ClientChronicleEvent::SOCIAL_UNLINKED => "social_unlinked",
    ClientChronicleEvent::SESSION_REVOKED => "session_revoked",
    ClientChronicleEvent::EMAIL_REGISTERED => "email_registered",
    ClientChronicleEvent::EMAIL_REMOVED => "email_removed",
    ClientChronicleEvent::TELEPHONE_REGISTERED => "telephone_registered",
    ClientChronicleEvent::TELEPHONE_REMOVED => "telephone_removed",
    ClientChronicleEvent::TOTP_ENABLED => "totp_enabled",
    ClientChronicleEvent::PASSKEY_REGISTERED => "passkey_registered",
    ClientChronicleEvent::USER_SECRET_CREATED => "user_secret_credential_created",
    ClientChronicleEvent::RECOVERY_CODES_GENERATED => "recovery_codes_generated",
  }.freeze
  SENSITIVE_CONTEXT_PATTERNS = %w(user_agent authorization token secret_credential code email telephone phone
                                  otp).freeze

  def initialize(client)
    @client = client
  end

  def activities
    ClientChronicle
      .includes(:user_chronicle_event)
      .where(event_id: VISIBLE_EVENT_IDS)
      .where(subject_or_actor_scope)
      .recent_activity_first
  end

  def occurred_at(activity) = activity.occurred_at

  def event_label(activity)
    key = EVENT_LABELS[activity.event_id]
    return I18n.t("auth.app.settings.activity.events.unknown", event_id: activity.event_id) if key.blank?

    translation_key = "auth.app.settings.activity.events.#{key}"
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
    return "-" if method.blank?

    provider = context_value(activity, "provider")
    return provider.to_s if method.to_s == "social" && provider.present?

    method.to_s
  end

  private

  attr_reader :client

  def subject_or_actor_scope
    table = ClientChronicle.arel_table
    table[:subject_type].eq("Client")
      .and(table[:subject_id].eq(client.id))
      .or(table[:actor_type].eq("Client").and(table[:actor_id].eq(client.id)))
  end

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

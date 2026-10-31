# typed: false
# frozen_string_literal: true

module PreferenceTransport
  extend ActiveSupport::Concern

  private

  def set_preferences_cookie
    case preference_class.name
    when "AppPreference", "OrgPreference"
      set_app_org_preferences_cookie
    when "ComPreference"
      set_com_preferences_cookie
    else
      raise PreferenceBase::ResolutionError, "unsupported anonymous Preference transport"
    end
  end

  def set_app_org_preferences_cookie
    unless request.get? || request.head?
      load_access_token_payload
      load_access_token_preference_record! if @preference_payload.is_a?(Hash)
      @preferences ||= preference_class.new
      return
    end

    load_access_token_payload
    return unless base_or_visa_preference_surface?

    if @preference_payload.is_a?(Hash)
      return if anonymous_realm_display_cookies_match?(@preference_payload)

      repair_anonymous_realm_display_cookies!(@preference_payload)
      return
    end

    clear_anonymous_realm_display_cookies! if anonymous_realm_cookies_present?
  end

  def set_com_preferences_cookie
    if request.get? || request.head?
      access_cookie_present = BrowserCredentialCookie.read(cookies, PreferenceCookieName.anonymous_jwt).present?
      load_access_token_preference_record!
      clear_unusable_preference_access_cookies! if preference_read_cookie_cleanup_needed?(access_cookie_present)
      return
    end

    load_access_token_payload
    load_access_token_preference_record! if @preference_payload.is_a?(Hash)
    @preferences ||= preference_class.new
  end

  def set_read_only_preferences_cookie
    access_cookie_present = BrowserCredentialCookie.read(cookies, PreferenceCookieName.anonymous_jwt).present?
    load_access_token_preference_record!
    clear_unusable_preference_access_cookies! if preference_read_cookie_cleanup_needed?(access_cookie_present)
  end

  def base_or_visa_preference_surface?
    surface = controller_path.to_s.split("/", 3).first
    %w(base visa).include?(surface)
  end

  def anonymous_realm_cookies_present?
    [
      PreferenceCookieName.anonymous_jwt,
      PreferenceIoKeys::Cookies::LANGUAGE,
      PreferenceCookieName.anonymous_experience,
    ].any? { |name| BrowserCredentialCookie.read(cookies, name).present? }
  end

  def anonymous_realm_display_cookies_match?(payload)
    preferences = PreferenceToken.extract_preferences(payload)
    display = PreferenceDisplayValue.new(preferences)
    BrowserCredentialCookie.read(cookies, PreferenceIoKeys::Cookies::LANGUAGE) == display.language &&
      BrowserCredentialCookie.read(cookies, PreferenceCookieName.anonymous_experience) == display.experience
  rescue ArgumentError, KeyError
    false
  end

  def repair_anonymous_realm_display_cookies!(payload)
    preference_class = self.preference_class
    public_id = PreferenceToken.extract_public_id(payload)
    now = nil
    snapshot = Actor::Preference::DEFAULTS.except(:region).transform_keys(&:to_s)
    snapshot["theme"] = PreferenceBase::THEME_OPTION_MAP.fetch(snapshot.fetch("theme"))

    preference_class.connection_class_for_self.connected_to(role: :reading) do
      now = preference_class.database_now
      expires_at = Time.at(payload.fetch("exp")).utc
      if expires_at <= now
        raise PreferenceBase::ResolutionError, "anonymous Preference token expired during display repair"
      end

      if public_id.present?
        preference = preference_class.find_by(
          public_id:, status_id: preference_class::ACTIVE_STATUS_ID,
        )
        if preference&.issuance_active_at?(now:)
          snapshot.merge!(read_anonymous_realm_display_snapshot(preference))
        end
      end

      actor = preference_write_actor if respond_to?(:preference_write_actor, true)
      snapshot.merge!(explicit_actor_preference_snapshot(actor, preference_realm_name)) if actor
    end

    display = PreferenceDisplayValue.new(snapshot)
    options = anonymous_com_cookie_options(expires_at: Time.at(payload.fetch("exp")).utc, httponly: false)
    cookies[PreferenceIoKeys::Cookies::LANGUAGE] = options.merge(value: display.language)
    cookies[PreferenceCookieName.anonymous_experience] = options.merge(value: display.experience)
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
    raise PreferenceBase::ResolutionError, "Preference display repair failed", cause: e
  end

  def read_anonymous_realm_display_snapshot(preference)
    prefix = preference_realm_name.capitalize
    PreferenceWriteBoundary::ANONYMOUS_DISPLAY_TYPES.each_with_object({}) do |type, snapshot|
      record = PreferenceClassRegistry.record_class(prefix, type).find_by(preference_id: preference.id)
      next unless record

      option = PreferenceClassRegistry.option_class(prefix, type).find_by(id: record.option_id)
      value = option&.name
      snapshot[type.to_s] = value if value.is_a?(String) && value.present?
    end
  end

  def clear_anonymous_realm_display_cookies!
    options = anonymous_com_cookie_options(expires_at: nil)
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience,].each do |name|
      cookies.delete(name, **options) if BrowserCredentialCookie.read(cookies, name).present?
    end
  end

  def preference_read_cookie_cleanup_needed?(access_cookie_present)
    return false if preference_credential_detached?
    return false if @preference_payload.present?

    access_cookie_present || cookies[PreferenceIoKeys::Cookies::LANGUAGE].present? ||
      cookies[PreferenceCookieName.anonymous_experience].present?
  end

  def detach_preference_credential!
    @preferences = nil
    @preference_payload = nil
    @preference_credential_detached = true
  end

  def preference_credential_detached?
    @preference_credential_detached == true
  end

  def clear_unusable_preference_access_cookies!
    options = anonymous_com_cookie_options(expires_at: nil)
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience,].each do |name|
      cookies.delete(name, **options) if BrowserCredentialCookie.read(cookies, name).present?
    end
    Rails.logger.info(
      JitLogEvent.format(
        "preference.credential.recovery",
        surface: preference_cookie_surface,
        credential_kind: "anonymous_preference_jwt",
        failure: "missing_or_invalid_access_token",
        category: "credential_rejection",
        outcome: "detached",
        request_id: request.request_id,
      ),
    )
  end
end

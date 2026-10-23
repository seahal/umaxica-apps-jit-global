# typed: false
# frozen_string_literal: true

module PreferenceCookieWriter
  extend ActiveSupport::Concern

  private

  def write_preference_cookie(key, value)
    cookies[key] = preference_cookie_options(
      expires_at: PreferenceBase::REFRESH_TOKEN_TTL.from_now,
      httponly: false,
    ).merge(
      value: value,
    )
  end
end

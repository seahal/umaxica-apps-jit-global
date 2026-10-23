# typed: false
# frozen_string_literal: true

module PreferenceConsentedBuffer
  extend ActiveSupport::Concern

  private

  # Write-only buffer cookie for JS. Rails must not read this cookie.
  def set_preference_consented_buffer!(consented:, expires_at:)
    cookie_options = ::CoreCookieOptions.for(
      request: request,
      # SameSite=Strict: this is a JS-readable projection of the JWT consent state, apex-scoped
      # for cross-subdomain reads within a surface (still same-site). The only cost of Strict is a
      # brief consent-banner flash on the first cross-site inbound hit before a same-site request
      # repopulates it; the source of truth is the JWT, not this buffer.
      same_site: :strict,
      path: "/",
    )

    cookies[PreferenceIoKeys::Cookies::CONSENTED] = {
      **cookie_options,
    }.merge(
      value: consented_cookie_value(consented),
      expires: expires_at,
      httponly: false,
    )
  end

  def consented_cookie_value(consented)
    ActiveModel::Type::Boolean.new.cast(consented) ? "1" : "0"
  end
end

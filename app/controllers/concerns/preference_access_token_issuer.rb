# typed: false
# frozen_string_literal: true

module PreferenceAccessTokenIssuer
  extend ActiveSupport::Concern

  private

  # WU-7 section 4.1: the anonymous com write issues exactly the shared cookie set: the signed
  # preference JWT, the JS-readable `language`, and the JS-readable display JSON (`experience`,
  # everything except language). No item cookies, no refresh, no DBSC. The three share the com
  # domain scope and the 400-day lifetime from the writing clock.
  def prepare_anonymous_com_token(preference, payload, issued_at:)
    unless SecurityJwtPreferenceTokenCodec.valid_display_snapshot?(payload)
      raise PreferenceBase::ResolutionError, "invalid anonymous preference snapshot"
    end

    display = PreferenceDisplayValue.new(payload)

    raise PreferenceBase::ResolutionError, "preference issuance time is required" unless issued_at.acts_like?(:time)

    token = PreferenceToken.encode(
      display.preferences,
      host: request.host, preference_type: preference.class.name,
      public_id: preference.public_id, jti: preference.jti,
      jwt_issuer_id: preference_jwt_issuer_id,
      issued_at: issued_at,
    )
    return if token.blank?

    decoded = PreferenceToken.decode(token, host: request.host, jwt_issuer_id: preference_jwt_issuer_id)
    if decoded.blank?
      Rails.logger.warn(
        JitLogEvent.format(
          "preference.access_token.self_verification_failed",
          host: request.host, jwt_issuer_id: preference_jwt_issuer_id,
          cookie_name: PreferenceCookieName.anonymous_jwt,
        ),
      )
      return nil
    end

    expires_at = Time.at(decoded.fetch("exp")).utc
    validate_anonymous_com_cookie_sizes!(token, display, expires_at)
    PreferenceWriteResult.new(token: token, decoded: decoded, display: display, expires_at: expires_at)
  end

  def validate_anonymous_com_cookie_sizes!(token, display, expires_at)
    cookies_to_issue = [
      [PreferenceCookieName.anonymous_jwt, token, true],
      [PreferenceIoKeys::Cookies::LANGUAGE, display.language, false],
      [PreferenceCookieName.anonymous_experience, display.experience, false],
    ]
    cookies_to_issue.each do |name, value, httponly|
      options = anonymous_com_cookie_options(expires_at: expires_at, httponly: httponly).merge(value: value)
      header = Rack::Utils.set_cookie_header(name, options)
      if header.bytesize > SecurityJwtPreferenceTokenCodec::ANONYMOUS_REALM_TOKEN_MAX_BYTES
        raise PreferenceBase::ResolutionError, "anonymous preference cookie exceeds size limit"
      end
    end
  end

  def emit_anonymous_com_token!(issuance)
    expires_at = issuance.expires_at
    cookies[PreferenceCookieName.anonymous_jwt] = anonymous_com_cookie_options(expires_at: expires_at)
      .merge(value: issuance.token)
    cookies[PreferenceIoKeys::Cookies::LANGUAGE] =
      anonymous_com_cookie_options(expires_at: expires_at, httponly: false).merge(value: issuance.display.language)
    cookies[PreferenceCookieName.anonymous_experience] =
      anonymous_com_cookie_options(expires_at: expires_at, httponly: false).merge(value: issuance.display.experience)

    @preference_payload = issuance.decoded
  end

  def anonymous_com_cookie_options(expires_at:, httponly: true)
    {
      domain: anonymous_com_cookie_domain,
      path: "/",
      secure: true,
      httponly: httponly,
      same_site: :lax,
      expires: expires_at,
    }.compact
  end

  # The realm-shared cookie scope: the registrable two-label domain of the request host. A
  # single-label dev host (localhost) cannot carry a Domain attribute and stays host-only.
  def anonymous_com_cookie_domain
    labels = request.host.to_s.split(".")
    return nil if labels.length < 3

    ".#{labels.last(2).join(".")}"
  end

  def rotate_preference_jti!(preference)
    with_preference_connection(:writing) do
      preference.update!(jti: JitSecurityJwtJtiGenerator.generate)
    end
  end

  def preference_jwt_issuer_id
    "preference_#{preference_realm_name}"
  end
end

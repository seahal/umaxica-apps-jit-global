# typed: false
# frozen_string_literal: true

module AuthenticationCookieStore
  extend ActiveSupport::Concern

  def set_login_auth_cookies(token_record, access_token, refresh_plain, access_expires_at)
    set_auth_cookies(
      access_token: access_token,
      refresh_token: refresh_plain,
      access_expires_at: access_expires_at,
      refresh_expires_at: refresh_cookie_expires_at_for(token_record),
      dbsc_token: dbsc_cookie_value_for(token_record),
      dbsc_expires_at: dbsc_cookie_expires_at_for(token_record),
    )
  end

  private

  def cookie_options
    authentication_cookie_service.auth_cookie_options
  end

  def cookie_deletion_options
    authentication_cookie_service.auth_cookie_deletion_options
  end

  def clear_auth_cookies!
    cookies.delete(AuthenticationBase::ACCESS_COOKIE_KEY, cookie_deletion_options)
    cookies.delete(AuthenticationBase::REFRESH_COOKIE_KEY, cookie_deletion_options)
    clear_dbsc_cookie!
    @current_resource = nil
    @current_session = nil
    @current_session_public_id = nil
    Actor.clear if defined?(Actor)
  end

  def set_auth_cookies(access_token:, refresh_token:, access_expires_at:, refresh_expires_at:,
                       dbsc_token: nil, dbsc_expires_at: nil)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = cookie_options.merge(
      value: access_token,
      expires: access_expires_at,
    )
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = cookie_options.merge(
      value: refresh_token,
      expires: refresh_expires_at,
    )
    set_dbsc_cookie!(dbsc_token, expires_at: dbsc_expires_at) if dbsc_token.present? && dbsc_expires_at.present?
  end

  def set_dbsc_cookie!(token, expires_at:)
    cookies[AuthenticationBase::DBSC_COOKIE_KEY] = cookie_options.merge(
      value: token,
      expires: expires_at,
    )
  end

  def clear_dbsc_cookie!
    cookies.delete(AuthenticationBase::DBSC_COOKIE_KEY, cookie_deletion_options)
  end

  def extract_access_token(cookie_key)
    return nil unless respond_to?(:request, true) && request

    AuthAuthorizationHeader.access_token(request) || BrowserCredentialCookie.read(cookies, cookie_key)
  end

  def set_refresh_auth_cookies(token_record, access_token, refresh_plain, access_expires_at)
    set_auth_cookies(
      access_token: access_token,
      refresh_token: refresh_plain,
      access_expires_at: access_expires_at,
      refresh_expires_at: refresh_cookie_expires_at_for(token_record),
      dbsc_token: dbsc_cookie_value_for(token_record),
      dbsc_expires_at: dbsc_cookie_expires_at_for(token_record),
    )
  end

  def authentication_cookie_service
    @authentication_cookie_service ||= AuthenticationCookieService.new(cookies, request)
  end
end

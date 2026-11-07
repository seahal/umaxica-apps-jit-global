# typed: false
# frozen_string_literal: true

module AuthenticationClient
  extend ActiveSupport::Concern

  include AuthenticationBase

  ACCESS_COOKIE_KEY = AuthenticationBase::ACCESS_COOKIE_KEY
  REFRESH_COOKIE_KEY = AuthenticationBase::REFRESH_COOKIE_KEY
  ACCESS_TOKEN_TTL = AuthenticationBase::ACCESS_TOKEN_TTL
  REFRESH_TOKEN_TTL = AuthenticationBase::REFRESH_TOKEN_TTL
  AUDIT_EVENTS = AuthenticationBase::AUDIT_EVENTS

  def audit_client_login_failed(client)
    record_audit(AUDIT_EVENTS[:login_failed], resource: client, actor: nil) if client
  end

  def current_client = current_resource

  def authenticate_client! = authenticate!

  def logged_in_client? = logged_in?

  def active_client?
    current_client.present? && current_client.active?
  end

  def am_i_client?
    true
  end

  def am_i_staff?
    false
  end

  def am_i_owner?
    false
  end

  private

  def resource_class
    ::Client
  end

  def token_class
    ClientToken
  end

  def audit_class
    ::ClientChronicle
  end

  def resource_type
    "client"
  end

  def resource_foreign_key
    :user_id
  end

  def sign_in_url_with_pt(return_to)
    _ = return_to
    auth_app_sign_in_url(
      host: sign_app_redirect_host,
      protocol: "https",
    )
  end

  def sign_app_redirect_host
    configured_hosts =
      %w(PUBLIC_AUTH_SERVICE_URL).filter_map do |key|
        CommonRedirect.normalize_host(ENV.fetch(key))
      end

    request_host = CommonRedirect.normalize_host(request.host_with_port)
    return request_host if configured_hosts.include?(request_host)

    configured_hosts.first || "auth.app.localhost"
  end
end

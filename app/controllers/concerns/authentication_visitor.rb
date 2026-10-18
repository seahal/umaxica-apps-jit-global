# typed: false
# frozen_string_literal: true

module AuthenticationVisitor
  extend ActiveSupport::Concern

  include AuthenticationBase

  ACCESS_COOKIE_KEY = AuthenticationBase::ACCESS_COOKIE_KEY
  REFRESH_COOKIE_KEY = AuthenticationBase::REFRESH_COOKIE_KEY
  ACCESS_TOKEN_TTL = AuthenticationBase::ACCESS_TOKEN_TTL
  REFRESH_TOKEN_TTL = AuthenticationBase::REFRESH_TOKEN_TTL
  AUDIT_EVENTS = AuthenticationBase::AUDIT_EVENTS

  def audit_visitor_login_failed(visitor)
    record_audit(AUDIT_EVENTS[:login_failed], resource: visitor, actor: nil) if visitor
  end

  def current_visitor = current_resource

  def authenticate_visitor! = authenticate!

  def logged_in_visitor? = logged_in?

  def active_visitor?
    current_visitor.present? && current_visitor.active?
  end

  def am_i_user?
    false
  end

  def am_i_staff?
    false
  end

  def am_i_owner?
    false
  end

  private

  def resource_class
    ::Visitor
  end

  # Where a new sign-in starts after a login cooldown refusal: the surface's
  # Base neutral /sign entry, which issues a fresh admission and ceremony.
  def login_cooldown_restart_url
    base_com_sign_show_url(
      host: Rails.configuration.x.boot_config.fetch(:hosts).base_corporate.host,
      protocol: "https",
    )
  end

  def token_class
    VisitorToken
  end

  def audit_class
    ::ClientChronicle
  end

  def resource_type
    "visitor"
  end

  def resource_foreign_key
    :visitor_id
  end

  def max_sessions_for_resource(resource)
    return VisitorToken::MAX_SESSIONS_PER_VISITOR if resource.is_a?(::Visitor)

    super
  end

  def record_audit(event_id, resource:, actor: resource, context: {})
    return unless resource && event_id

    normalized_event_id =
      case event_id.to_s
      when "LOGGED_IN" then ClientChronicleEvent::LOGGED_IN
      when "LOGGED_OUT" then ClientChronicleEvent::LOGGED_OUT
      when "LOGOUT" then ClientChronicleEvent::LOGOUT
      when "LOGIN_FAILED" then ClientChronicleEvent::LOGIN_FAILED
      when "TOKEN_REFRESHED" then ClientChronicleEvent::TOKEN_REFRESHED
      else event_id
      end

    operation =
      lambda do
        ChronicleRecord.connected_to(role: :writing) do
          ClientChronicle.create!(
            actor_id: actor&.id || 0,
            actor_type: actor&.class&.name || "AuthenticationVisitor",
            subject_id: resource.id.to_s,
            subject_type: "AuthenticationVisitor",
            event_id: normalized_event_id,
            level_id: ClientChronicleLevel::NOTHING,
            ip_address: request_ip_address,
            occurred_at: Time.current,
            context: context.presence || {},
          )
        end
      end
    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        "authentication.visitor.audit_write_failed",
        error_class: e.class.name,
        message: e.message,
      ),
    )
    false
  end

  def sign_in_url_with_pt(return_to)
    _ = return_to
    auth_com_sign_in_url(
      host: auth_com_redirect_host,
      protocol: "https",
    )
  end

  def auth_com_redirect_host
    configured_hosts =
      %w(PRIVATE_AUTH_CORPORATE_URL).filter_map do |key|
        CommonRedirect.normalize_host(ENV.fetch(key))
      end

    request_host = CommonRedirect.normalize_host(request.host_with_port)
    return request_host if configured_hosts.include?(request_host)

    configured_hosts.first || "id.com.localhost"
  end
end

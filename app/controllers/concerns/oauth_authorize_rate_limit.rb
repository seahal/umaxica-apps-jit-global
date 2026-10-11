# typed: false
# frozen_string_literal: true

module OauthAuthorizeRateLimit
  extend ActiveSupport::Concern

  included do
    before_action :enforce_oauth_authorize_rate_limits!, only: :show
  end

  def show
    super
  end

  private

  def enforce_oauth_authorize_rate_limits!
    profile_set = RateLimitProfiles.oauth_authorize

    return if oauth_authorize_rate_limit_request!(
      bucket: "ip_surface",
      profile: profile_set.ip_surface,
      key: oauth_authorize_rate_limit_ip_surface_key,
    )
    return if oauth_authorize_rate_limit_request!(
      bucket: "browser_client",
      profile: profile_set.browser_client,
      key: oauth_authorize_rate_limit_browser_client_key,
    )
    return if oauth_authorize_rate_limit_request!(
      bucket: "client_redirect_host",
      profile: profile_set.client_redirect_host,
      key: oauth_authorize_rate_limit_client_redirect_host_key,
    )

    nil
  end

  def oauth_authorize_rate_limit_request!(bucket:, profile:, key:)
    count = Rails.configuration.x.rate_limit.fetch(:store).increment(key, 1, expires_in: profile.within)
    return true if count.blank? || count <= profile.to

    oauth_authorize_rate_limit_exceeded!(bucket:, profile:, count:)
    false
  end

  def oauth_authorize_rate_limit_exceeded!(bucket:, profile:, count:)
    log_oauth_authorize_rate_limit_event!(
      event: "oidc.authorize.rate_limited",
      bucket: bucket,
      profile: profile,
      count: count,
    )

    render_oauth_authorize_rate_limited(
      bucket: bucket,
      profile: profile,
      _count: count,
    )
  end

  def oauth_authorize_rate_limit_near_limit!(bucket:, profile:, count:)
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.authorize.rate_limit.near_limit",
        mode: "request_window",
        bucket: bucket,
        surface: oauth_authorize_rate_limit_surface,
        client_id: params[:client_id].presence,
        redirect_uri_host: oauth_authorize_rate_limit_redirect_uri_host,
        limit: profile.to,
        period_seconds: profile.within.to_i,
        count: count,
        retry_after_seconds: profile.retry_after,
        request_id: request.request_id,
        flow_kind: params[:result].present? ? "result" : (params[:admission].present? ? "admission" : nil),
      ),
    )
  end

  def log_oauth_authorize_rate_limit_event!(event:, bucket:, profile:, count:)
    near_limit = (profile.to * 0.8).ceil
    oauth_authorize_rate_limit_near_limit!(bucket:, profile:, count:) if count == near_limit

    Rails.logger.info(
      JitLogEvent.format(
        event,
        mode: "request_window",
        bucket: bucket,
        surface: oauth_authorize_rate_limit_surface,
        client_id: params[:client_id].presence,
        redirect_uri_host: oauth_authorize_rate_limit_redirect_uri_host,
        limit: profile.to,
        period_seconds: profile.within.to_i,
        count: count,
        retry_after_seconds: profile.retry_after,
        request_id: request.request_id,
        flow_kind: params[:result].present? ? "result" : (params[:admission].present? ? "admission" : nil),
      ),
    )
  end

  def render_oauth_authorize_rate_limited(bucket:, profile:, _count:)
    response.headers["X-RateLimit-Layer"] = "rails"
    response.headers["X-RateLimit-Rule"] = "oauth_authorize_#{bucket}"
    response.headers["Retry-After"] = profile.retry_after.to_i.to_s

    payload = {
      error: "rate_limited",
      rule: "oauth_authorize_#{bucket}",
      message: I18n.t("errors.rate_limit.exceeded"),
      retry_after: profile.retry_after.to_i,
    }

    respond_to do |format|
      format.json { render json: payload, status: :too_many_requests }
      format.html do
        render plain: payload.fetch(:message),
               content_type: "text/plain",
               status: :too_many_requests
      end
    end
  end

  def oauth_authorize_rate_limit_surface
    self.class.name.deconstantize.underscore.split("/").second
  end

  def oauth_authorize_rate_limit_client_id
    params[:client_id].presence
  end

  def oauth_authorize_rate_limit_redirect_uri_host
    return if params[:redirect_uri].blank?

    URI.parse(params[:redirect_uri].to_s).host
  rescue URI::InvalidURIError
    nil
  end

  def oauth_authorize_rate_limit_ip_surface_key
    [
      "rate-limit",
      "oauth_authorize",
      "ip_surface",
      oauth_authorize_rate_limit_surface,
      request.remote_ip,
    ].join(":")
  end

  def oauth_authorize_rate_limit_browser_client_key
    [
      "rate-limit",
      "oauth_authorize",
      "browser_client",
      oauth_authorize_rate_limit_surface,
      oauth_authorize_rate_limit_browser_key,
      oauth_authorize_rate_limit_client_id || "unknown",
    ].join(":")
  end

  def oauth_authorize_rate_limit_browser_key
    current_session_public_id.presence || session.id.to_s.presence || "anonymous"
  end

  def oauth_authorize_rate_limit_client_redirect_host_key
    [
      "rate-limit",
      "oauth_authorize",
      "client_redirect_host",
      oauth_authorize_rate_limit_surface,
      oauth_authorize_rate_limit_client_id || "unknown",
      oauth_authorize_rate_limit_redirect_uri_host || "unknown",
    ].join(":")
  end
end

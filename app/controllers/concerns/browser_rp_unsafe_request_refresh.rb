# typed: false
# frozen_string_literal: true

# Unsafe Browser RP requests validate browser request provenance and CSRF before
# consulting the refresh authority. A successful refresh then reaches the same
# request's authorization and mutation; there is no 401/resend loop.
module BrowserRpUnsafeRequestRefresh
  extend ActiveSupport::Concern

  included do
    include BrowserRpAuthentication

    prepend_before_action :authenticate_browser_rp_unsafe_request!
  end

  public

  def authenticate_browser_rp_unsafe_request!
    return if request.get? || request.head? || request.options?
    return unless browser_rp_request_safe_for_unsafe_method?
    return if browser_rp_authenticated? || browser_rp_dependency_failed?

    refresh_browser_rp_credentials!
  end

  private

  def browser_rp_request_safe_for_unsafe_method?
    unless browser_rp_fetch_metadata_allowed? && browser_rp_origin_allowed?
      render_browser_rp_unsafe_request_rejected!
      return false
    end
    return true if verified_request_for_forgery_protection?

    render_browser_rp_unsafe_request_rejected!
    false
  end

  def render_browser_rp_unsafe_request_rejected!
    response.set_header("Cache-Control", "no-store")
    render plain: "Invalid browser request", status: :unprocessable_content, content_type: "text/plain"
  end

  def browser_rp_fetch_metadata_allowed?
    fetch_site = request.headers["Sec-Fetch-Site"].to_s.downcase
    return true if fetch_site.blank?

    %w(same-origin same-site).include?(fetch_site)
  end

  def browser_rp_origin_allowed?
    origin = request.origin.to_s
    return false if origin == "null"
    return true if origin.blank?
    return true if origin == request.base_url

    browser_rp_trusted_origins.include?(origin)
  end
end

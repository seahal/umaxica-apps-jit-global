# typed: false
# frozen_string_literal: true

module SignSignupObservability
  extend ActiveSupport::Concern

  private

  def log_sign_signup_event(event_name, payload = {})
    Rails.logger.info(JitLogEvent.format(event_name, **sign_signup_observability_payload.merge(payload)))
  end

  def sign_signup_observability_payload
    {
      surface: sign_signup_observability_surface,
      region: params[:ri],
      flow_id: session[:sign_up_flow_id] ||
        (session[:app_sign_up_flow_locator].is_a?(Hash) && session[:app_sign_up_flow_locator]["public_id"]),
      request_id: sign_signup_request_id,
    }.compact
  end

  def sign_signup_observability_surface
    if respond_to?(:sign_in_surface, true)
      sign_in_surface
    elsif self.class.name.start_with?("Sign::Org::")
      :org
    else
      :app
    end
  end

  def sign_signup_request_flags
    {
      method: request.request_method,
      content_type: request.content_type,
      origin_present: request.headers["Origin"].present?,
      origin_null: request.headers["Origin"] == "null",
      referer_present: request.headers["Referer"].present?,
      csrf_token_present: request.headers["X-CSRF-Token"].present? || params[:authenticity_token].present?,
      turnstile_token_present: params["cf-turnstile-response"].present?,
      turbo_frame_request: request.headers["Turbo-Frame"].present?,
      xhr: request.xhr?,
    }.compact
  end

  def sign_signup_request_id
    request.respond_to?(:request_id) ? request.request_id : nil
  end
end

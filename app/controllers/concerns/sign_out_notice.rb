# typed: false
# frozen_string_literal: true

module SignOutNotice
  extend ActiveSupport::Concern

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    helper_method :sign_out_active_context_present?,
                  :sign_out_confirmation_form_path,
                  :sign_out_home_path,
                  :sign_out_completed_description,
                  :sign_out_post_path
  end

  SIGN_OUT_NOTICE_SESSION_KEY = :sign_out_notice
  SIGN_OUT_NOTICE_TTL = 5.minutes
  SIGN_OUT_NOTICE_CACHE_CONTROL = "no-store, no-cache, must-revalidate, private"
  SIGN_OUT_REFERRER_POLICY = "no-referrer"

  private

  def prepare_sign_out_completion_notice!(state: nil)
    @sign_out_actor_ref = current_resource.try(:public_id) if respond_to?(:current_resource, true)
    @sign_out_session_public_id = current_session_public_id if respond_to?(:current_session_public_id, true)
    @sign_out_state = state
  end

  def issue_sign_out_notice!
    payload = sign_out_notice_payload
    notice_id = Valkey::AuthState::SignOutNoticeStore.new.issue!(payload: payload)
    # The browser cookie carries only an opaque random capability. The presentation payload lives
    # in the dedicated auth-state namespace so two concurrent GETs cannot both render completion.
    session[SIGN_OUT_NOTICE_SESSION_KEY] = notice_id
    @sign_out_notice = sign_out_notice_from_session(payload)
  end

  def consume_sign_out_notice
    notice_id = session[SIGN_OUT_NOTICE_SESSION_KEY]
    session.delete(SIGN_OUT_NOTICE_SESSION_KEY)
    return unless notice_id.is_a?(String) && notice_id.present?

    notice = Valkey::AuthState::SignOutNoticeStore.new.consume(raw_id: notice_id)
    return unless notice

    sign_out_notice_from_session(notice)
  rescue Umaxica::Valkey::Error
    # A presentation marker is deliberately fail-closed. The authority state has already been
    # handled by the logout transaction; a store outage must not manufacture a completion page.
    nil
  end

  def sign_out_active_context_present?
    return true if current_resource.present?

    session_token = safe_current_session_for_logout if respond_to?(:safe_current_session_for_logout, true)
    return true if session_token&.currently_usable?
    return true if respond_to?(:oidc_logout_pending_request_present?, true) && oidc_logout_pending_request_present?

    false
  end

  def sign_out_route_helper_prefix
    controller_path.split("/").first(2).join("_")
  end

  def sign_out_route_params
    params.slice(:ri).permit(:ri).to_h.symbolize_keys
  end

  def sign_out_edit_path(**options)
    public_send("edit_#{sign_out_route_helper_prefix}_sign_out_path", **sign_out_route_params, **options.compact)
  end

  def sign_out_post_path(**options)
    public_send("#{sign_out_route_helper_prefix}_sign_out_path", **sign_out_route_params, **options.compact)
  end

  def sign_out_home_path(**options)
    public_send("#{sign_out_route_helper_prefix}_root_path", **sign_out_route_params, **options.compact)
  end

  def sign_out_confirmation_form_path
    sign_out_post_path
  end

  def sign_out_notice_cache_headers!
    response.headers["Cache-Control"] = SIGN_OUT_NOTICE_CACHE_CONTROL
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    response.headers["Referrer-Policy"] = SIGN_OUT_REFERRER_POLICY
  end

  # A lost commit response is neither a successful nor a failed sign-out. Keep the response
  # uncached and say that the result is unknown while the caller reports the indeterminate state in
  # the structured sign-out event.
  def render_sign_out_indeterminate!
    response.headers["Cache-Control"] = SIGN_OUT_NOTICE_CACHE_CONTROL
    response.headers["Referrer-Policy"] = SIGN_OUT_REFERRER_POLICY
    # The session may already be revoked. Clearing the history of a session that survived only
    # costs a server round trip on Back, so the unknown outcome takes the signed-out side.
    session[:inertia_clear_history] = true
    if respond_to?(:render_oidc_rp_logout_indeterminate, true)
      render_oidc_rp_logout_indeterminate
    else
      render "auth/shared/sign_outs/indeterminate", status: :service_unavailable, layout: false
    end
  end

  # REQ-008: completion wording states the global result only. It never states an end time, and an
  # origin whose own cleanup did not finish says so without calling the sign-out a failure.
  def sign_out_completed_description
    return t("sign.shared.sign_out.cleanup_incomplete_description") if @sign_out_cleanup_incomplete

    t("sign.shared.sign_out.completed_description")
  end

  def parse_sign_out_notice_time(value)
    Time.zone.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def sign_out_notice_payload
    expires_at = SIGN_OUT_NOTICE_TTL.from_now
    payload = {
      "actor_ref" => @sign_out_actor_ref.presence,
      "face" => controller_path.split("/").second,
      "sid" => @sign_out_session_public_id.presence,
      "expires_at" => expires_at.iso8601,
      "state" => @sign_out_state,
    }

    payload.compact
  end

  def sign_out_notice_from_session(payload)
    expires_at = parse_sign_out_notice_time(payload["expires_at"])
    return if expires_at.blank? || expires_at <= Time.current

    {
      expires_at: expires_at,
      session_public_id: payload["sid"].presence,
      state: payload["state"].presence,
      actor_ref: payload["actor_ref"].presence,
      face: payload["face"].presence,
    }
  end
end

# typed: false
# frozen_string_literal: true

module SignOutNotice
  extend ActiveSupport::Concern

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
  SIGN_OUT_HANDOFF_REFERRER_POLICY = "strict-origin-when-cross-origin"

  private

  def prepare_sign_out_completion_notice!(state: nil)
    @sign_out_access_expires_at = current_sign_out_access_expires_at
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

  def sign_out_completion_notice_present?
    session[SIGN_OUT_NOTICE_SESSION_KEY].is_a?(String)
  end

  def sign_out_active_context_present?
    return true if current_resource.present? || current_session_public_id.present?
    return true if respond_to?(:safe_current_session_for_logout, true) && safe_current_session_for_logout.present?
    return true if respond_to?(:oidc_logout_pending_request_present?, true) && oidc_logout_pending_request_present?
    return true if respond_to?(:params, true) && params[:logout_challenge].present?

    false
  end

  def sign_out_route_helper_prefix
    controller_path.split("/").first(2).join("_")
  end

  def sign_out_route_params
    # These two are the only params that belong in a sign-out route. `permit` alone would
    # report every other param on the request as unpermitted - and the request legitimately
    # carries others (client_id, logout_request) - so narrow the set first, then permit.
    params.slice(:ri, :logout_challenge).permit(:ri, :logout_challenge).to_h.symbolize_keys
  end

  def sign_out_new_path(**options)
    public_send("new_#{sign_out_route_helper_prefix}_sign_out_path", **sign_out_route_params, **options.compact)
  end

  def sign_out_new_url(**options)
    public_send("new_#{sign_out_route_helper_prefix}_sign_out_url", **sign_out_route_params, **options.compact)
  end

  def sign_out_edit_path(**options)
    public_send("edit_#{sign_out_route_helper_prefix}_sign_out_path", **sign_out_route_params, **options.compact)
  end

  def sign_out_edit_url(**options)
    public_send("edit_#{sign_out_route_helper_prefix}_sign_out_url", **sign_out_route_params, **options.compact)
  end

  def sign_out_post_path(**options)
    public_send("#{sign_out_route_helper_prefix}_sign_out_path", **sign_out_route_params, **options.compact)
  end

  def sign_out_post_url(**options)
    public_send("#{sign_out_route_helper_prefix}_sign_out_url", **sign_out_route_params, **options.compact)
  end

  def sign_out_complete_path(**options)
    public_send("#{sign_out_route_helper_prefix}_sign_out_path", **sign_out_route_params, **options.compact)
  end

  def sign_out_complete_url(**options)
    public_send("#{sign_out_route_helper_prefix}_sign_out_url", **sign_out_route_params, **options.compact)
  end

  def sign_out_home_path(**options)
    public_send("#{sign_out_route_helper_prefix}_root_path", **sign_out_route_params, **options.compact)
  end

  def sign_out_home_url(**options)
    public_send("#{sign_out_route_helper_prefix}_root_url", **sign_out_route_params, **options.compact)
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

  def sign_out_handoff_cache_headers!
    sign_out_notice_cache_headers!
    response.headers["Referrer-Policy"] = SIGN_OUT_HANDOFF_REFERRER_POLICY
  end

  def render_sign_out_handoff(template)
    sign_out_handoff_cache_headers!
    log_sign_out_event(
      "auth.sign_out.cross_origin_handoff.rendered",
      user_confirmation_required: false,
      auto_handoff: true,
      cleanup_performed: false,
      result: "rendered",
    )
    render template, layout: false
  end

  def render_cross_origin_sign_out_handoff(target_url:, transaction:)
    @sign_out_handoff_url = target_url
    @logout_transaction = transaction

    render_sign_out_handoff("sign/shared/sign_outs/handoff")
  end

  # Cross-host sign-out cleanup cannot carry a same-origin Rails CSRF token after
  # one surface has already cleared its own session. The one-shot logout challenge
  # is the proof for these coordination posts; fetch metadata is still checked
  # separately before any local cleanup runs.
  def verified_request?
    coordinated_sign_out_challenge_verifies_request? || super
  end

  def verify_coordinated_sign_out_post!(trusted_origins:)
    return unless request.post? && params[:logout_challenge].present?

    sec_fetch_site = request.headers["Sec-Fetch-Site"].to_s.downcase.presence
    origin = request.origin.to_s.presence

    trusted_origin_match = origin.present? && trusted_origins.include?(origin)
    challenge_verified = coordinated_sign_out_challenge_verifies_request?
    allowed_fetch_site = %w(same-origin same-site).include?(sec_fetch_site)
    allowed_origin = origin.blank? || trusted_origin_match || (origin == "null" && challenge_verified)

    unless allowed_fetch_site && allowed_origin
      warn_sign_out_event(
        "auth.sign_out.fetch_metadata.rejected",
        sec_fetch_site: sec_fetch_site,
        origin_host: origin_host_for_sign_out_log(origin),
        trusted_origin_match: trusted_origin_match,
        result: "rejected",
        reason: fetch_metadata_rejection_reason(sec_fetch_site, allowed_origin),
      )
      render "auth/shared/sign_outs/unavailable", status: :forbidden, layout: false
    end

    log_sign_out_event(
      "auth.sign_out.fetch_metadata.accepted",
      sec_fetch_site: sec_fetch_site,
      origin_host: origin_host_for_sign_out_log(origin),
      trusted_origin_match: trusted_origin_match,
      result: "accepted",
    )
  end

  def coordinated_sign_out_challenge_verifies_request?
    return false unless request.post? && params[:logout_challenge].present?

    transaction = coordinated_sign_out_challenge_transaction
    return false unless transaction
    return false if transaction.expired?
    return false if transaction.finalized? || transaction.failed?

    transaction.expected_step.present?
  end

  def coordinated_sign_out_challenge_transaction
    return @coordinated_sign_out_challenge_transaction if defined?(@coordinated_sign_out_challenge_transaction)

    @coordinated_sign_out_challenge_transaction =
      AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: params.expect(:logout_challenge))
  rescue ActiveRecord::RecordNotFound, ArgumentError, ActionController::BadRequest
    @coordinated_sign_out_challenge_transaction = nil
  end

  def log_sign_out_event(event_name, transaction: nil, **payload)
    Rails.logger.info(JitLogEvent.format(event_name, sign_out_log_payload(transaction: transaction, **payload)))
  end

  def warn_sign_out_event(event_name, transaction: nil, **payload)
    Rails.logger.warn(JitLogEvent.format(event_name, sign_out_log_payload(transaction: transaction, **payload)))
  end

  def sign_out_log_payload(transaction: nil, **payload)
    transaction ||= @logout_transaction if defined?(@logout_transaction)
    {
      request_id: request.request_id,
      transaction_public_id: transaction&.public_id,
      origin_surface: transaction&.origin_surface || logout_origin_surface_for_logs,
      current_surface: logout_origin_surface_for_logs,
      next_surface: sign_out_next_surface_for_logs(transaction),
      region: params[:ri].presence,
      step_before: transaction&.expected_step,
      step_after: payload.delete(:step_after),
      challenge_present: params[:logout_challenge].present?,
      challenge_valid: payload.delete(:challenge_valid),
      sec_fetch_site: payload.delete(:sec_fetch_site),
      origin_host: payload.delete(:origin_host),
      trusted_origin_match: payload.delete(:trusted_origin_match),
      user_confirmation_required: payload.delete(:user_confirmation_required),
      auto_handoff: payload.delete(:auto_handoff),
      cleanup_performed: payload.delete(:cleanup_performed),
      redirect_target_surface: payload.delete(:redirect_target_surface),
      result: payload.delete(:result),
      reason: payload.delete(:reason),
    }.merge(payload).compact
  end

  def logout_origin_surface_for_logs
    controller_path.split("/").first
  end

  def sign_out_next_surface_for_logs(transaction)
    return unless transaction

    case transaction.expected_step
    when AcmeLogoutTransaction::STEP_ACME_CLEARED then "acme"
    when AcmeLogoutTransaction::STEP_SIGN_CLEARED then "sign"
    when AcmeLogoutTransaction::STEP_FINALIZED then transaction.origin_surface
    end
  end

  def origin_host_for_sign_out_log(origin)
    URI.parse(origin).host if origin.present?
  rescue URI::InvalidURIError
    "invalid"
  end

  def fetch_metadata_rejection_reason(sec_fetch_site, allowed_origin)
    return "missing_sec_fetch_site" if sec_fetch_site.blank?
    return "invalid_sec_fetch_site" unless %w(same-origin same-site).include?(sec_fetch_site)
    return "untrusted_origin" unless allowed_origin

    "invalid_request"
  end

  def sign_out_completed_description
    access_expires_at = @sign_out_access_expires_at || @sign_out_notice&.fetch("access_expires_at", nil)
    return if access_expires_at.blank?

    t(
      "sign.shared.sign_out.completed_description",
      expires_at: l(access_expires_at, format: :short),
    )
  end

  def current_sign_out_access_expires_at
    access_expires_at_from_claims(Actor.authn.access_claims) ||
      access_expires_at_from_current_cookie
  end

  def access_expires_at_from_current_cookie
    return unless respond_to?(:extract_access_token, true)
    return if request&.host.blank?
    return unless respond_to?(:resource_type, true)

    token = extract_access_token(AuthenticationBase::ACCESS_COOKIE_KEY)
    return if token.blank?

    payload = AuthenticationTokenService.decode_allow_expired(
      token,
      host: request.host,
      resource_type: resource_type,
      jwt_issuer_id: auth_jwt_issuer_id_for_sign_out_notice,
    )
    access_expires_at_from_claims(payload)
  end

  def auth_jwt_issuer_id_for_sign_out_notice
    auth_jwt_issuer_id if respond_to?(:auth_jwt_issuer_id, true)
  end

  def access_expires_at_from_claims(claims)
    exp = claims&.dig("exp")
    return if exp.blank?

    Time.zone.at(Integer(exp))
  rescue ArgumentError, TypeError
    nil
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
      "access_expires_at" => @sign_out_access_expires_at&.iso8601,
      "state" => @sign_out_state,
    }

    payload.compact
  end

  def sign_out_notice_from_session(payload)
    expires_at = parse_sign_out_notice_time(payload["expires_at"])
    return if expires_at.blank? || expires_at <= Time.current

    access_expires_at = parse_sign_out_notice_time(payload["access_expires_at"])
    {
      expires_at: expires_at,
      access_expires_at: access_expires_at,
      session_public_id: payload["sid"].presence,
      state: payload["state"].presence,
      actor_ref: payload["actor_ref"].presence,
      face: payload["face"].presence,
    }
  end
end

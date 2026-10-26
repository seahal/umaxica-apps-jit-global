# typed: false
# frozen_string_literal: true

module SignOidcLogout
  extend ActiveSupport::Concern

  OIDC_LOGOUT_REQUEST_SESSION_KEY = :oidc_logout_request

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    after_action :sign_out_notice_cache_headers!, only: %i(show create)
  end

  public

  def show
    handle_oidc_end_session_request
  end

  def create
    handle_oidc_end_session_request
  end

  private

  def confirm_oidc_end_session_logout
    pending_request = oidc_logout_pending_request
    return render_oidc_end_session_failure unless pending_request

    perform_oidc_end_session_logout(pending_request)
  end

  def handle_oidc_end_session_request
    return head(:bad_request) if params[:logout_challenge].present?

    @oidc_end_session_request = OidcEndSessionRequest.call(params: params, request: request)
    return render_oidc_end_session_error(@oidc_end_session_request) if @oidc_end_session_request.error?

    # A verified hint without the captured IdP session identifies an RP's requested target, but it
    # does not authorize this browser to mutate anything. Stop before storing a pending request or
    # redirecting to an origin: the IdP-session-absent contract is a plain error with no state
    # change (REQ-009 / DEC-074).
    if @oidc_end_session_request.source == OidcEndSessionRequest::SOURCE_ID_TOKEN_HINT &&
        @oidc_end_session_request.requires_confirmation?
      return render_oidc_end_session_session_missing_error
    end

    if oidc_logout_pending_request_present?
      return render_oidc_end_session_confirmation
    end

    session_public_id = current_session_public_id
    return render_oidc_end_session_confirmation if session_public_id.blank?

    store_oidc_logout_request!(@oidc_end_session_request, session_public_id:)
    if @oidc_end_session_request.post_logout_redirect_uri.present?
      return redirect_to(sign_out_edit_path, status: :see_other)
    end

    render_oidc_end_session_confirmation
  end

  def perform_oidc_end_session_logout(result)
    prepare_sign_out_completion_notice!
    logout_oidc_current_session!(result)
    issue_sign_out_notice!
    session[OpLogoutReceiptSession::KEY] = @op_logout_receipt_session if @op_logout_receipt_session

    if result.post_logout_redirect_uri.present?
      redirect_to_jump_url(post_logout_redirect_uri_with_state(result), status: :see_other)
    else
      redirect_to(
        oidc_logout_completed_path(ri: result.legacy_ri || params[:ri]),
        status: :see_other,
      )
    end
  end

  def render_oidc_logout_completion
    @sign_out_notice = consume_sign_out_notice
    render oidc_logout_completion_template, status: :ok
  end

  def render_oidc_end_session_confirmation
    render :show, status: :ok
  end

  def oidc_logout_completion_template
    :show
  end

  def render_oidc_end_session_error(result)
    if request.format.json?
      render json: { error: result.error_code, error_description: result.error_description },
             status: :bad_request
    elsif result.error_description.to_s.start_with?("id_token_hint ") &&
        result.error_description.to_s.end_with?("does not match current session")
      render_oidc_end_session_session_error
    else
      render_oidc_logout_completion
    end
  end

  def render_oidc_end_session_session_missing_error
    render_oidc_end_session_session_error(
      error_code: "login_required",
      error_description: I18n.t("sign.shared.sign_out.idp_session_error"),
    )
  end

  def render_oidc_end_session_session_error(error_code: "invalid_request", error_description: nil)
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    response.headers["Referrer-Policy"] = SignOutNotice::SIGN_OUT_REFERRER_POLICY
    description = error_description.presence || I18n.t("sign.shared.sign_out.idp_session_error")

    if request.format.json?
      render json: { error: error_code, error_description: description }, status: :bad_request
    else
      render plain: description, status: :bad_request
    end
  end

  def render_oidc_end_session_failure
    if request.format.json?
      render json: { error: "unprocessable_content", error_description: "logout completion is stale" },
             status: :unprocessable_content
    else
      render_oidc_logout_completion
    end
  end

  def oidc_logout_pending_request_present?
    session.key?(OIDC_LOGOUT_REQUEST_SESSION_KEY)
  end

  OidcLogoutPendingRequest = Struct.new(
    :client_id, :subject, :sid, :post_logout_redirect_uri, :state, :ui_locales, :legacy_ri,
    :expires_at,
    keyword_init: true,
  )

  def oidc_logout_pending_request
    payload = session[OIDC_LOGOUT_REQUEST_SESSION_KEY]
    return unless payload.is_a?(Hash)

    expires_at = parse_oidc_logout_request_time(payload["expires_at"])
    return unless expires_at.present? && expires_at > Time.current

    OidcLogoutPendingRequest.new(**payload.symbolize_keys)
  end

  def store_oidc_logout_request!(result, session_public_id:)
    session[OIDC_LOGOUT_REQUEST_SESSION_KEY] = oidc_logout_request_payload(result, session_public_id:)
  end

  def oidc_logout_request_payload(result, session_public_id:)
    {
      "client_id" => result.client_id,
      "subject" => result.subject,
      "sid" => result.sid.presence || session_public_id,
      "post_logout_redirect_uri" => result.post_logout_redirect_uri,
      "state" => result.state,
      "ui_locales" => result.ui_locales,
      "legacy_ri" => result.legacy_ri,
      "expires_at" => 5.minutes.from_now.iso8601,
    }.compact
  end

  def parse_oidc_logout_request_time(value)
    Time.zone.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def logout_oidc_current_session!(result)
    begin
      resource = current_resource if respond_to?(:current_resource, true)
      session_public_id = result.sid.presence || current_session_public_id
      token_record = oidc_current_session_token(session_public_id)
      browser_binding = SecureRandom.urlsafe_base64(32)
      logout = AuthenticationLogoutCurrentSession.new(
        current: Actor,
        resource: resource,
        token: token_record,
        token_class: token_class,
        session_public_id: session_public_id,
        reason: "oidc_rp_initiated_logout",
        cause: "rp_initiated_logout",
        browser_binding: browser_binding,
      )
      logout.call
      stop_result = logout.stop_results.first
      if stop_result&.stop && stop_result.receipt_nonce
        @op_logout_receipt_session = {
          "realm" => sign_surface_name,
          "stop" => stop_result.stop.public_id,
          "nonce" => stop_result.receipt_nonce,
          "browser_binding" => browser_binding,
        }
      end
      record_logout_audit(resource) if respond_to?(:record_logout_audit, true)
    ensure
      clear_auth_cookies! if respond_to?(:clear_auth_cookies!, true)
      Actor.clear if defined?(Actor)
      reset_session_and_clear_inertia_history!
    end
  end

  def oidc_current_session_token(session_public_id)
    return if session_public_id.blank?

    token_class.includes(:device_session).find_by(public_id: session_public_id) ||
      oidc_current_session_token_by_device_session(session_public_id) ||
      oidc_current_session_token_by_sid(session_public_id)
  end

  def oidc_current_session_token_by_device_session(session_public_id)
    return unless token_class.column_names.include?("device_session_id")

    device_session = token_class.reflect_on_association(:device_session)
      &.klass&.active&.find_by(public_id: session_public_id)
    return if device_session.blank?

    token_class.currently_usable_at.where(device_session_id: device_session.id).order(created_at: :desc).first
  end

  def oidc_current_session_token_by_sid(session_public_id)
    return unless token_class.column_names.include?("oidc_sid")

    token_class.includes(:device_session).find_by(oidc_sid: session_public_id)
  end

  def sign_out_confirmation_form_path
    case sign_surface_name
    when "app" then visa_app_oidc_logout_confirmation_path(ri: params[:ri])
    when "com" then visa_com_oidc_logout_confirmation_path(ri: params[:ri])
    when "org" then visa_org_oidc_logout_confirmation_path(ri: params[:ri])
    else raise ArgumentError, "unsupported Visa logout surface: #{sign_surface_name.inspect}"
    end
  end

  def post_logout_redirect_uri_with_state(result)
    return result.post_logout_redirect_uri if result.state.blank?

    uri = URI.parse(result.post_logout_redirect_uri)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    query["state"] = result.state
    uri.query = query.to_query
    uri.to_s
  end

  def sign_surface_name
    controller_path.split("/").second
  end
end

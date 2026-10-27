# typed: false
# frozen_string_literal: true

module SignOidcLogout
  extend ActiveSupport::Concern

  OIDC_LOGOUT_REQUEST_SESSION_KEY = :oidc_logout_request
  OIDC_LOGOUT_COMPLETED_SESSION_KEY = :oidc_logout_completed
  OIDC_LOGOUT_REALMS = {
    "app" => { device: ClientDeviceSession, grant: OpAppGrant, root: :client_token, resource_type: "client" },
    "com" => { device: VisitorDeviceSession, grant: OpComGrant, root: :visitor_token, resource_type: "visitor" },
    "org" => { device: OperatorDeviceSession, grant: OpOrgGrant, root: :operator_token, resource_type: "operator" },
  }.freeze

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
    unless pending_request
      if session[OIDC_LOGOUT_COMPLETED_SESSION_KEY] == true && current_session_public_id.blank?
        clear_oidc_logout_browser!
        return render_oidc_already_signed_out
      end
      return render_oidc_end_session_failure
    end

    device_class = oidc_logout_realm.fetch(:device)
    device =
      device_class.connection_class_for_self.connected_to(role: :writing) do
        device_class.find_by(public_id: pending_request.device_session_public_id)
      end
    return render_oidc_end_session_failure unless device

    current_root = current_session
    current_device = current_root&.device_session_record
    return render_oidc_end_session_forbidden if current_device && current_device.id != device.id

    if device.revoked?
      clear_oidc_logout_browser!
      return render_oidc_already_signed_out
    end
    return render_oidc_end_session_forbidden unless current_device && current_device.id == device.id

    perform_oidc_end_session_logout(pending_request, device: device, root: current_root)
  end

  def handle_oidc_end_session_request
    return head(:bad_request) if params[:logout_challenge].present?

    @oidc_end_session_request = OidcEndSessionRequest.call(params: params, request: request)
    return render_oidc_end_session_error(@oidc_end_session_request) if @oidc_end_session_request.error?

    device = current_session&.device_session_record
    hinted = @oidc_end_session_request.source == OidcEndSessionRequest::SOURCE_ID_TOKEN_HINT
    return render_oidc_end_session_forbidden if hinted && !device&.usable?
    return render_oidc_already_signed_out unless device&.usable?

    grant = oidc_logout_hint_grant(@oidc_end_session_request, device) if hinted
    return render_oidc_end_session_forbidden if hinted && !grant

    pending = oidc_logout_pending_request
    if pending
      return render_oidc_end_session_forbidden unless pending.device_session_public_id == device.public_id

      return render_oidc_end_session_confirmation
    end

    store_oidc_logout_request!(@oidc_end_session_request, device: device, grant: grant)
    if @oidc_end_session_request.post_logout_redirect_uri.present?
      return redirect_to(sign_out_edit_path, status: :see_other)
    end

    render_oidc_end_session_confirmation
  end

  # Errors the authority stop can raise from storage or from its own refusal. Anything else is a
  # programming error and propagates.
  OIDC_LOGOUT_STOP_ERRORS = [ActiveRecord::ActiveRecordError, OpAuthorityStopCommitter::Refused].freeze

  def perform_oidc_end_session_logout(result, device:, root:)
    prepare_sign_out_completion_notice!
    resource = current_resource
    precondition_failed = false
    begin
      logout = AuthenticationLogoutCurrentSession.new(
        current: Actor, resource: resource, token: root, token_class: token_class,
        session_public_id: device.public_id, reason: "oidc_rp_initiated_logout", cause: "rp_initiated_logout",
        cascade_device_session_tokens: true,
        precondition: -> { device.reload.usable? && device.public_id == result.device_session_public_id },
      )
      logout.call
      record_logout_audit(resource)
    rescue AuthenticationLogoutCurrentSession::CommitOutcomeUnknown => e
      log_oidc_logout_failure("commit_unknown", e)
      return render_sign_out_indeterminate!
    rescue AuthenticationLogoutCurrentSession::PreconditionFailed => e
      log_oidc_logout_failure("precondition_failed", e)
      precondition_failed = true
    rescue ActiveRecord::ActiveRecordError, OpAuthorityStopCommitter::Refused, PG::Error => e
      log_oidc_logout_failure("stop_failed", e)
    end

    case persisted_oidc_device_state(device)
    when :revoked
      if precondition_failed
        clear_oidc_logout_browser!
        return render_oidc_already_signed_out
      end
      finish_oidc_committed_logout(result)
    when :active
      precondition_failed ? render_oidc_end_session_forbidden : render_oidc_stop_failure
    when :unknown
      render_sign_out_indeterminate!
    else
      raise RuntimeError, "unexpected logout device state"
    end
  end

  def finish_oidc_committed_logout(result)
    clear_oidc_logout_browser!
    if result.grant_public_id.present? && result.post_logout_redirect_uri.present?
      redirect_to_jump_url(post_logout_redirect_uri_with_state(result), strict: true, status: :see_other)
    else
      issue_sign_out_notice!
      redirect_to(oidc_logout_completed_path(ri: result.legacy_ri || params[:ri]), status: :see_other)
    end
  rescue ActiveRecord::ActiveRecordError, PG::Error, Umaxica::Valkey::Error,
         CommonRedirect::JumpRedirectFailure, JumpRtConfigurationError => e
    log_oidc_logout_failure("committed_presentation_failed", e)
    render_oidc_signed_out
  end

  def clear_oidc_logout_browser!
    clear_auth_cookies!
    Actor.clear
    reset_session_and_clear_inertia_history!
    session[OIDC_LOGOUT_COMPLETED_SESSION_KEY] = true
  end

  def persisted_oidc_device_state(device)
    device.class.connection_class_for_self.connected_to(role: :writing) do
      persisted = device.class.find_by(id: device.id)
      raise ActiveRecord::RecordNotFound, "logout device no longer exists" unless persisted

      persisted.revoked? ? :revoked : :active
    end
  rescue ActiveRecord::ActiveRecordError => e
    log_oidc_logout_failure("device_state_unreadable", e)
    :unknown
  end

  def render_oidc_stop_failure
    render_oidc_logout_result_page(
      title: I18n.t("sign.shared.sign_out.unavailable_title"),
      description: I18n.t("sign.shared.sign_out.unavailable_description"),
      status: :internal_server_error,
    )
  end

  def log_oidc_logout_failure(outcome, error)
    Rails.logger.warn(
      JitLogEvent.format(
        "oidc.logout", realm: sign_surface_name, outcome: outcome,
                       error_class: error.class.name,
      ),
    )
  end

  def render_oidc_logout_completion
    @sign_out_notice = consume_sign_out_notice
    render oidc_logout_completion_template, status: :ok
  end

  def render_oidc_end_session_confirmation
    render :show, status: :ok
  end

  def render_oidc_already_signed_out
    render_oidc_logout_result_page(
      title: I18n.t("sign.shared.sign_out.completed_title"),
      description: I18n.t("sign.shared.sign_out.already_signed_out"),
      status: :ok,
    )
  end

  def oidc_logout_completion_template
    :show
  end

  def render_oidc_end_session_error(result)
    Rails.logger.warn(
      JitLogEvent.format(
        "oidc.logout.request_refused", realm: sign_surface_name, error: result.error_code,
                                       error_description: result.error_description,
      ),
    )
    if request.format.json?
      render json: { error: result.error_code, error_description: result.error_description },
             status: :bad_request
    else
      Rails.logger.info(
        JitLogEvent.format(
          "oidc.logout", realm: sign_surface_name, outcome: "invalid_request", error_code: result.error_code,
        ),
      )
      render plain: I18n.t("sign.shared.sign_out.invalid_request"), status: :bad_request
    end
  end

  def render_oidc_end_session_forbidden
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    response.headers["Referrer-Policy"] = SignOutNotice::SIGN_OUT_REFERRER_POLICY
    render plain: I18n.t("sign.shared.sign_out.forbidden_description"), status: :forbidden
  end

  def render_oidc_end_session_failure
    if request.format.json?
      render json: { error: "unprocessable_content", error_description: "logout completion is stale" },
             status: :unprocessable_content
    else
      render plain: I18n.t("sign.shared.sign_out.stale_description"), status: :unprocessable_content
    end
  end

  def oidc_logout_pending_request_present?
    session.key?(OIDC_LOGOUT_REQUEST_SESSION_KEY)
  end

  OidcLogoutPendingRequest = Struct.new(
    :client_id, :device_session_public_id, :grant_public_id, :post_logout_redirect_uri, :state, :ui_locales, :legacy_ri,
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

  def store_oidc_logout_request!(result, device:, grant:)
    session.delete(OIDC_LOGOUT_COMPLETED_SESSION_KEY)
    session[OIDC_LOGOUT_REQUEST_SESSION_KEY] = oidc_logout_request_payload(result, device: device, grant: grant)
  end

  def oidc_logout_request_payload(result, device:, grant:)
    {
      "client_id" => result.client_id,
      "device_session_public_id" => device.public_id,
      "grant_public_id" => grant&.public_id,
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

  def oidc_logout_realm
    OIDC_LOGOUT_REALMS.fetch(sign_surface_name)
  end

  def oidc_logout_hint_grant(result, device)
    realm = oidc_logout_realm
    grant_class = realm.fetch(:grant)
    grant =
      grant_class.connection_class_for_self.connected_to(role: :writing) do
        grant_class.includes(realm.fetch(:root)).find_by(public_id: result.sid, oidc_client_id: result.client_id)
      end
    root = grant&.public_send(realm.fetch(:root))
    return unless root && root.device_session_id == device.id
    return unless result.subject == OidcSubject.for(root.actor_record, resource_type: realm.fetch(:resource_type))

    grant
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

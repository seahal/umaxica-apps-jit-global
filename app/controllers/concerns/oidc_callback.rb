# typed: false
# frozen_string_literal: true

require "digest"

module OidcCallback
  extend ActiveSupport::Concern

  InvalidCallbackState = Class.new(StandardError)
  OIDC_PENDING_FLOWS_SESSION_KEY = "oidc_pending_flows"
  OIDC_PENDING_FLOW_TTL = 10.minutes

  def show
    response.set_header("Cache-Control", "no-store")
    validate_state!
    token_result = exchange_code!
    return render_callback_failure(token_result.error) unless token_result.success?

    id_token_result = verify_id_token!(token_result.token_response[:id_token])
    return render_callback_failure(id_token_result.error) unless id_token_result.success?

    resource = provision_rp_account_from_id_token!(id_token_result)
    login_result =
      ActiveRecord::Base.connected_to(role: :writing) do
        log_in(
          resource, token_kind_id: "BROWSER_WEB", require_totp_check: false,
                    audit_context: { oidc_client_id: oidc_client_id },
                    skip_login_cooldown: true,
        )
      end
    return render_oidc_session_limit_hard_reject(login_result) if login_result[:status] == :session_limit_hard_reject

    if login_result[:session_management_required]
      bind_oidc_rp_logout_session!(id_token_result.payload)
      return redirect_to(oidc_session_management_path, allow_other_host: false)
    end

    return render_callback_failure("login_failed") unless login_result[:status] == :success

    bind_oidc_rp_logout_session!(id_token_result.payload)

    redirect_to(consume_oidc_pt, allow_other_host: false)
  rescue InvalidCallbackState => e
    log_invalid_callback_state!(e.message)
    clear_oidc_session_state!(pending_flows: e.message == "OIDC state mismatch")
    render plain: I18n.t("errors.messages.login_required"), status: :unprocessable_content
  end

  private

  def validate_state!
    actual = params[:state].to_s
    @current_oidc_flow, @current_oidc_flow_expired = consume_oidc_pending_flow(actual)
    raise InvalidCallbackState, "OIDC state expired" if @current_oidc_flow_expired

    clear_legacy_oidc_flow_if_current!(actual) if @current_oidc_flow.present?
    expected = @current_oidc_flow.present? ? actual : session.delete(:oidc_state).to_s
    @oidc_invalid_state_context = oidc_invalid_state_context(expected: expected, actual: actual)
    unless expected.present? && actual.present? && expected.bytesize == actual.bytesize &&
        ActiveSupport::SecurityUtils.secure_compare(expected, actual)
      raise InvalidCallbackState, "OIDC state mismatch"
    end

    @oidc_invalid_state_context = nil
  end

  def exchange_code!
    code_verifier = oidc_flow_value("code_verifier") || session.delete(:oidc_code_verifier)
    raise InvalidCallbackState, "OIDC PKCE verifier missing" if code_verifier.blank?

    token_url = oidc_token_url
    OidcRpTokenClient.call(
      token_url: token_url,
      client_id: oidc_client_id,
      client_secret: oidc_client_secret,
      code: params[:code],
      redirect_uri: oidc_callback_url,
      code_verifier: code_verifier,
      require_https: oidc_token_endpoint_requires_https?(token_url),
    )
  end

  def oidc_token_endpoint_requires_https?(token_url)
    return true unless Rails.env.local?

    uri = URI.parse(token_url)
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    allowed_hosts =
      [hosts.base_service.host, hosts.base_corporate.host, hosts.base_staff.host]
        .map { |host| host.to_s.downcase }
    local_port = Integer(ENV.fetch("PORT"), exception: false) || 3000

    !(
      uri.scheme == "http" &&
      allowed_hosts.include?(uri.host.to_s.downcase) &&
      uri.port == local_port &&
      uri.path == "/oauth/token" &&
      uri.userinfo.blank? && uri.query.blank? && uri.fragment.blank?
    )
  rescue URI::InvalidURIError
    true
  end

  def verify_id_token!(id_token)
    OidcIdTokenVerifier.call(
      id_token: id_token,
      client_id: oidc_client_id,
      resource_type: oidc_resource_type,
      expected_nonce: oidc_flow_value("nonce") || session.delete(:oidc_nonce),
      issuer: OidcIssuer.for_resource_type(oidc_resource_type),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(oidc_resource_type),
    )
  end

  def oidc_client_secret
    oidc_client&.client_secret
  end

  def consume_oidc_pt
    pending_pt = oidc_flow_value("pt").presence
    legacy_pt = session.delete(:oidc_pt).presence
    pt = pending_pt || legacy_pt || "/"
    log_oidc_callback_return_to(
      pt: pt,
      source: pending_pt.present? ? "pending_flow" : legacy_pt.present? ? "legacy" : "default",
    )
    pt
  end

  def session_limit_gate_pt
    oidc_flow_value("pt").presence || session[:oidc_pt].presence ||
      (defined?(super) ? super : request&.fullpath.presence || request&.path.presence || "/")
  rescue StandardError
    "/"
  end

  def render_oidc_session_limit_hard_reject(login_result)
    if respond_to?(:render_session_limit_hard_reject, true)
      return render_session_limit_hard_reject(
        message: login_result[:message],
        http_status: login_result[:http_status],
      )
    end

    render plain: login_result[:message].presence || I18n.t("session_limit.login_limit_exceeded"),
           status: login_result[:http_status].presence || :forbidden
  end

  def oidc_session_management_path
    return session_management_path if respond_to?(:session_management_path, true)
    return sign_app_sign_in_session_path if respond_to?(:sign_app_sign_in_session_path, true)
    return sign_org_sign_in_session_path if respond_to?(:sign_org_sign_in_session_path, true)
    return sign_com_sign_in_session_path if respond_to?(:sign_com_sign_in_session_path, true)

    "/sign/in/session"
  end

  def render_callback_failure(error)
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.rp.callback.failed",
        error: error,
        client_id: oidc_client_id,
        host: request.host,
      ),
    )
    clear_oidc_session_state!
    redirect_to(sign_in_url_with_pt(nil), allow_other_host: true)
  end

  def log_invalid_callback_state!(reason)
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.rp.callback.invalid_state",
        reason: reason,
        client_id: oidc_client_id,
        host: request.host,
        grant_present: params[:code].present?,
        csrf_present: params[:state].present?,
        **(@oidc_invalid_state_context || {}),
      ),
    )
  end

  def oidc_invalid_state_context(expected:, actual:)
    {
      expected_state_present: expected.present?,
      actual_state_present: actual.present?,
      expected_state_digest12: oidc_state_digest12(expected),
      actual_state_digest12: oidc_state_digest12(actual),
      code_verifier_present: oidc_flow_value("code_verifier").present? || session[:oidc_code_verifier].present?,
      nonce_present: oidc_flow_value("nonce").present? || session[:oidc_nonce].present?,
      pt_present: oidc_flow_value("pt").present? || session[:oidc_pt].present?,
    }
  end

  def oidc_state_digest12(value)
    return nil if value.blank?

    Digest::SHA256.hexdigest(value.to_s).first(12)
  end

  def log_oidc_callback_return_to(pt:, source:)
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.rp.callback.return_to",
        client_id: oidc_client_id,
        host: request.host,
        source: source,
        pt_digest12: oidc_state_digest12(pt),
        pt_is_root: pt == "/",
        pending_flow_present: @current_oidc_flow.present?,
      ),
    )
  end

  def clear_oidc_session_state!(pending_flows: false)
    session.delete(:oidc_code_verifier)
    session.delete(:oidc_state)
    session.delete(:oidc_nonce)
    session.delete(:oidc_pt)
    session.delete(OIDC_PENDING_FLOWS_SESSION_KEY) if pending_flows
  end

  def consume_oidc_pending_flow(state)
    return nil if state.blank?

    flows = session[OIDC_PENDING_FLOWS_SESSION_KEY]
    return nil unless flows.is_a?(Hash)

    flow = flows[state]
    return [nil, false] unless flow.is_a?(Hash)

    created_at = Time.at(flow["created_at"].to_i).utc
    if created_at.blank? || created_at + OIDC_PENDING_FLOW_TTL < Time.current.utc
      flows.delete(state)
      store_oidc_pending_flows!(flows)
      return [nil, true]
    end

    flows.delete(state)
    store_oidc_pending_flows!(flows)
    [flow, false]
  end

  def store_oidc_pending_flows!(flows)
    if flows.empty?
      session.delete(OIDC_PENDING_FLOWS_SESSION_KEY)
    else
      session[OIDC_PENDING_FLOWS_SESSION_KEY] = flows
    end
  end

  def oidc_flow_value(key)
    @current_oidc_flow&.[](key)
  end

  def clear_legacy_oidc_flow_if_current!(state)
    return unless session[:oidc_state].to_s == state

    session.delete(:oidc_code_verifier)
    session.delete(:oidc_state)
    session.delete(:oidc_nonce)
    session.delete(:oidc_pt)
  end

  def bind_oidc_rp_logout_session!(payload)
    sid = payload["sid"].to_s
    return unless oidc_callback_uuid_identifier?(sid)

    token_record = @current_session
    return unless token_record&.respond_to?(:update_columns)

    updates = {}
    updates[:oidc_sid] = sid if token_record.has_attribute?(:oidc_sid)
    updates[:oidc_client_id] = oidc_client_id if token_record.has_attribute?(:oidc_client_id)
    return if updates.blank?

    token_record_connection_owner(token_record.class).connected_to(role: :writing) do
      token_record.update!(**updates)
    end
  end

  def oidc_resource_type
    return rp_actor_resource_type if respond_to?(:rp_actor_resource_type, true)

    OidcIssuer.resource_type_for_client(oidc_client)
  end

  def oidc_callback_uuid_identifier?(value)
    /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i.match?(
      value.to_s,
    )
  end

  def oidc_client
    @oidc_client ||= OidcClientRegistry.find!(oidc_client_id)
  end

  def oidc_client_id
    raise NotImplementedError, "controller must define oidc_client_id"
  end

  def provision_rp_account_from_id_token!(verification_result)
    payload = verification_result.respond_to?(:payload) ? verification_result.payload : verification_result
    canonical_audience =
      if verification_result.respond_to?(:canonical_audience)
        verification_result.canonical_audience
      else
        oidc_client_id
      end

    provision_rp_account_from_id_token_payload!(payload, canonical_audience)
  end

  def provision_rp_account_from_id_token_payload!(_payload, _canonical_audience)
    raise NotImplementedError, "controller must provision RP account"
  end
end

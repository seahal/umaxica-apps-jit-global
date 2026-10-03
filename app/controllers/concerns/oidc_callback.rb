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
    validate_authorization_response_issuer!
    token_result = exchange_code!
    return render_callback_failure(token_result.error) unless token_result.success?

    id_token_result = verify_id_token!(token_result.token_response[:id_token])
    return render_callback_failure(id_token_result.error) unless id_token_result.success?

    authentication_event_at = authentication_event_at_from_id_token(id_token_result.payload)
    return render_callback_failure("authentication_time_missing") if authentication_event_at.blank?

    resource = provision_rp_account_from_id_token!(id_token_result)
    if oidc_rp_credentials_only?
      store_oidc_rp_credentials!(token_result.token_response)
      return redirect_to(consume_oidc_pt, allow_other_host: false)
    end

    # The RP's local session derives from a root login Base already
    # established; it is an RP session, so it neither checks nor moves the
    # root-login cooldown anchor.
    login_result =
      ActiveRecord::Base.connected_to(role: :writing) do
        log_in(
          resource, establishment: :rp_session, token_kind_id: "BROWSER_WEB", require_totp_check: false,
                    audit_context: { oidc_client_id: oidc_client_id },
                    authentication_event_at: authentication_event_at,
        )
      end
    # No restricted session is issued at a full limit; the RP refuses.
    if %i(session_limit_hard_reject session_limit_pending).include?(login_result[:status])
      return render_oidc_session_limit_hard_reject(login_result.reverse_merge(http_status: :forbidden))
    end

    return render_callback_failure("login_failed") unless login_result[:status] == :success

    bind_oidc_rp_logout_session!(id_token_result.payload)

    redirect_to(consume_oidc_pt, allow_other_host: false)
  rescue InvalidCallbackState => e
    log_invalid_callback_state!(e.message)
    # A rejected callback must not destroy unrelated state-indexed browser-tab flows. The
    # matching flow is consumed atomically before exchange; an invalid or missing state consumes
    # nothing.
    clear_oidc_session_state!
    render plain: I18n.t("errors.messages.login_required"), status: :unprocessable_content
  end

  private

  def validate_state!
    actual = params[:state].to_s
    @current_oidc_flow, @current_oidc_flow_expired = consume_oidc_pending_flow(actual)
    raise InvalidCallbackState, "OIDC state expired" if @current_oidc_flow_expired

    expected = @current_oidc_flow.present? ? actual : nil
    @oidc_invalid_state_context = oidc_invalid_state_context(expected: expected, actual: actual)
    unless expected.present? && actual.present? && expected.bytesize == actual.bytesize &&
        ActiveSupport::SecurityUtils.secure_compare(expected, actual)
      raise InvalidCallbackState, "OIDC state mismatch"
    end

    @oidc_invalid_state_context = nil
  end

  def exchange_code!
    code_verifier = oidc_flow_value("code_verifier")
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

  def validate_authorization_response_issuer!
    actual = params[:iss].to_s
    expected = OidcIssuer.for_resource_type(oidc_resource_type).to_s
    valid = actual.present? && actual.bytesize == expected.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(actual, expected)
    return if valid

    raise InvalidCallbackState, "OIDC issuer mismatch"
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

  def oidc_rp_credentials_only?
    false
  end

  def store_oidc_rp_credentials!(token_response)
    access_token, refresh_token = OidcRpBrowserCredentialContract.require_token_response!(token_response)
    access_expires_at = OidcRpBrowserCredentialContract.access_expires_at(access_token)

    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      OidcRpBrowserCredentialContract.access_cookie_options(expires_at: access_expires_at).merge(
        value: access_token,
      )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] =
      OidcRpBrowserCredentialContract.refresh_cookie_options.merge(value: refresh_token)
  end

  def verify_id_token!(id_token)
    OidcIdTokenVerifier.call(
      id_token: id_token,
      client_id: oidc_client_id,
      resource_type: oidc_resource_type,
      expected_nonce: oidc_flow_value("nonce"),
      expected_max_age: oidc_flow_value("max_age"),
      issuer: OidcIssuer.for_resource_type(oidc_resource_type),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(oidc_resource_type),
    )
  end

  def authentication_event_at_from_id_token(payload)
    raw = payload&.fetch("auth_time", nil)
    return if raw.blank?

    value = raw.is_a?(Numeric) ? raw : Integer(raw, 10)
    authentication_time = Time.at(value).utc
    return if authentication_time > Time.current.utc + AuthenticationJwtConfiguration.leeway_seconds

    authentication_time
  rescue ArgumentError, RangeError, TypeError
    nil
  end

  def oidc_client_secret
    oidc_client&.client_secret
  end

  def consume_oidc_pt
    pending_pt = oidc_flow_value("pt").presence
    pt = pending_pt || "/"
    log_oidc_callback_return_to(
      pt: pt,
      source: pending_pt.present? ? "pending_flow" : "default",
    )
    pt
  end

  def session_limit_gate_pt
    oidc_flow_value("pt").presence ||
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
    redirect_to_oidc_authorization_url(sign_in_url_with_pt(nil))
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
      expected_value_present: expected.present?,
      actual_value_present: actual.present?,
      expected_value_digest12: oidc_state_digest12(expected),
      actual_value_digest12: oidc_state_digest12(actual),
      code_verifier_present: oidc_flow_value("code_verifier").present?,
      nonce_present: oidc_flow_value("nonce").present?,
      pt_present: oidc_flow_value("pt").present?,
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
    session.delete(:oidc_max_age)
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

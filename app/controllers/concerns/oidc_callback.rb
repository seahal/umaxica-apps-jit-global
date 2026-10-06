# typed: false
# frozen_string_literal: true

module OidcCallback
  extend ActiveSupport::Concern

  InvalidCallbackState =
    Class.new(StandardError) do
      attr_reader :reason

      def initialize(message, reason: "state_invalid")
        @reason = reason
        super(message)
      end
    end
  OIDC_PENDING_FLOWS_SESSION_KEY = "oidc_pending_flows"
  OIDC_PENDING_FLOW_TTL = 10.minutes

  # The callback is intentionally kept as one linear public boundary so the
  # verification order remains visible beside the D-59 contract.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Lint/NoReturnInBeginEndBlocks
  def show
    response.set_header("Cache-Control", "no-store")
    begin
      validate_state!
      validate_authorization_response_issuer!
    rescue InvalidCallbackState => e
      log_invalid_callback_state!(e)
      clear_oidc_session_state!
      return render_callback_failure(e.reason)
    end

    return render_callback_failure("authorization_error") if params[:error].present?
    return render_callback_failure("authorization_error") if params[:code].blank?

    token_result =
      begin
        exchange_code!
      rescue InvalidCallbackState => e
        log_invalid_callback_state!(e)
        clear_oidc_session_state!
        return render_callback_failure(e.reason)
      end
    unless token_result.success?
      return render_callback_failure(
        token_exchange_failure_reason(token_result.error),
        status: token_exchange_failure_status(token_result.error),
      )
    end

    token_response = token_result.token_response
    return render_callback_failure("token_response_invalid") unless token_response_complete?(token_response)

    id_token_result = verify_id_token!(token_response_value(token_response, :id_token))
    return render_callback_failure("id_token_invalid") unless id_token_result.success?

    authentication_event_at = authentication_event_at_from_id_token(id_token_result.payload)
    return render_callback_failure("id_token_invalid") if authentication_event_at.blank?

    authoritative_resource =
      begin
        verified_access_token_resource_for_callback(token_response)
      rescue ActiveRecord::RecordNotFound, ArgumentError, KeyError
        return render_callback_failure("access_token_invalid")
      rescue ActiveRecord::ActiveRecordError
        return render_callback_failure("dependency_unavailable", status: :service_unavailable)
      end

    userinfo_result = verified_userinfo_claims_for_callback(token_response)
    if userinfo_result
      if userinfo_result.dependency_failure?
        return render_callback_failure("dependency_unavailable", status: :service_unavailable)
      end
      return render_callback_failure("userinfo_failed") unless userinfo_result.success?
      return render_callback_failure("subject_mismatch") unless callback_subject_matches_userinfo?(
        id_token_result,
        userinfo_result,
      )
    end

    resource =
      begin
        provision_rp_account_from_id_token!(
          id_token_result,
          authoritative_resource: authoritative_resource,
        )
      rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, ArgumentError, KeyError
        return render_callback_failure("identity_resolution_failed")
      rescue ActiveRecord::ActiveRecordError
        return render_callback_failure("dependency_unavailable", status: :service_unavailable)
      end
    if oidc_rp_credentials_only?
      store_oidc_rp_credentials!(token_response)
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

    return render_callback_failure("identity_resolution_failed") unless login_result[:status] == :success

    bind_oidc_rp_logout_session!(id_token_result.payload)

    redirect_to(consume_oidc_pt, allow_other_host: false)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Lint/NoReturnInBeginEndBlocks

  private

  def validate_state!
    actual = params[:state].to_s
    @current_oidc_flow, @current_oidc_flow_expired = consume_oidc_pending_flow(actual)
    raise InvalidCallbackState.new("OIDC state expired", reason: "state_invalid") if @current_oidc_flow_expired

    expected = @current_oidc_flow.present? ? actual : nil
    unless expected.present? && actual.present? && expected.bytesize == actual.bytesize &&
        ActiveSupport::SecurityUtils.secure_compare(expected, actual)
      raise InvalidCallbackState.new("OIDC state mismatch", reason: "state_invalid")
    end
  end

  def exchange_code!
    code_verifier = oidc_flow_value("code_verifier")
    raise InvalidCallbackState.new("OIDC PKCE verifier missing", reason: "state_invalid") if code_verifier.blank?

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

    raise InvalidCallbackState.new("OIDC issuer mismatch", reason: "issuer_invalid")
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

  def oidc_userinfo_endpoint_requires_https?(userinfo_url)
    return true unless Rails.env.local?

    uri = URI.parse(userinfo_url)
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    allowed_hosts =
      [hosts.base_service.host, hosts.base_corporate.host, hosts.base_staff.host]
        .map { |host| host.to_s.downcase }
    local_port = Integer(ENV.fetch("PORT"), exception: false) || 3000

    !(
      uri.scheme == "http" &&
      allowed_hosts.include?(uri.host.to_s.downcase) &&
      uri.port == local_port &&
      uri.path == "/oauth/userinfo" &&
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
    expiries = OidcRpBrowserCredentialContract.cookie_expiries_from_response(token_response)

    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      OidcRpBrowserCredentialContract.access_cookie_options(expires_at: expiries.fetch(:access_expires_at)).merge(
        value: access_token,
      )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] =
      OidcRpBrowserCredentialContract.refresh_cookie_options(expires_at: expiries.fetch(:refresh_expires_at)).merge(
        value: refresh_token,
      )
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
    pending_pt || "/"
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

  def render_callback_failure(reason, status: :unprocessable_content)
    log_callback_failure(reason: reason, status: status)
    clear_oidc_session_state!
    render plain: I18n.t("errors.messages.login_required"), content_type: "text/plain", status: status
  end

  def log_invalid_callback_state!(failure)
    log_callback_failure(reason: failure.reason, status: :unprocessable_content)
  end

  def log_callback_failure(reason:, status:)
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.rp.callback.failed",
        surface: oidc_callback_log_surface,
        face: oidc_callback_log_face,
        client_id: oidc_client_id,
        request_id: request.request_id,
        status: Rack::Utils.status_code(status),
        reason: reason,
      ),
    )
  end

  def oidc_callback_log_surface
    case oidc_client_id
    when "base-app-ww", "core-app", "warp-app", "app-ios-rp", "app-android-rp" then "app"
    when "base-com-ww", "core-com", "warp-com" then "com"
    when "base-org-ww", "core-org", "edit-org", "warp-org" then "org"
    else "unknown"
    end
  end

  def oidc_callback_log_face
    case oidc_client_id
    when "base-app-ww", "core-app", "warp-app", "app-ios-rp", "app-android-rp" then "app"
    when "base-com-ww", "core-com", "warp-com" then "com"
    when "base-org-ww", "core-org", "edit-org", "warp-org" then "org"
    else "unknown"
    end
  end

  def token_response_complete?(token_response)
    return false unless token_response.is_a?(Hash)

    required = %i(access_token id_token)
    if oidc_rp_credentials_only?
      required << :refresh_token
      required.concat(%i(expires_in refresh_token_expires_in))
    end
    required.all? { |key| token_response[key].presence || token_response[key.to_s].presence }
  end

  def token_response_value(token_response, key)
    token_response[key] || token_response[key.to_s]
  end

  def token_exchange_failure_reason(error)
    %w(token_exchange_failed server_error temporarily_unavailable dependency_unavailable).include?(error.to_s) ?
      "dependency_unavailable" : "token_exchange_failed"
  end

  def token_exchange_failure_status(error)
    (token_exchange_failure_reason(error) == "dependency_unavailable") ? :service_unavailable : :unprocessable_content
  end

  def callback_subject_matches_userinfo?(id_token_result, userinfo_result)
    expected = id_token_result.payload.to_h["sub"].to_s
    actual = userinfo_result.claims.to_h["sub"].to_s
    return false if expected.blank? || actual.blank? || expected.bytesize != actual.bytesize

    ActiveSupport::SecurityUtils.secure_compare(expected, actual)
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

  def provision_rp_account_from_id_token!(verification_result, authoritative_resource: nil)
    payload = verification_result.respond_to?(:payload) ? verification_result.payload : verification_result
    canonical_audience =
      if verification_result.respond_to?(:canonical_audience)
        verification_result.canonical_audience
      else
        oidc_client_id
      end

    provision_rp_account_from_id_token_payload!(
      payload,
      canonical_audience,
      authoritative_resource: authoritative_resource,
    )
  end

  def provision_rp_account_from_id_token_payload!(_payload, _canonical_audience, authoritative_resource: nil)
    raise ArgumentError, "unused authoritative resource" if authoritative_resource

    raise NotImplementedError, "controller must provision RP account"
  end

  def verified_access_token_resource_for_callback(_token_response)
    nil
  end

  def verified_userinfo_claims_for_callback(_token_response)
    nil
  end
end

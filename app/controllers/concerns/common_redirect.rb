# typed: false
# frozen_string_literal: true

module CommonRedirect
  extend ActiveSupport::Concern

  def self.normalize_host(val)
    return nil if val.blank?

    str = val.to_s.strip
    begin
      uri = URI.parse(str)
      host = uri.host.presence || str.split("/").first
    rescue URI::InvalidURIError
      host = str
    end
    # strip scheme remnants and spaces
    host.to_s.downcase.sub(%r{^https?://}i, "").split("/").first
  end

  def allowed_hosts
    # NOTE: External redirect is disabled. This list remains only for diagnostics/auditing.
    keys = %w(CORPORATE_URL SERVICE_URL STAFF_URL NETWORK_URL DEV_URL)
    keys.filter_map { |key| CommonRedirect.normalize_host(ENV[key]) }
  end

  private

  def redirect_to_surface_url(url, preserve_query_keys: [], **)
    uri = URI.parse(url.to_s)
    if uri.host.nil?
      redirect_to(url, allow_other_host: false, **)
    elsif uri.is_a?(URI::HTTP) && uri.host == request.host && uri.userinfo.blank?
      redirect_to(uri.request_uri, allow_other_host: false, **)
    else
      redirect_to_jump_url(url, preserve_query_keys: preserve_query_keys, **)
    end
  rescue URI::InvalidURIError
    render plain: I18n.t("errors.messages.invalid_request"), status: :unprocessable_content
  end

  def redirect_to_jump_url(
    url,
    namespace: jump_rt_issuer_namespace,
    dst: "internal",
    replay_policy: "reuse",
    preserve_query_keys: [],
    fallback_internal: false,
    **
  )
    preserve_query_keys |= safe_jump_preserved_query_keys(url)
    token = JumpRtIssuer.call(
      namespace: namespace,
      url: url,
      dst: dst,
      replay_policy: replay_policy,
      preserve_query_keys: preserve_query_keys,
    )
    if token.present?
      log_jump_rt_issued(token: token, namespace: namespace, dst: dst, replay_policy: replay_policy, url: url)
      result = RedirectsJumpGatewayUrl.call(token)
      return redirect_to(result.value, allow_other_host: true, **) if result.ok?

      fallback_path = safe_return_path(url) if fallback_internal
      if fallback_path.present?
        log_jump_rt_fallback_internal(
          namespace: namespace, dst: dst, replay_policy: replay_policy, url: url,
          reason: :gateway_url_failed, gateway_failure: result.failure_reason,
        )
        return redirect_to(fallback_path, allow_other_host: false, **)
      end

      log_redirect_target_failure(result)
      return render plain: I18n.t("errors.messages.invalid_request"),
                    status: :unprocessable_content
    end

    fallback_path = safe_return_path(url) if fallback_internal
    if fallback_path.present?
      log_jump_rt_fallback_internal(
        namespace: namespace, dst: dst, replay_policy: replay_policy, url: url,
        reason: :issuance_failed,
      )
      return redirect_to(fallback_path, allow_other_host: false, **)
    end

    result = RedirectsTargetResult.failure(
      kind: :external, source: :jump_rt_issue, reason: :invalid_jump_rt_url,
      unsafe_value: url,
    )
    log_redirect_target_failure(result)
    render plain: I18n.t("errors.messages.invalid_request"),
           status: :unprocessable_content
  end

  def safe_jump_preserved_query_keys(url)
    uri = URI.parse(url.to_s)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    return [] unless uri.is_a?(URI::HTTP)
    return [] unless uri.path == "/oauth/authorize"
    return [] unless oidc_authorize_host_allowed?(uri.host)
    return [] unless defined?(OidcClientRegistry)
    return [] unless OidcClientRegistry.valid_redirect_uri?(query["client_id"], query["redirect_uri"])

    ["redirect_uri"]
  rescue URI::InvalidURIError,
         Rack::Utils::ParameterTypeError,
         Rack::Utils::InvalidParameterError,
         Rack::Utils::ParamsTooDeepError
    []
  end

  def oidc_authorize_host_allowed?(host)
    allowed_hosts =
      %w(
        PUBLIC_AUTH_SERVICE_URL PRIVATE_AUTH_CORPORATE_URL PRIVATE_AUTH_STAFF_URL
        PUBLIC_BASE_SERVICE_URL PUBLIC_BASE_CORPORATE_URL PUBLIC_BASE_STAFF_URL
      ).filter_map do |key|
        Oidc::AcmeServiceOrigin.host_from(ENV.fetch(key)) || CommonRedirect.normalize_host(ENV.fetch(key))
      end
    allowed_hosts += %w(
      auth.app.localhost auth.com.localhost auth.org.localhost
      base.app.localhost base.com.localhost base.org.localhost
    )
    allowed_hosts.include?(CommonRedirect.normalize_host(host))
  end

  def safe_redirect_to(target, fallback: "/", **)
    result = RedirectsPathTargetResolver.call(target, source: :legacy_safe_redirect)
    safe_path = result.value if result.ok?
    log_redirect_target_failure(result) unless result.ok? || target.blank?

    if safe_path
      redirect_to(safe_path, allow_other_host: false, **)
    else
      redirect_to(fallback, allow_other_host: false, **)
    end
  end

  def safe_redirect_back_or_to(fallback, **)
    result = RedirectsPathTargetResolver.call(request.referer, source: :referer)
    safe_path = result.value if result.ok?
    redirect_to(safe_path || fallback, allow_other_host: false, **)
  end

  def safe_internal_path(target)
    result = RedirectsPathTargetResolver.call(target, source: :internal_path)
    result.value if result.ok?
  end

  def safe_return_path(target, allowed_hosts: nil)
    return safe_internal_path(target) if target.to_s.start_with?("/")
    return nil if allowed_hosts.present?

    uri = URI.parse(target.to_s)
    return nil unless uri.is_a?(URI::HTTP) && uri.userinfo.blank?

    allowed = allowed_return_hosts(allowed_hosts)
    return nil unless allowed.include?(host_with_optional_port(uri))

    safe_internal_path(uri.request_uri)
  rescue URI::InvalidURIError
    nil
  end

  private :safe_return_path

  def allowed_return_hosts(allowed_hosts)
    req = request if defined?(request)
    hosts = Array(allowed_hosts).presence || [
      req&.respond_to?(:host_with_port) ? req.host_with_port : nil,
      req&.respond_to?(:host) ? req.host : nil,
    ]

    result = hosts.filter_map { |host| normalized_host_with_optional_port(host) }
    result.uniq!
    result
  end

  def normalized_host_with_optional_port(value)
    raw = value.to_s.strip.downcase
    return if raw.blank?

    uri = URI.parse(raw.match?(%r{\Ahttps?://}) ? raw : "//#{raw}")
    host = uri.host
    return if host.blank?

    if uri.port && uri.port != default_port_for(uri.scheme)
      "#{host}:#{uri.port}"
    else
      host
    end
  rescue URI::InvalidURIError
    nil
  end

  def host_with_optional_port(uri)
    host = uri.host.to_s.downcase
    return host if uri.port.blank? || uri.port == default_port_for(uri.scheme)

    "#{host}:#{uri.port}"
  end

  def default_port_for(scheme)
    (scheme == "https") ? 443 : 80
  end

  def redirect_target_context_params
    {
      ri: params[:ri],
      surface: redirect_target_surface,
    }
  end

  def redirect_target_surface
    return surface_from_controller_name if respond_to?(
      :surface_from_controller_name,
      true,
    ) && surface_from_controller_name.present?
    return Actor.tld if defined?(Actor) && Actor.respond_to?(:tld) && Actor.tld.present?

    "app"
  end

  def jump_rt_issuer_namespace
    JumpRtSurface.namespace_for_controller(self.class.name)
  end

  def log_jump_rt_issued(token:, namespace:, dst:, replay_policy:, url:)
    req = request if respond_to?(:request, true)
    headers = req.headers if req&.respond_to?(:headers)
    request_id = req.request_id if req&.respond_to?(:request_id)
    referer = req.referer if req&.respond_to?(:referer)
    user_agent = req.user_agent if req&.respond_to?(:user_agent)
    remote_ip = req.remote_ip if req&.respond_to?(:remote_ip)
    cf_connecting_ip = headers["CF-Connecting-IP"] if headers
    Rails.logger.info(
      JitLogEvent.format(
        "jump_rt.issued",
        request_id: request_id,
        namespace: namespace,
        dst: dst,
        rpl: replay_policy,
        rt_length: token.to_s.bytesize,
        rt_parts: token.to_s.split(".").size,
        rt_digest12: Digest::SHA256.hexdigest(token.to_s)[0, 12],
        target_url_digest: Digest::SHA256.hexdigest(url.to_s)[0, 12],
        referer_digest12: digest12(referer),
        user_agent_digest12: digest12(user_agent),
        remote_ip_digest12: digest12(remote_ip),
        cf_connecting_ip_digest12: digest12(cf_connecting_ip),
        cf_ray: headers&.[]("CF-Ray").presence,
        cf_asn: headers&.[]("CF-ASN").presence,
        cf_ipcountry: headers&.[]("CF-IPCountry").presence,
      ),
    )
  end

  # Emitted when redirect_to_jump_url could not push the user through the
  # Jump gateway and silently downgraded to a same-host redirect via
  # fallback_internal. Surfaces key-config and gateway-issuance regressions
  # that would otherwise be invisible in production.
  def log_jump_rt_fallback_internal(namespace:, dst:, replay_policy:, url:, reason:, gateway_failure: nil)
    request_id = request.request_id if respond_to?(:request, true) && request.respond_to?(:request_id)
    Rails.logger.warn(
      JitLogEvent.format(
        "jump_rt.fallback_internal",
        request_id: request_id,
        namespace: namespace,
        dst: dst,
        rpl: replay_policy,
        reason: reason,
        gateway_failure: gateway_failure,
        target_url_digest: Digest::SHA256.hexdigest(url.to_s)[0, 12],
      ),
    )
  end

  def digest12(value)
    raw = value.to_s
    return nil if raw.blank?

    Digest::SHA256.hexdigest(raw)[0, 12]
  end

  def log_redirect_target_failure(result)
    return if result.ok?

    request_id = request.request_id if respond_to?(:request, true) && request.respond_to?(:request_id)
    Rails.logger.info(
      JitLogEvent.format(
        "redirect_target.rejected",
        kind: result.kind,
        source: result.source,
        reason: result.failure_reason,
        unsafe_value_digest: result.unsafe_value_digest,
        request_id: request_id,
      ),
    )
  end
end

# typed: false
# frozen_string_literal: true

module OidcSsoInitiator
  extend ActiveSupport::Concern
  include CommonRedirect

  OIDC_PENDING_FLOWS_SESSION_KEY = "oidc_pending_flows"
  OIDC_PENDING_FLOW_LIMIT = 2

  def authenticate!
    if logged_in?
      SignRiskEnforcer.call(current_resource)
      return
    end

    return render(json: { error: "Unauthorized" }, status: :unauthorized) if request.format.json?

    SignRiskEmitter.emit(
      "auth_required",
      ip: request&.remote_ip,
      user_agent: request&.user_agent,
      request_id: request&.request_id,
      path: request&.fullpath,
      method: request&.request_method,
    )
    url = sign_in_url_with_pt(encoded_pt(request.fullpath))
    redirect_to_oidc_authorization_url(url)
  end

  def sign_in_url_with_pt(pt)
    initiate_oidc_session!(pt: decode_pt(pt))
  end

  private

  def initiate_oidc_session!(pt: "/", screen_hint: nil, prompt: nil, max_age: nil)
    prompt = OidcAuthorizeRequestResolver.normalize_prompt(prompt)
    max_age = OidcAuthorizeRequestResolver.normalize_max_age(max_age)
    verifier = SecureRandom.urlsafe_base64(48)
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    state = SecureRandom.urlsafe_base64(32)
    nonce = SecureRandom.urlsafe_base64(32)

    oidc_pt = safe_oidc_pt(pt)
    if screen_hint.present?
      session[:oidc_code_verifier] = verifier
      session[:oidc_state] = state
      session[:oidc_nonce] = nonce
      session[:oidc_pt] = oidc_pt
      session[:oidc_max_age] = max_age
    else
      remember_oidc_pending_flow!(
        state: state,
        verifier: verifier,
        nonce: nonce,
        pt: oidc_pt,
        max_age: max_age,
      )
    end
    log_oidc_pending_flow_created(state: state, pt: oidc_pt)

    oidc_authorization_url(
      screen_hint: screen_hint,
      code_challenge: challenge,
      state: state,
      nonce: nonce,
      prompt: prompt,
      max_age: max_age,
    )
  end

  def redirect_to_oidc_authorization_url(url, **)
    decision = oidc_redirect_decision(url)
    log_oidc_redirect_decision(decision)

    case decision.kind
    when :direct
      redirect_to(url, allow_other_host: true, **)
    when :jump
      redirect_to_jump_url(url, preserve_query_keys: ["redirect_uri"], **)
    else
      head :bad_request
    end
  end

  def same_site_oidc_authorization_url?(url)
    oidc_redirect_decision(url).direct?
  end

  def same_site_oidc_rejection_reason(url)
    oidc_redirect_decision(url).reason_code
  end

  def oidc_redirect_decision(url)
    oidc_acme_service_origin.decision_for_authorize_url(url, request: request)
  end

  def oidc_authorization_url(screen_hint:, code_challenge:, state:, nonce:, prompt: nil, max_age: nil)
    query = {
      response_type: "code",
      client_id: oidc_client_id,
      redirect_uri: oidc_callback_url,
      code_challenge: code_challenge,
      code_challenge_method: "S256",
      state: state,
      nonce: nonce,
      scope: "openid profile",
      # The authorization endpoint skips region normalization, so it can only carry the region the
      # initiating request already resolved. Without this the ceremony reaches the credential
      # gateway region-less and every URL built from it downstream loses the region too.
      # `RequestContextContract` is used directly rather than `current_region_identifier` because
      # this concern is also included on controllers that do not mix in `PreferenceGlobal`.
      ri: RequestContextContract.normalize_region(params[:ri]),
    }
    query[:screen_hint] = screen_hint if screen_hint.present?
    query[:prompt] = prompt if prompt.present?
    query[:max_age] = max_age if max_age.present?
    oidc_acme_service_origin.authorization_endpoint(query: query)
  end

  def remember_oidc_pending_flow!(state:, verifier:, nonce:, pt:, max_age: nil)
    flows = session[OIDC_PENDING_FLOWS_SESSION_KEY]
    flows = {} unless flows.is_a?(Hash)
    flow =
      {
        "code_verifier" => verifier,
        "nonce" => nonce,
        "pt" => pt,
        "created_at" => Time.current.to_i,
      }.tap { |pending_flow| pending_flow["max_age"] = max_age if max_age.present? }
    flows[state] = flow
    session[OIDC_PENDING_FLOWS_SESSION_KEY] = flows.sort_by { |_key, entry| entry["created_at"].to_i }
      .last(OIDC_PENDING_FLOW_LIMIT)
      .to_h
  end

  def log_oidc_pending_flow_created(state:, pt:)
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.sso.pending_flow.created",
        client_id: oidc_client_id,
        host: request.host,
        csrf_digest12: oidc_sso_digest12(state),
        pt_digest12: oidc_sso_digest12(pt),
        pt_is_root: pt == "/",
        pending_flow_count: session[OIDC_PENDING_FLOWS_SESSION_KEY].to_h.size,
      ),
    )
  end

  def oidc_sso_digest12(value)
    Digest::SHA256.hexdigest(value.to_s).first(12)
  end

  def oidc_callback_url
    client = OidcClientRegistry.find!(oidc_client_id)
    client.redirect_uris.find { |uri| URI.parse(uri).host == request.host } ||
      raise(ActionController::BadRequest, "OIDC redirect URI is not registered for this host")
  rescue URI::InvalidURIError
    raise ActionController::BadRequest, "OIDC redirect URI is invalid"
  end

  def oidc_token_url
    public_token_endpoint = oidc_acme_service_origin.token_endpoint
    return public_token_endpoint unless Rails.env.local?

    local_oidc_token_endpoint(public_token_endpoint)
  end

  def encoded_pt(pt)
    Base64.urlsafe_encode64(pt.to_s)
  end

  def decode_pt(pt)
    Base64.urlsafe_decode64(pt.to_s)
  rescue ArgumentError
    "/"
  end

  def local_oidc_token_endpoint(public_token_endpoint)
    uri = URI.parse(public_token_endpoint)
    return public_token_endpoint unless uri.is_a?(URI::HTTP)
    return public_token_endpoint unless public_acme_development_host?(uri.host)

    uri.scheme = "http"
    uri.port = local_oidc_token_endpoint_port
    uri.to_s
  rescue URI::InvalidURIError
    public_token_endpoint
  end

  def public_acme_development_host?(host)
    configured_acme_hosts.include?(host.to_s.downcase)
  end

  def configured_acme_hosts
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    [
      hosts.acme_service.host,
      hosts.acme_corporate.host,
      hosts.acme_staff.host,
      hosts.base_service.host,
      hosts.base_corporate.host,
      hosts.base_staff.host,
    ].map { |configured_host| configured_host.to_s.downcase }
  end

  def local_oidc_token_endpoint_port
    Integer(ENV.fetch("PORT"), exception: false) || 3000
  end

  # Tighten the OIDC pt to a same-host internal path.
  #
  # Mirrors the shape of CommonRedirect#safe_internal_path (path?query
  # only, no scheme / host / userinfo / control chars). Inlined here instead
  # of delegated because OidcSsoInitiator is included on acme application
  # controllers that already mix in CommonRedirect via other paths, and we
  # want this validator to be self-contained while the broader unification
  # is planned separately. Future work: share the helper.
  def safe_oidc_pt(pt)
    target = pt.to_s
    return "/" if target.blank?
    return "/" if target.match?(/[[:cntrl:]]/)

    begin
      uri = URI.parse(target)
    rescue URI::InvalidURIError
      return "/"
    end

    return "/" if uri.user.present? || uri.password.present?

    if uri.scheme.present? || uri.host.present?
      scheme_ok = %w(http https).include?(uri.scheme)
      host_ok = uri.host.present? && uri.host == request.host
      return "/" unless scheme_ok && host_ok
    end

    path = uri.path.presence || "/"
    return "/" unless path.start_with?("/")

    uri.query.present? ? "#{path}?#{uri.query}" : path
  end

  def oidc_client_id
    raise NotImplementedError, "controller must define oidc_client_id"
  end

  def oidc_sign_host
    raise NotImplementedError, "controller must define oidc_sign_host"
  end

  def oidc_base_authority_host
    raise NotImplementedError, "controller must define oidc_base_authority_host"
  end

  def oidc_base_service_origin
    @oidc_base_service_origin ||=
      Oidc::AcmeServiceOrigin.from(
        oidc_base_authority_host,
        default_scheme: oidc_base_default_scheme,
      )
  end

  def oidc_base_default_scheme
    host = Oidc::AcmeServiceOrigin.host_from(oidc_base_authority_host)
    return request.ssl? ? "https" : "http" if host.present? && host.end_with?(".localhost")

    "https"
  end

  def oidc_acme_host
    oidc_base_authority_host
  end

  def oidc_acme_service_origin
    oidc_base_service_origin
  end

  def oidc_acme_default_scheme
    oidc_base_default_scheme
  end

  def log_oidc_redirect_decision(decision)
    event_name =
      case decision.kind
      when :direct then "oidc.sso.redirect_policy.direct"
      when :jump then "oidc.sso.redirect_policy.jump"
      else "oidc.sso.redirect_policy.rejected"
      end

    payload = {
      request_id: request.request_id,
      surface: oidc_redirect_surface,
      client_id: oidc_client_id,
      request_host: decision.request_host,
      request_scheme: decision.request_scheme,
      target_scheme: decision.target_scheme,
      target_host: decision.target_host,
      target_port: decision.target_port,
      target_path: decision.target_path,
      decision: decision.kind,
      reason_code: decision.reason_code,
      same_site: decision.same_site,
      acme_host: decision.acme_host,
      acme_port: decision.acme_port,
      acme_scheme: decision.acme_scheme,
    }.compact

    Rails.logger.info(JSON.generate(event: event_name, data: payload))
  end

  def oidc_redirect_surface
    case self.class.name.to_s
    when /\ASign::App::/ then "sign_app"
    when /\ASign::Com::/ then "sign_com"
    when /\ASign::Org::/ then "sign_org"
    when /\ACore::App::/ then "core_app"
    when /\ACore::Com::/ then "core_com"
    when /\ACore::Org::/ then "core_org"
    when /\ABase::App::/ then "base_app"
    when /\ABase::Com::/ then "base_com"
    when /\ABase::Org::/ then "base_org"
    when /\APalm::App::/ then "palm_app"
    else
      self.class.name.to_s
    end
  end
end

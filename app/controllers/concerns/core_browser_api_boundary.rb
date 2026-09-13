# typed: false
# frozen_string_literal: true

module CoreBrowserApiBoundary
  extend ActiveSupport::Concern

  include ProblemDetailsRendering
  include ApiContentNegotiation

  included do
    # Every endpoint on this boundary answers per-subject state derived from a credential cookie, and
    # the session endpoint hands out a CSRF token. None of it may sit in a shared cache, so the
    # directive belongs to the boundary rather than to whichever action remembers to set it.
    before_action :set_core_browser_api_no_store!
  end

  private

  def set_core_browser_api_no_store!
    response.set_header("Cache-Control", "no-store")
  end

  attr_reader :current_resource, :current_token_payload, :current_token_record

  def require_core_browser_api_enabled!
    return if CoreBrowserCredentialContract.enabled?

    # rubocop:disable I18n/RailsI18n/DecorateString
    render_problem(:service_unavailable, detail: "Core browser API is not enabled.")
    # rubocop:enable I18n/RailsI18n/DecorateString
  end

  def authenticate_core_browser_cookie!
    if AuthAuthorizationHeader.access_token(request).present?
      render_problem(:authentication_required)
      return false
    end

    token = cookies[CoreBrowserCredentialContract::ACCESS_COOKIE].to_s.presence
    unless token
      install_unauthenticated_actor!
      return false
    end

    payload = CoreBrowserCredentialContract.decode_access_token(
      token: token,
      host: request.host,
      resource_type: core_resource_type,
    )
    if payload.blank? || CoreBrowserCredentialContract.native_or_side_audience?(payload)
      render_problem(:authentication_required)
      return false
    end

    @current_token_payload = payload
    @current_token_record = find_core_token_record(payload)
    @current_resource = find_core_resource(payload)
    unless current_token_record&.active? && current_resource&.active?
      render_problem(:authentication_required)
      return false
    end

    install_authenticated_actor!
    true
  end

  def render_csrf_failure
    render_problem(:csrf_verification_failed)
  end

  def render_authorization_denied
    render_problem(:authorization_denied)
  end

  def refresh_core_browser_token!
    if AuthAuthorizationHeader.access_token(request).present?
      render_problem(:authentication_required)
      return
    end

    refresh_plain = cookies[CoreBrowserCredentialContract::REFRESH_COOKIE].to_s.presence
    unless refresh_plain
      render_problem(:authentication_required)
      return
    end

    result = AcmeRefreshTokenIssuer.call(refresh_token: refresh_plain)
    unless result.success? && result.token.is_a?(core_token_class)
      render_problem(:token_expired)
      return
    end

    resource = result.token.public_send(core_token_resource_method)
    access_expires_at = CoreBrowserCredentialContract.access_token_expires_at_for(
      token_record: result.token,
    )
    access_token = CoreBrowserCredentialContract.encode_access_token(
      resource: resource,
      token_record: result.token,
      host: request.host,
      resource_type: core_resource_type,
      expires_at: access_expires_at,
    )

    cookies[CoreBrowserCredentialContract::ACCESS_COOKIE] =
      auth_cookie_service.auth_cookie_options(expires: access_expires_at).merge(value: access_token)
    cookies[CoreBrowserCredentialContract::REFRESH_COOKIE] =
      auth_cookie_service.auth_cookie_options(expires: result.token.discarded_at).merge(value: result.refresh_token)

    # The rotated credentials travel as `Set-Cookie`, so there is no representation to return.
    # RFC 9110 15.3.5 and docs/reference/api-design-standards.md both call for 204 rather than a
    # `{"ok": true}` placeholder. The previous 200 with `{"refreshed": true}` was justified in a
    # comment here by the claim that the Next.js edge application read that key; an audit of
    # `seahal/umaxica-apps-edge` on 2026-08-22 found it forwards `/api/v0/*` without parsing it and
    # has no reader for the key. See decision D14 in plans/rails-nextjs-openapi-contract-audit.md.
    head :no_content
  end

  def verify_core_browser_api_csrf!
    return if request.get? || request.head? || request.options?

    token = request.headers["X-CSRF-Token"].to_s
    return if token.present? && valid_authenticity_token?(session, token)

    render_csrf_failure
  end

  def current_actor
    Actor.context
  end

  def current_policy_user
    current_actor&.authz&.policy_user
  end

  def install_unauthenticated_actor!
    Actor.clear
  end

  def install_authenticated_actor!
    Actor.clear
    # The Core Browser API boundary is the Core BFF browser cookie flow, so the
    # transport/channel axes are known and concrete here.
    context = ActorValuesContext.new(
      subject: current_resource,
      actor_type: core_actor_type,
      account: nil,
      tenant: nil,
      tld: core_actor_tld,
      surface: :core,
      transport: :cookie,
      channel: :browser,
      authn: Actor::Authentication.new(
        login_public_id: current_token_record.public_id,
        access_claims: current_token_payload,
        acr: current_token_payload["acr"],
        amr: current_token_payload["amr"],
        actor_type: core_actor_type,
        actor_id: current_resource.id,
        restricted: current_token_record.respond_to?(:restricted?) && current_token_record.restricted?,
      ),
      authz: Actor::Authz.new(
        policy_user: current_resource,
        token_claims: current_token_payload,
        surface: core_actor_tld,
      ),
      preferences: Actor::Preference::NULL,
      configuration: Actor::Configuration::NULL,
      step_up: Actor::StepUp::NULL,
      selection: Actor::SelectedContext::NULL,
      trace_id: request.request_id,
      span_id: nil,
    )
    Actor.install_context!(**context.to_h)
  end

  def find_core_token_record(payload)
    sid = AuthorizationTokenClaims.session_id(payload).to_s
    return nil if sid.blank?

    core_token_class.find_by(public_id: sid) || core_token_class.find_by(oidc_sid: sid)
  end

  def find_core_resource(payload)
    subject = AuthorizationTokenClaims.subject(payload).to_s
    return nil if subject.blank?

    core_resource_class.find_by(id: subject)
  end

  def core_actor_tld
    raise NotImplementedError, "controller must define core_actor_tld"
  end

  def core_actor_type
    core_resource_type.to_sym
  end

  def core_resource_class
    raise NotImplementedError, "controller must define core_resource_class"
  end

  def core_token_class
    raise NotImplementedError, "controller must define core_token_class"
  end

  def core_resource_type
    raise NotImplementedError, "controller must define core_resource_type"
  end

  def core_token_resource_method
    case core_resource_type
    when "operator" then :staff
    when "visitor" then :visitor
    else :user
    end
  end

  def auth_cookie_service
    @auth_cookie_service ||= AuthenticationCookieService.new(cookies, request)
  end
end

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

  attr_reader :current_resource, :current_token_payload

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

    token = cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.presence
    unless token
      install_unauthenticated_actor!
      return false
    end

    payload = OidcRpBrowserCredentialContract.decode_access_token(
      token: token,
      host: request.host,
      resource_type: core_resource_type,
      client_id: core_rp_client_id,
    )
    if payload.blank?
      reject_core_browser_cookie!(reason: "invalid_access_token")
      render_problem(:authentication_required)
      return false
    end

    @current_token_payload = payload
    @current_resource = find_core_resource(payload)
    unless current_resource&.active?
      reject_core_browser_cookie!(reason: current_resource ? "inactive_resource" : "record_not_found")
      render_problem(:authentication_required)
      return false
    end

    install_authenticated_actor!
    true
  end

  def render_csrf_failure
    render_problem(:csrf_verification_failed)
  end

  def reject_core_browser_cookie!(reason:)
    Rails.logger.info(
      JitLogEvent.format(
        "auth.credential_rejected",
        surface: core_actor_tld,
        credential_kind: "oidc_rp_access_cookie",
        reason: reason,
        category: (reason == "inactive_resource") ? "lifecycle" : "credential_rejection",
        request_id: request.request_id,
      ),
    )
    cookies.delete(
      OidcRpBrowserCredentialContract::ACCESS_COOKIE,
      OidcRpBrowserCredentialContract.access_cookie_deletion_options,
    )
    # Refusing access does not verify the independent refresh credential. Its
    # existing explicit POST must decide rotation or refusal; GET grants no
    # authority from refresh presence and never consumes or deletes it here.
    install_unauthenticated_actor!
  end

  def render_authorization_denied
    render_problem(:authorization_denied)
  end

  def refresh_core_browser_token!
    if AuthAuthorizationHeader.access_token(request).present?
      render_problem(:authentication_required)
      return
    end

    refresh_plain = cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.presence
    unless refresh_plain
      render_problem(:authentication_required)
      return
    end

    token_endpoint_uri = OidcIssuer.token_endpoint(core_resource_type)
    client_assertion = OidcClientAssertionJwt.issue(
      client_id: core_rp_client_id,
      token_url: token_endpoint_uri,
    )
    result = OidcTokenExchangeCoordinator.call(
      grant_type: "refresh_token",
      refresh_token: refresh_plain,
      client_id: core_rp_client_id,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: client_assertion,
      token_endpoint_uri: token_endpoint_uri,
      expected_resource_type: core_resource_type,
    )
    unless result.success?
      render_problem(:token_expired)
      return
    end

    access_token = result.token_response.fetch(:access_token)
    new_refresh_token = result.token_response.fetch(:refresh_token)
    expiries = {
      access_expires_at: result.access_expires_at ||
        OidcRpBrowserCredentialContract.access_expires_at_from_response(result.token_response),
      refresh_expires_at: result.refresh_expires_at ||
        OidcRpBrowserCredentialContract.refresh_expires_at_from_response(result.token_response),
    }

    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      OidcRpBrowserCredentialContract.access_cookie_options(expires_at: expiries.fetch(:access_expires_at)).merge(
        value: access_token,
      )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] =
      OidcRpBrowserCredentialContract.refresh_cookie_options(expires_at: expiries.fetch(:refresh_expires_at)).merge(
        value: new_refresh_token,
      )

    # The rotated credentials travel as `Set-Cookie`, so there is no representation to return.
    # RFC 9110 15.3.5 and docs/reference/api-design-standards.md both call for 204 rather than a
    # `{"ok": true}` placeholder. The previous 200 with `{"refreshed": true}` was justified in a
    # comment here by the claim that the Next.js edge application read that key; an audit of
    # `seahal/umaxica-apps-edge` on 2026-08-22 found it forwards `/api/v0/*` without parsing it and
    # has no reader for the key. See decision D14 in plans/analysis/rails-nextjs-openapi-contract-audit.md.
    head :no_content
  end

  def verify_core_browser_api_csrf!
    return if request.get? || request.head? || request.options?

    token = request.headers["X-CSRF-Token"].to_s
    if valid_request_origin? && token.present? && valid_authenticity_token?(session, token) &&
        verified_request_for_forgery_protection?
      return
    end

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
    observability_context = ObservabilityContextResolver.call
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
        login_public_id: AuthorizationTokenClaims.session_id(current_token_payload),
        access_claims: current_token_payload,
        acr: current_token_payload["acr"],
        amr: current_token_payload["amr"],
        actor_type: core_actor_type,
        actor_id: current_resource.id,
        restricted: false,
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
      trace_id: observability_context.trace_id,
      span_id: observability_context.span_id,
    )
    Actor.install_context!(**context.to_h)
  end

  def find_core_resource(payload)
    subject = OidcSubject.public_id_from(
      AuthorizationTokenClaims.subject(payload), resource_type: core_resource_type,
    )
    return nil if subject.blank?

    core_resource_class.find_by(public_id: subject)
  end

  def core_rp_client_id
    case core_resource_type.to_s
    when "operator" then "core-org"
    when "visitor" then "core-com"
    else "core-app"
    end
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
end

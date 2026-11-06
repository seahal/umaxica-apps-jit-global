# typed: false
# frozen_string_literal: true

module CoreBrowserApiBoundary
  extend ActiveSupport::Concern

  include ProblemDetailsRendering
  include ApiContentNegotiation
  include RpCellLocalSession

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
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
    authenticate_core_cell_session!(token)
  end

  # R5-WU17 cell process: the Access JWT plus this cell's local session; the actor is the local
  # principal, never the canonical Client/Operator.
  def authenticate_core_cell_session!(token)
    result = authenticate_rp_cell_request(access_token: token)
    unless result.authenticated?
      reject_core_browser_cookie!(reason: "invalid_access_token")
      render_problem(:authentication_required)
      return false
    end

    @current_token_payload = result.payload
    @current_resource = result.principal
    install_authenticated_actor!
    true
  rescue OidcOpJwksClient::FetchError, ActiveRecord::ActiveRecordError, PG::Error
    render_problem(:service_unavailable)
    false
  end

  def rp_cell_client_id = core_rp_client_id

  def rp_cell_resource_type = core_resource_type

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

    refresh_core_cell_token!(refresh_plain)
  end

  # R5-WU17 cell process: Refresh is checked/installed under the local session (RpRefreshCommitter).
  def refresh_core_cell_token!(refresh_plain)
    cell = rp_cell
    result =
      "#{cell.record_prefix}Record".constantize.connected_to(role: :writing) do
        RpRefreshCommitter.call(
          cell:, local_session_id: cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE].to_s,
          refresh_token: refresh_plain, issuer: rp_cell_issuer,
          jwks_client: rp_cell_jwks_client, token_url: OidcIssuer.token_endpoint(core_resource_type),
        )
      end
    case result.outcome
    when :installed
      install_core_refreshed_cookies!(result.token_response)
      head :no_content
    when :refused, :revoked then render_problem(:token_expired)
    else render_problem(:service_unavailable)
    end
  end

  def install_core_refreshed_cookies!(token_response)
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      OidcRpBrowserCredentialContract.access_cookie_options(
        expires_at: OidcRpBrowserCredentialContract.access_expires_at_from_response(token_response),
      ).merge(value: token_response.fetch(:access_token))
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] =
      OidcRpBrowserCredentialContract.refresh_cookie_options(
        expires_at: OidcRpBrowserCredentialContract.refresh_expires_at_from_response(token_response),
      ).merge(value: token_response.fetch(:refresh_token))
  end

  def verify_core_browser_api_csrf!
    return if request.get? || request.head? || request.options?

    token = request.headers["X-CSRF-Token"].to_s
    if request.origin.present? && valid_request_origin? && token.present? && valid_authenticity_token?(
      session,
      token,
    ) &&
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

  def core_rp_client_id
    case core_resource_type.to_s
    when "operator" then RpDeploymentBindingValue.client_id("core-org")
    else RpDeploymentBindingValue.client_id("core-app")
    end
  end

  def core_actor_tld
    raise NotImplementedError, "controller must define core_actor_tld"
  end

  def core_actor_type
    core_resource_type.to_sym
  end

  def core_resource_type
    raise NotImplementedError, "controller must define core_resource_type"
  end
end

# typed: false
# frozen_string_literal: true

module ActorSupport
  extend ActiveSupport::Concern

  include ::PreferenceRequestOverlay

  class ResolutionError < StandardError; end

  def current_actor
    Actor.context
  end

  private

  # Time.zone is thread-local, so a zone set for one request would otherwise stay
  # on the thread and be inherited by the next request, a job, or a mailer that
  # never resolved a preference of its own. Restoring it here keeps every
  # rendered date -- the copyright year included -- a function of the request's
  # own preference rather than of whatever ran before it.
  def with_actor_lifecycle
    previous_time_zone = Time.zone
    yield
  ensure
    Time.zone = previous_time_zone
    Actor.clear
  end

  def set_current_context
    context = resolved_current_context
    # Note: HostContextResolver's `surface` is the TLD tier, not the ActorValuesContext
    # `surface` route/product axis. The latter, plus transport/channel, are left at
    # their safe baseline here.
    # TODO: derive surface from routing and refine transport/channel from the
    # resolved credential source when those axes gain consumers. Until then the
    # anonymous baseline is transport: :none, channel/surface: :unknown.
    Actor.install_context!(
      tld: context.surface,
      surface: :unknown,
      transport: :none,
      channel: :unknown,
      account: context.account,
      tenant: context.tenant,
      actor: Unauthenticated.instance,
      actor_type: :unauthenticated,
      authn: Actor::Authentication::NULL,
      authz: Actor::Authz::NULL,
      configuration: Actor::Configuration::NULL,
      preferences: Actor::Preference.new,
      selection: Actor::SelectedContext::NULL,
      step_up: Actor::StepUp::NULL,
      trace_id: nil,
      span_id: nil,
    )
  end

  def set_current_actor
    set_current_context if Actor.tld.blank?
    resource = safe_current_resource
    actor = resource.presence || Unauthenticated.instance
    actor_type = resolved_current_actor_type(resource)
    authn = resolved_current_authentication(resource: resource, actor_type: actor_type)
    Actor.install_context!(
      actor: actor,
      actor_type: actor_type,
      authn: authn,
      authz: resolved_current_authz(resource: resource, authn: authn),
      configuration: resolved_current_configuration(resource),
      preferences: resolved_current_preference(resource),
      selection: resolved_current_selection,
      step_up: resolved_current_step_up,
    )
  end

  alias set_current set_current_actor

  def current_policy_user
    Actor.authz.policy_user || safe_current_resource
  end

  def resolved_current_context
    if Actor.tld.present?
      return HostContextResolver::Context.new(
        surface: Actor.tld,
        account: Actor.account,
        tenant: Actor.tenant,
      )
    end
    unless respond_to?(:request, true) && request.present?
      return HostContextResolver::Context.new(
        surface: nil,
        account: Actor.account,
        tenant: Actor.tenant,
      )
    end

    HostContextResolver.call(request)
  end

  def resolved_current_tld
    resolved_current_context.surface
  end

  def safe_current_resource
    return unless respond_to?(:current_resource, true)

    current_resource
  rescue StandardError => e
    return nil if respond_to?(:authentication_credentials_invalid?, true) && authentication_credentials_invalid?

    raise_actor_resolution_error!(:current_resource, e)
  end

  def resolved_current_actor_type(resource)
    actor_type = Actor.actor_type
    return actor_type if actor_type.present? && actor_type != :unauthenticated
    return :unauthenticated if resource.blank?

    if resource.respond_to?(:operator?) && resource.operator?
      :operator
    elsif resource.respond_to?(:visitor?) && resource.visitor?
      :visitor
    else
      :client
    end
  end

  def resolved_current_session
    return @current_session_public_id if defined?(@current_session_public_id) && @current_session_public_id.present?

    resolved_current_token&.dig("sid")
  end

  # The verified access-token claims recorded by AuthenticationBase#load_from_token. This must
  # not fall back to another token: ApplicationPolicy reads its Emergency context from here.
  def resolved_current_token
    @current_access_token_payload if defined?(@current_access_token_payload)
  end

  def resolved_current_authentication(resource: safe_current_resource,
                                      actor_type: resolved_current_actor_type(resource))
    token = resolved_current_token
    session_id = resolved_current_session
    return Actor::Authentication::NULL if token.blank? && session_id.blank? && resource.blank?

    Actor::Authentication.new(
      login_public_id: session_id,
      access_claims: token,
      acr: token&.dig("acr"),
      amr: token&.dig("amr"),
      actor_type: actor_type,
      actor_id: resource&.id,
      active_sign_sequence_id: resolved_active_sign_sequence_id,
    )
  end

  def resolved_active_sign_sequence_id
    return unless respond_to?(:session, true)
    return unless defined?(SignInSequenceCarrier)

    sequence = SignInSequenceCarrier.new(session, surface: Actor.tld).current
    return if sequence.blank?
    return if sequence.expired? || sequence.terminal?

    sequence.id
  rescue StandardError => e
    raise_actor_resolution_error!(:sign_sequence, e)
  end

  def resolved_current_configuration(_resource)
    Actor::Configuration::NULL
  end

  def resolved_current_selection
    # An RP cell process has no OP root to read; its controller supplies the owner's answer.
    cell_selection = rp_cell_selected_context if respond_to?(:rp_cell_selected_context, true)
    return cell_selection if cell_selection

    token = current_session if respond_to?(:current_session, true)
    return Actor::SelectedContext::NULL if token.blank?

    Actor::SelectedContext.new(
      account_public_id: token.try(:selected_account_public_id),
      collective_public_id: token.try(:selected_collective_public_id),
      collective_unit_public_id: token.try(:selected_collective_unit_public_id),
      avatar_public_id: token.try(:selected_avatar_public_id),
      selected_at: token.try(:selected_at),
    )
  rescue StandardError => e
    raise_actor_resolution_error!(:selected_context, e)
  end

  def resolved_current_authz(resource:, authn:)
    Actor::Authz.new(
      policy_user: resource,
      token_claims: authn.access_claims,
      surface: resolved_current_tld,
    )
  end

  def resolved_current_step_up
    return Actor::StepUp::NULL unless defined?(StepUpResolver)
    return Actor::StepUp::NULL unless respond_to?(:current_session_token, true)
    # Base authorization reads its OP Access-token event at the protected writer. Actor's legacy
    # request snapshot cannot represent that unscoped event, so it must not resolve root columns.
    return Actor::StepUp::NULL if browser_rp_controller?

    scope = resolved_current_step_up_scope
    return Actor::StepUp::NULL if scope.blank?

    # This runs before the authentication gate. A request without a session has no Step-Up state to
    # resolve, and a requirement cannot be built without a session binding; the gate refuses it.
    token = current_session_token
    return Actor::StepUp::NULL if token.nil?

    StepUpResolver.call(
      token: token,
      requirement: step_up_requirement(scope: scope),
    )
  rescue ActiveRecord::RecordNotFound
    raise
  rescue StandardError => e
    raise_actor_resolution_error!(:step_up, e)
  end

  def resolved_current_step_up_scope
    return verification_scope if respond_to?(:verification_required?, true) && verification_required?

    nil
  end

  def raise_actor_resolution_error!(component, exception)
    Rails.logger.warn(
      JitLogEvent.format(
        "actor.resolution.failed",
        component: component,
        error_class: exception.class.name,
      ),
    )

    raise ResolutionError.new("Actor #{component} resolution failed"), cause: exception
  end

  # Hydrate Actor.preferences from the Preference JWT payload -- the signed
  # projection of the DB, which is the SSoT. The payload is decoded by
  # set_preferences_cookie, which the controller lifecycle runs before
  # set_current_actor (locked by controller_lifecycle_order_invariant_test).
  #
  # The obsolete auth access-token `prf` claim is intentionally not read here:
  # it never mirrored the DB and is no longer emitted for newly issued auth
  # access tokens.
  #
  # Bearer/OIDC requests and the endpoints that skip set_preferences_cookie carry
  # no Preference JWT cookie, so they fall back to the default preference values
  # (theme sy) plus the request overlay. Actor::Preference::NULL is reserved for
  # an unbound context, not for "visitor has not chosen a theme yet".
  def resolved_current_preference(_resource)
    cookie = Actor::Preference::NULL_COOKIE
    payload_preferences = current_preference_payload_preferences
    if payload_preferences.present?
      return preference_with_request_overlay(
        Actor::Preference.from_jwt(payload_preferences, cookie: cookie),
      )
    end

    preference_with_request_overlay(Actor::Preference.new(cookie: cookie))
  end

  # The decoded Preference JWT `preferences` hash, or nil when absent or when the
  # controller does not include the preference concept at all.
  def current_preference_payload_preferences
    return unless respond_to?(:preference_payload_preferences, true)

    load_access_token_payload if respond_to?(:load_access_token_payload, true)
    preferences = preference_payload_preferences
    preferences if preferences.is_a?(Hash) && preferences.present?
  end

  def set_current_observability
    observability_context = ObservabilityContextResolver.call
    Actor.install_context!(
      trace_id: observability_context.trace_id,
      span_id: observability_context.span_id,
    )
  end
end

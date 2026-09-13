# typed: false
# frozen_string_literal: true

module ActorSupport
  extend ActiveSupport::Concern

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

  def _reset_current_state
    Actor.clear
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

  def resolved_current_token
    payload = nil
    payload = access_token_payload if respond_to?(:access_token_payload, true)
    payload ||= load_access_token_payload if respond_to?(:load_access_token_payload, true)
    payload if payload.is_a?(Hash)
  rescue StandardError => e
    raise_actor_resolution_error!(:access_token, e)
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
      restricted: resolved_current_restricted_session?,
      active_sign_sequence_id: resolved_active_sign_sequence_id,
    )
  end

  def resolved_current_restricted_session?
    return current_session_restricted? if respond_to?(:current_session_restricted?, true)

    false
  rescue StandardError => e
    raise_actor_resolution_error!(:restricted_session, e)
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

    StepUpResolver.call(
      token: current_session_token,
      scope: resolved_current_step_up_scope,
      required_aal: resolved_current_step_up_required_aal,
    )
  rescue StandardError => e
    raise_actor_resolution_error!(:step_up, e)
  end

  def resolved_current_step_up_scope
    return verification_scope if respond_to?(:verification_required?, true) && verification_required?

    nil
  end

  def resolved_current_step_up_required_aal
    return verification_required_aal if respond_to?(:verification_required_aal, true)

    StepUpResolver::DEFAULT_REQUIRED_AAL
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
  def resolved_current_preference(resource)
    cookie = resolved_current_cookie(resource, preference_record: nil)

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

  def resolved_current_cookie(resource, preference_record: :__resolve__)
    preference_record = resolved_resource_preference(resource) if preference_record == :__resolve__
    if preference_record.present?
      return Actor::Preference.cookie_from(
        consented: preference_record.consented,
        functional: preference_record.functional,
        performant: preference_record.performant,
        targetable: preference_record.targetable,
        consent_version: preference_record.try(:consent_version),
        consented_at: preference_record.consented_at,
      )
    end

    if respond_to?(:preference_payload_preferences, true)
      payload_preferences = preference_payload_preferences
      if payload_preferences.is_a?(Hash)
        return Actor::Preference.cookie_from(
          consented: payload_preferences["consented"],
          functional: payload_preferences["functional"],
          performant: payload_preferences["performant"],
          targetable: payload_preferences["targetable"],
          consent_version: payload_preferences["consent_version"],
          consented_at: payload_preferences["consented_at"],
        )
      end
    end

    Actor::Preference::NULL_COOKIE
  end

  def resolved_resource_preference(resource)
    association_name = resource_preference_association_name(resource)
    return if association_name.blank? || !resource.respond_to?(association_name)

    reset_resource_preference_association(resource, association_name)
    resource.public_send(association_name)
  end

  def resource_preference_association_name(resource)
    return if resource.blank?

    if resource.respond_to?(:operator?) && resource.operator?
      :staff_preference
    elsif resource.respond_to?(:visitor?) && resource.visitor?
      :visitor_preference
    else
      :user_preference
    end
  end

  def reset_resource_preference_association(resource, association_name)
    return unless resource.respond_to?(:association)

    resource.association(association_name).reset
  rescue ActiveRecord::AssociationNotFoundError
    nil
  end

  def preference_from_record(preference_record, cookie:)
    Actor::Preference.new(
      language: preference_record_value(preference_record, :language),
      region: preference_record_value(preference_record, :region),
      timezone: preference_record_value(preference_record, :timezone),
      theme: preference_record_value(preference_record, :theme),
      currency: preference_record_value(preference_record, :currency),
      date_format: preference_record_value(preference_record, :date_format),
      time_format: preference_record_value(preference_record, :time_format),
      motion: preference_record_value(preference_record, :motion),
      density: preference_record_value(preference_record, :density),
      page_size: preference_record_value(preference_record, :page_size),
      cookie: cookie,
    )
  end

  def preference_with_request_overlay(preference)
    return preference unless respond_to?(:requested_context, true)

    context = requested_context
    return preference if context.blank?

    Actor::Preference.new(
      language: overlay_language(context, preference),
      region: context[:ri] || preference.region,
      timezone: context[:tz] || preference.timezone,
      theme: context[:ct] || preference.theme,
      currency: context[:cu] || preference.currency,
      date_format: context[:df] || preference.date_format,
      time_format: context[:tf] || preference.time_format,
      motion: context[:mo] || preference.motion,
      density: context[:dn] || preference.density,
      page_size: context[:ps] || preference.page_size,
      cookie: preference.cookie,
      null: preference.null?,
      explicit_fields: preference.explicit_fields,
    )
  end

  # Resolve the request-overlay language.
  #
  # Priority:
  #   1. explicit `lx` param      - the user asked for this language directly
  #   2. explicitly saved language - a language the user chose on purpose must not
  #                                  be overridden by a region context param (?ri)
  #   3. region-derived locale    - seeds the language for users who have not set
  #                                  one yet (?ri=jp -> ja, ?ri=us -> en)
  #   4. preference default       - final fallback (default language is "ja")
  #
  # Explicitness, not whole-record null?, gates step 2: a hydrated preference is
  # never null (default child records always exist), so region seeding for unset
  # users relies on the per-field explicit marker.
  def overlay_language(context, preference)
    context[:lx] ||
      (preference.language_explicit? ? preference.language : nil) ||
      locale_from_request_region(context[:ri]) ||
      preference.language
  end

  def locale_from_request_region(region)
    return if region.blank?
    return locale_from_region(region) if respond_to?(:locale_from_region, true)

    {
      "jp" => "ja",
      "us" => "en",
    }[region.to_s.downcase]
  end

  def preference_record_value(preference_record, name)
    return preference_adult_content_gate_value(preference_record) if name == :adult_content_gate

    value = preference_record.public_send(name) if preference_record.respond_to?(name)
    value.presence || Actor::Preference::DEFAULTS.fetch(name)
  end

  def preference_adult_content_gate_value(preference_record)
    association = "#{preference_record.class.name.underscore}_adult_content_gate"
    stopper = preference_record.public_send(association) if preference_record.respond_to?(association)
    stopper&.option&.name || "nothing"
  end

  def set_current_observability
    if respond_to?(:request, true) && request.respond_to?(:request_id) && request.request_id.present?
      Actor.install_context!(trace_id: request.request_id)
    end
    return unless defined?(OpenTelemetry::Trace)

    preference_cookie = Actor.preferences.cookie
    analytics_allowed = preference_cookie.performant?

    span = OpenTelemetry::Trace.current_span
    context = span.context
    return unless context.valid?

    Actor.install_context!(
      trace_id: context.hex_trace_id,
      span_id: analytics_allowed ? context.hex_span_id : nil,
    )
  end
end

# typed: false
# frozen_string_literal: true

# Anonymous actor lifecycle for the com surface.
#
# The com hosts have no principal, credential, session, or admission boundary. Both the Base com
# preference entry and the Warp com public pages install the same anonymous snapshot and clear it
# when the request ends, so localization, theme, and URL overlay keep working without leaving actor
# state on the thread.
#
# Contract with the including controller (all private methods here, declared there as callbacks):
#   request  - the current ActionController request, used only to resolve the host context
#
# Including this module registers nothing. The caller declares `before_action` for
# `set_anonymous_context` / `set_current_observability` and `around_action` for
# `with_anonymous_context_lifecycle`, so the callbacks are visible at the controller.
module ComAnonymousActorContext
  extend ActiveSupport::Concern

  include ::PreferenceRequestOverlay

  private

  def set_anonymous_context
    context = HostContextResolver.call(request)
    Actor.install_context!(
      tld: context.surface,
      surface: :unknown,
      transport: :none,
      channel: :unknown,
      account: nil,
      tenant: nil,
      subject: Unauthenticated.instance,
      actor_type: :unauthenticated,
      authn: Actor::Authentication::NULL,
      authz: Actor::Authz::NULL,
      configuration: Actor::Configuration::NULL,
      preferences: anonymous_preference,
      selection: Actor::SelectedContext::NULL,
      step_up: Actor::StepUp::NULL,
      trace_id: nil,
      span_id: nil,
    )
  end

  # The anonymous preference is built from the request context only. It carries no persisted
  # preference because the corporate surface has no principal; the overlay is what makes
  # `?ri=us` render English on the public preference screens.
  def anonymous_preference
    preference_with_request_overlay(Actor::Preference.new)
  end

  def valid_anonymous_experience_cookie?(value, expected)
    return false unless value.is_a?(String) && value.present?
    return false if value.bytesize > SecurityJwtPreferenceTokenCodec::ANONYMOUS_REALM_TOKEN_MAX_BYTES

    JSON.parse(value, allow_duplicate_key: false) == expected
  rescue JSON::ParserError
    false
  end

  def hydrate_anonymous_preferences
    load_access_token_payload if (request.get? || request.head?) && !@preference_payload.is_a?(Hash)
    return unless @preference_payload.is_a?(Hash) && @preference_payload["aud"] == "com"

    preference = Actor::Preference.from_jwt(effective_context.stringify_keys)
    Actor.install_context!(preferences: preference_with_request_overlay(preference))
  end

  # Time.zone is thread-local, so a zone set for one request would otherwise stay on the thread and
  # be inherited by the next request or job. Clearing the anonymous snapshot here keeps both the
  # clock and the actor state a function of this request only.
  def with_anonymous_context_lifecycle
    previous_time_zone = Time.zone
    yield
  ensure
    Time.zone = previous_time_zone
    Actor.clear
  end

  def set_current_observability
    observability_context = ObservabilityContextResolver.call
    Actor.install_context!(
      trace_id: observability_context.trace_id,
      span_id: observability_context.span_id,
    )
  end
end

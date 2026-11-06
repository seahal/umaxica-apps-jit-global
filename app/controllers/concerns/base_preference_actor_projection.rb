# typed: false
# frozen_string_literal: true

# Adds the Base-owned database fields that may be exposed through Actor.preferences. Anonymous
# Preference JWTs remain the authority for display fields; this projection reads only the active
# realm row and browser-bound state for an HTML request.
module BasePreferenceActorProjection
  extend ActiveSupport::Concern

  include PreferenceBrowserStateReader

  public

  def cookie_context
    context = super
    region = base_anonymous_actor_region
    region ? context.merge(ri: region) : context
  end

  private

  def hydrate_base_preference_actor_state
    return unless (request.get? || request.head?) && request.format.html?
    return if controller_path.include?("/api/")

    load_access_token_payload unless @preference_payload.is_a?(Hash)
    payload = @preference_payload
    return unless payload.is_a?(Hash) && payload["aud"] == preference_realm_name

    region = base_anonymous_actor_region
    cookie_state = cookie_consent_state(fail_on_read_error: true)
    receipt = @base_preference_actor_consent_receipt
    cookie_state = cookie_state.merge(
      consent_version: receipt&.version,
      consented_at: receipt&.recorded_at,
    )
    web_push = ((preference_realm_name == "com") ? readable_com_web_push : readable_realm_web_push)

    preference = Actor.preferences.with_browser_state(
      cookie: cookie_state,
      web_push: web_push,
      region: region || Actor.preferences.region,
    )
    Actor.install_context!(preferences: preference_with_request_overlay(preference))
  rescue ActiveRecord::ActiveRecordError, PreferenceBase::ResolutionError => e
    Rails.logger.error(
      JitLogEvent.format(
        "preference.actor_browser_state.read_failed",
        realm: preference_realm_name,
        error_class: e.class.name,
      ),
    )
  end

  def base_anonymous_actor_region
    return unless (request.get? || request.head?) && @preference_payload.is_a?(Hash)
    return unless @preference_payload["aud"] == preference_realm_name
    return anonymous_com_actor_region if preference_realm_name == "com"

    public_id = PreferenceToken.extract_public_id(@preference_payload)
    return if public_id.blank?

    preference_class.connection_class_for_self.connected_to(role: :reading) do
      preference = preference_class.find_by(
        public_id: public_id, status_id: preference_class::ACTIVE_STATUS_ID,
      )
      now = preference_class.database_now
      next unless preference&.issuance_active_at?(now: now) && now.to_i < @preference_payload.fetch("exp")

      prefix = preference_realm_name.capitalize
      region = PreferenceClassRegistry.record_class(prefix, :region).find_by(preference_id: preference.id)
      next unless region

      option = PreferenceClassRegistry.option_class(prefix, :region).find_by(id: region.option_id)
      value = option&.name&.downcase
      raise PreferenceBase::ResolutionError, "unknown #{preference_realm_name} preference region" unless
        %w(jp us).include?(value)

      value
    end
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error(
      JitLogEvent.format(
        "preference.actor_region.read_failed",
        realm: preference_realm_name,
        error_class: e.class.name,
      ),
    )
    nil
  end
end

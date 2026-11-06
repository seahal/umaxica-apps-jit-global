# typed: false
# frozen_string_literal: true

require "jwt"

# Read-only resolution for browser-bound anonymous Preference state. The Base Actor projection and
# browser API share the same active-row, expiry, receipt, binding, and realm checks.
module PreferenceBrowserStateReader
  extend ActiveSupport::Concern

  CONSENT_RECEIPT_CLASSES = {
    "app" => AppPreferenceConsentReceipt,
    "org" => OrgPreferenceConsentReceipt,
    "com" => ComPreferenceConsentReceipt,
  }.freeze
  BROWSER_BINDING_CLASSES = {
    "app" => AppPreferenceBrowserBinding,
    "org" => OrgPreferenceBrowserBinding,
    "com" => ComPreferenceBrowserBinding,
  }.freeze

  private

  def cookie_consent_state(fail_on_read_error: false)
    return @cookie_consent_state_override if @cookie_consent_state_override

    return anonymous_com_cookie_consent_state(fail_on_read_error:) if anonymous_com_claim_shape?(preference_class)
    return anonymous_realm_cookie_consent_state if %w(AppPreference OrgPreference).include?(preference_class.name)

    raise PreferenceBase::ResolutionError, "unsupported Preference consent model"
  end

  def anonymous_com_cookie_consent_state(fail_on_read_error:)
    @com_consent_decision_available = false
    @base_preference_actor_consent_receipt = nil
    payload = decoded_preference_payload
    public_id = PreferenceToken.extract_public_id(payload)
    empty = { consented: false, functional: false, performant: false, targetable: false }
    return empty if public_id.blank?

    preference_class.connection_class_for_self.connected_to(role: :reading) do
      preference = preference_class.find_by(
        public_id: public_id, status_id: ComPreferenceStatus::ACTIVE,
      )
      now = preference_class.database_now
      if preference&.issuance_active_at?(now: now) && now.to_i < payload.fetch("exp")
        cookie = ComPreferenceCookie.find_by(preference_id: preference.id)
        if cookie
          receipt = matching_browser_consent_receipt(realm: "com", preference: preference)
          @com_consent_decision_available = receipt.present? && browser_binding_matches?(cookie)
          @base_preference_actor_consent_receipt = receipt if @com_consent_decision_available
          return readable_cookie_state(cookie)
        end
      end
    end
    empty
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
    Rails.logger.error(
      JitLogEvent.format("preference.consent.read_failed", realm: "com", error_class: e.class.name),
    )
    raise PreferenceBase::ResolutionError, "Preference consent state is unavailable" if fail_on_read_error

    empty
  end

  def anonymous_realm_cookie_consent_state
    @cookie_consent_decision_available = false
    @base_preference_actor_consent_receipt = nil
    empty = { consented: false, functional: false, performant: false, targetable: false }

    family, surface = controller_path.split("/", 3)
    if %w(auth core warp).include?(family)
      raise PreferenceBase::ResolutionError, "Preference consent reads belong to Base" unless
        surface == preference_realm_name

      return empty
    end
    raise PreferenceBase::ResolutionError, "unsupported Preference consent reader: #{family.inspect}" unless
      family == "base" && surface == preference_realm_name

    payload = decoded_preference_payload
    public_id = PreferenceToken.extract_public_id(payload)
    return empty if public_id.blank?

    realm = preference_realm_name
    prefix = realm.capitalize
    preference_class.connection_class_for_self.connected_to(role: :reading) do
      preference = preference_class.find_by(public_id:, status_id: preference_class::ACTIVE_STATUS_ID)
      now = preference_class.database_now
      return empty unless preference&.issuance_active_at?(now:) && now.to_i < payload.fetch("exp")

      cookie = PreferenceClassRegistry.cookie_class(prefix).find_by(preference_id: preference.id)
      return empty unless cookie

      receipt = matching_browser_consent_receipt(realm: realm, preference: preference)
      @cookie_consent_decision_available = receipt.present?
      @base_preference_actor_consent_receipt = receipt if @cookie_consent_decision_available
      return empty unless @cookie_consent_decision_available

      readable_cookie_state(cookie)
    end
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
    Rails.logger.error(
      JitLogEvent.format("preference.consent.read_failed", realm:, error_class: e.class.name),
    )
    raise PreferenceBase::ResolutionError, "Preference consent state is unavailable"
  end

  def readable_realm_web_push
    payload = decoded_preference_payload
    public_id = PreferenceToken.extract_public_id(payload)
    return "disabled" if public_id.blank?

    realm = preference_realm_name
    preference_class.connection_class_for_self.connected_to(role: :reading) do
      preference = preference_class.find_by(public_id:, status_id: preference_class::ACTIVE_STATUS_ID)
      now = preference_class.database_now
      return "disabled" unless preference&.issuance_active_at?(now:) && now.to_i < payload.fetch("exp")

      binding_class = ((realm == "app") ? AppPreferenceBrowserBinding : OrgPreferenceBrowserBinding)
      binding = binding_class.find_by(preference_id: preference.id)
      return "disabled" unless binding &&
        PreferenceBrowserBinding.matches?(cookies[PreferenceBrowserBinding::COOKIE_NAME], binding.digest)

      web_push_class = ((realm == "app") ? AppPreferenceWebPush : OrgPreferenceWebPush)
      option_class = ((realm == "app") ? AppPreferenceWebPushOption : OrgPreferenceWebPushOption)
      web_push = web_push_class.find_by(preference_id: preference.id)
      option = option_class.find_by(id: web_push&.option_id)
      option&.name || "disabled"
    end
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
    Rails.logger.error(
      JitLogEvent.format("preference.web_push.read_failed", realm:, error_class: e.class.name),
    )
    raise PreferenceBase::ResolutionError, "Preference Web Push state is unavailable"
  end

  def readable_com_web_push
    raise PreferenceBase::ResolutionError, "unsupported Preference Web Push reader" unless
      preference_class.name == "ComPreference"

    payload = decoded_preference_payload
    public_id = PreferenceToken.extract_public_id(payload)
    return "disabled" if public_id.blank?

    with_preference_connection(:writing) do
      ComPreference.transaction do
        preference = ComPreference.lock.find_by(
          public_id: public_id, status_id: ComPreferenceStatus::ACTIVE,
        )
        now = ComPreference.database_now
        return "disabled" unless preference&.issuance_active_at?(now: now) && now.to_i < payload.fetch("exp")

        binding = ComPreferenceBrowserBinding.find_by(preference_id: preference.id)
        return "disabled" unless binding &&
          PreferenceBrowserBinding.matches?(cookies[PreferenceBrowserBinding::COOKIE_NAME], binding.digest)

        push = ComPreferenceWebPush.find_by(preference_id: preference.id)
        option = ComPreferenceWebPushOption.find_by(id: push&.option_id)
        option&.name || "disabled"
      end
    end
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
    Rails.logger.error(JitLogEvent.format("preference.web_push.read_failed", realm: "com", error_class: e.class.name))
    "disabled"
  end

  def matching_browser_consent_receipt(realm:, preference:)
    receipt = CONSENT_RECEIPT_CLASSES.fetch(realm).find_by(preference_id: preference.id)
    binding = BROWSER_BINDING_CLASSES.fetch(realm).find_by(preference_id: preference.id)
    return unless receipt && binding
    return unless PreferenceBrowserBinding.matches?(cookies[PreferenceBrowserBinding::COOKIE_NAME], binding.digest)

    receipt
  end

  # SSOT decode point.
  def decode_and_verify_preference_jwt(jwt)
    payload = decode_matching_access_token(jwt)
    return payload if payload.is_a?(Hash)

    Rails.logger.info(I18n.t("errors.preference.cookie.invalid_access_token"))
    nil
  end

  def decoded_preference_payload
    @decoded_preference_payload ||=
      begin
        jwt = matching_access_token_value
        decode_and_verify_preference_jwt(jwt)
      end
  end
end

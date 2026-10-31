# typed: false
# frozen_string_literal: true

require "jwt"

module PreferenceWebCookieEndpoint
  extend ActiveSupport::Concern
  include PreferenceBase

  COOKIE_CONSENT_FIELDS = %w(consented functional performant targetable).freeze

  private

  def cookie_consent_state
    return @cookie_consent_state_override if @cookie_consent_state_override

    return anonymous_com_cookie_consent_state if anonymous_com_claim_shape?(preference_class)
    return anonymous_realm_cookie_consent_state if %w(AppPreference OrgPreference).include?(preference_class.name)

    raise PreferenceBase::ResolutionError, "unsupported Preference consent model"
  end

  def anonymous_com_cookie_consent_state
    @com_consent_decision_available = false
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
          @com_consent_decision_available = ComPreferenceConsentReceipt.exists?(preference_id: preference.id) &&
            browser_binding_matches?(cookie)
          return readable_cookie_state(cookie)
        end
      end
    end
    empty
  end

  def show_banner?
    state = cookie_consent_state
    return !@com_consent_decision_available if anonymous_com_claim_shape?(preference_class)
    return !@cookie_consent_decision_available if anonymous_preference_claim_shape?(preference_class)

    !state.fetch(:consented)
  end

  # `requested` is an already read consent decision (`cookie_consent_request`).
  def apply_cookie_consent_update!(requested)
    if anonymous_com_claim_shape?(preference_class)
      persist_anonymous_com_cookie_consent!(requested)
      return
    end
    if anonymous_preference_claim_shape?(preference_class)
      persist_anonymous_realm_cookie_consent!(requested)
      return
    end

    raise PreferenceBase::ResolutionError, "unsupported Preference consent model"
  rescue StandardError => e
    Rails.logger.error("[PreferenceWebCookieEndpoint] consent update failed: #{e.class}")
    raise
  end

  def persist_anonymous_com_cookie_consent!(attrs)
    raw_binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]

    issuance =
      write_preference!(
        operation: :save, actor: Actor.current,
        submitted: attrs,
      ) do |preference, decision_time, submitted|
        raw_binding = PreferenceBrowserBinding.mint_value unless PreferenceBrowserBinding.valid_value?(raw_binding)
        cookie = load_or_create_preference_cookie!(preference)
        require_matching_existing_browser_binding!(cookie, raw_binding)
        receipt = ComPreferenceConsentReceipt.find_or_initialize_by(preference_id: preference.id)
        if receipt.new_record?
          cookie.update!({ consented: false, functional: false, performant: false, targetable: false }.merge(submitted))
        else
          cookie.update!(submitted)
        end
        receipt.update!(version: SecureRandom.uuid, recorded_at: decision_time)
        store_com_browser_binding!(preference.id, raw_binding)
      end

    write_browser_binding_cookie(raw_binding, expires_at: issuance.expires_at)
    @cookie_consent_state_override = attrs.slice(:consented, :functional, :performant, :targetable)
  end

  def anonymous_realm_cookie_consent_state
    @cookie_consent_decision_available = false
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

      receipt_class = realm == "app" ? AppPreferenceConsentReceipt : OrgPreferenceConsentReceipt
      binding_class = realm == "app" ? AppPreferenceBrowserBinding : OrgPreferenceBrowserBinding
      binding = binding_class.find_by(preference_id: preference.id)
      @cookie_consent_decision_available = receipt_class.exists?(preference_id: preference.id) && binding &&
        PreferenceBrowserBinding.matches?(cookies[PreferenceBrowserBinding::COOKIE_NAME], binding.digest)
      return empty unless @cookie_consent_decision_available

      readable_cookie_state(cookie)
    end
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
    Rails.logger.error(
      JitLogEvent.format("preference.consent.read_failed", realm:, error_class: e.class.name),
    )
    raise PreferenceBase::ResolutionError, "Preference consent state is unavailable"
  end

  def persist_anonymous_realm_cookie_consent!(attrs)
    write_preference!(
      operation: :save, actor: preference_write_actor,
      submitted: attrs,
    )
    @cookie_consent_state_override = attrs.slice(:consented, :functional, :performant, :targetable)
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

      binding_class = realm == "app" ? AppPreferenceBrowserBinding : OrgPreferenceBrowserBinding
      binding = binding_class.find_by(preference_id: preference.id)
      return "disabled" unless binding &&
        PreferenceBrowserBinding.matches?(cookies[PreferenceBrowserBinding::COOKIE_NAME], binding.digest)

      web_push_class = realm == "app" ? AppPreferenceWebPush : OrgPreferenceWebPush
      option_class = realm == "app" ? AppPreferenceWebPushOption : OrgPreferenceWebPushOption
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

  def preference_class
    @preference_class ||= PreferenceClassRegistry.for_controller_path(controller_path)
  end

  # true or false for an accepted spelling, nil for anything else (including nil itself).
  def cookie_boolean(value)
    case value
    when true, false
      value
    when 1, "1", "true", "TRUE", "t", "T"
      true
    when 0, "0", "false", "FALSE", "f", "F"
      false
    end
  end

  # The consent decision of a browser API request, read strictly: every consent field that is
  # present must be an accepted boolean, and `consented` must be present. Returns
  # `{ attrs:, invalid_pointers: }`; `attrs` is nil whenever `invalid_pointers` is not empty.
  # Keys outside the four consent fields are ignored, as they always were.
  def cookie_consent_request
    if params.key?(:consented)
      consented = cookie_boolean(params[:consented])
      return { attrs: nil, invalid_pointers: ["/consented"] } if consented.nil?

      return { attrs: default_cookie_consent_attrs(consented), invalid_pointers: [] }
    end

    raw = params[:cookie]
    raw = raw.to_unsafe_h if raw.is_a?(ActionController::Parameters)
    return { attrs: nil, invalid_pointers: ["/cookie/consented"] } if raw.nil?
    return { attrs: nil, invalid_pointers: ["/cookie"] } unless raw.is_a?(Hash)

    fields = raw.with_indifferent_access.slice(*COOKIE_CONSENT_FIELDS)
    return { attrs: nil, invalid_pointers: ["/cookie/consented"] } unless fields.key?(:consented)

    values = fields.to_h.transform_values { |value| cookie_boolean(value) }
    invalid = COOKIE_CONSENT_FIELDS.select { |field| fields.key?(field) && values[field].nil? }
    return { attrs: nil, invalid_pointers: invalid.map { |field| "/cookie/#{field}" } } if invalid.any?

    attrs = default_cookie_consent_attrs(values.fetch("consented"))
      .merge(values.except("consented").symbolize_keys)
    { attrs: attrs, invalid_pointers: [] }
  end

  def default_cookie_consent_attrs(consented)
    {
      consented: consented,
      functional: consented,
      performant: consented,
      targetable: consented,
    }
  end

  def load_or_create_preference_cookie!(preference)
    record_class = PreferenceClassRegistry.cookie_class(preference_prefix(preference))
    relation = record_class.where(preference_id: preference.id)
    cookie = relation.first
    return cookie if cookie.present?

    default_attrs = {
      targetable: false,
      performant: false,
      functional: false,
      consented: false,
    }
    relation.create!(default_attrs)
  end

end

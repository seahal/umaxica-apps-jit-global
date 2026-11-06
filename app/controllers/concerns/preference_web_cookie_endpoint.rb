# typed: false
# frozen_string_literal: true

module PreferenceWebCookieEndpoint
  extend ActiveSupport::Concern
  include PreferenceBase
  include PreferenceBrowserStateReader

  COOKIE_CONSENT_FIELDS = %w(consented functional performant targetable).freeze

  private

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
  end

  def persist_anonymous_realm_cookie_consent!(attrs)
    write_preference!(
      operation: :save, actor: preference_write_actor,
      submitted: attrs,
    )
    @cookie_consent_state_override = attrs.slice(:consented, :functional, :performant, :targetable)
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

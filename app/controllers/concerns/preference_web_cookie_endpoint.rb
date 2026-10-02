# typed: false
# frozen_string_literal: true

require "jwt"

module PreferenceWebCookieEndpoint
  extend ActiveSupport::Concern
  include PreferenceBase
  include PreferenceConsentedBuffer
  include PreferenceResourceSync

  COOKIE_CONSENT_FIELDS = %w(consented functional performant targetable).freeze

  private

  def cookie_consent_state
    return @cookie_consent_state_override if @cookie_consent_state_override

    payload = decoded_preference_payload
    preferences = payload.is_a?(Hash) ? payload["preferences"] : nil

    if preferences.is_a?(Hash)
      {
        consented: ActiveModel::Type::Boolean.new.cast(preferences["consented"]),
        functional: ActiveModel::Type::Boolean.new.cast(preferences["functional"]),
        performant: ActiveModel::Type::Boolean.new.cast(preferences["performant"]),
        targetable: ActiveModel::Type::Boolean.new.cast(preferences["targetable"]),
      }
    else
      { consented: false, functional: false, performant: false, targetable: false }
    end
  rescue StandardError => e
    Rails.logger.warn("[PreferenceWebCookieEndpoint] cookie_consent_state fallback: #{e.class}")
    { consented: false, functional: false, performant: false, targetable: false }
  end

  def show_banner?
    !cookie_consent_state.fetch(:consented)
  end

  def set_consented_buffer_cookie!
    set_preference_consented_buffer!(
      consented: extract_cookie_consented(decoded_preference_payload),
      expires_at: refresh_token_expires_at || PreferenceBase::REFRESH_TOKEN_TTL.from_now,
    )
  end

  def sync_consented_buffer_cookie_safely!
    set_consented_buffer_cookie!
  rescue StandardError => e
    Rails.logger.warn("[PreferenceWebCookieEndpoint] buffer sync skipped: #{e.class}")
  end

  # The `/edge/v0/cookie` entry point: reads the request leniently (a missing decision is a no-op,
  # an unreadable boolean is a 400) and applies it.
  def apply_consented_update_from_request!
    requested = requested_cookie_consent_attrs
    return false if requested.blank?

    apply_cookie_consent_update!(requested)
    true
  end

  # `requested` is an already read consent decision (`cookie_consent_request` or
  # `requested_cookie_consent_attrs`).
  def apply_cookie_consent_update!(requested)
    ensure_preference_access_token_audience_for_write!

    if decoded_preference_payload&.dig("public_id").blank?
      apply_buffer_only_cookie_consent!(requested)
      return
    end

    persist_cookie_consent!(requested)
  rescue StandardError => e
    Rails.logger.error("[PreferenceWebCookieEndpoint] consent update failed: #{e.class}")
    raise
  end

  def apply_buffer_only_cookie_consent!(attrs)
    set_preference_consented_buffer!(
      consented: attrs.fetch(:consented),
      expires_at: PreferenceBase::REFRESH_TOKEN_TTL.from_now,
    )
    @cookie_consent_state_override = attrs.slice(:consented, :functional, :performant, :targetable)
  end

  # SSOT decode point.
  def decode_and_verify_preference_jwt(jwt)
    payload = decode_matching_access_token(jwt)
    return payload if payload.is_a?(Hash)

    Rails.logger.info(I18n.t("errors.preference.cookie.invalid_access_token"))
    nil
  end

  def extract_cookie_consented(payload)
    return false unless payload.is_a?(Hash)

    preferences = payload["preferences"]
    return false unless preferences.is_a?(Hash)

    ActiveModel::Type::Boolean.new.cast(preferences["consented"])
  end

  def decoded_preference_payload
    @decoded_preference_payload ||=
      begin
        jwt = matching_access_token_value
        decode_and_verify_preference_jwt(jwt)
      end
  end

  def refresh_token_expires_at
    public_id = decoded_preference_payload&.dig("public_id")
    record = find_preference_by_public_id(public_id)
    expires_at = record&.expires_at
    return expires_at if expires_at.present? && !expires_at.is_a?(Float)

    nil
  rescue StandardError => e
    Rails.logger.warn("[PreferenceWebCookieEndpoint] refresh expiry fallback: #{e.class}")
    nil
  end

  def find_preference_by_public_id(public_id)
    return nil if public_id.blank?

    with_preference_connection(:reading) do
      preference_class.find_by(public_id: public_id)
    end
  end

  def preference_class
    @preference_class ||= PreferenceClassRegistry.for_controller_path(controller_path)
  end

  def refresh_token_value
    cookies[refresh_token_cookie_name]
  end

  def requested_cookie_consent_attrs
    if params.key?(:consented)
      consented = cast_cookie_boolean(params[:consented])
      return default_cookie_consent_attrs(consented)
    end

    cookie_params = params[:cookie]
    return nil unless cookie_params.is_a?(ActionController::Parameters) || cookie_params.is_a?(Hash)

    # Both branches read the same fixed set of keys and ignore the rest. The Hash branch
    # already narrowed first; the Parameters branch did not, so anything else the payload
    # carried read as unpermitted rather than as simply not ours.
    consent_keys = %i(consented functional performant targetable)
    cookie_params =
      if cookie_params.is_a?(ActionController::Parameters)
        cookie_params.slice(*consent_keys).permit(*consent_keys).to_h
      else
        cookie_params.to_h.slice(*consent_keys)
      end.with_indifferent_access
    return nil unless cookie_params.key?(:consented)

    consented = cast_cookie_boolean(cookie_params[:consented])
    default_cookie_consent_attrs(consented).merge(
      cookie_params.slice(:functional, :performant, :targetable).transform_values do |value|
        cast_cookie_boolean(value)
      end,
    )
  end

  def cast_cookie_boolean(value)
    cast = cookie_boolean(value)
    raise ActionController::BadRequest, "invalid_cookie_consent" if cast.nil?

    cast
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
      consented: true,
      functional: consented,
      performant: consented,
      targetable: consented,
    }
  end

  def persist_cookie_consent!(attrs)
    public_id = decoded_preference_payload&.dig("public_id")
    raise RuntimeError, "missing_preference_access_token" if public_id.blank?

    with_preference_connection(:writing) do
      preference_class.transaction do
        preference = preference_class.lock.find_by(public_id: public_id)
        raise ActiveRecord::RecordNotFound, "preference_not_found" if preference.blank?

        @preferences = preference
        cookie = load_or_create_preference_cookie!(preference)
        attrs = attrs.dup
        attrs[:consented_at] = attrs[:consented] ? (cookie.consented_at || Time.current) : nil

        resource_pref = preference_write_resource_preference!
        authorize_resource_preference_write!(resource_pref)
        write_resource_preference_cookie!(resource_pref, attrs) if resource_pref

        cookie.update!(attrs)

        preference.reload
        issue_access_token_from(preference)
        raise RuntimeError, "failed_to_issue_preference_access_token" if @preference_payload.blank?

        @cookie_consent_state_override = attrs.slice(:consented, :functional, :performant, :targetable)
        set_preference_consented_buffer!(
          consented: @cookie_consent_state_override.fetch(:consented),
          expires_at: consented_buffer_expires_at(preference),
        )
        @decoded_preference_payload = nil
      end
    end
  end

  def load_or_create_preference_cookie!(preference)
    association_name = "#{preference.class.name.underscore}_cookie"
    cookie = preference.public_send(association_name)
    return cookie if cookie.present?

    default_attrs = {
      targetable: false,
      performant: false,
      functional: false,
      consented: false,
    }
    preference.public_send("create_#{association_name}!", default_attrs)
  end

  def consented_buffer_expires_at(preference)
    expires_at = preference&.expires_at
    return expires_at if expires_at.present? && !expires_at.is_a?(Float)

    PreferenceBase::REFRESH_TOKEN_TTL.from_now
  end
end

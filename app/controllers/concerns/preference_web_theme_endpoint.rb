# typed: false
# frozen_string_literal: true

module PreferenceWebThemeEndpoint
  extend ActiveSupport::Concern
  include PreferenceBase

  private

  def current_color_theme
    return theme_from_preference_payload || "sy" if anonymous_preference_claim_shape?(preference_class)

    theme_from_preference_payload || "sy"
  end

  def theme_from_preference_payload
    payload = decoded_theme_preference_payload
    return nil if payload.blank?

    preferences = PreferenceToken.extract_preferences(payload)
    key = anonymous_preference_claim_shape?(preference_class) ? "theme" : "ct"
    normalize_theme(preferences[key])
  end

  # `short_code` is an already validated theme code (`requested_theme_value`).
  def apply_theme_update!(short_code)
    if anonymous_com_claim_shape?(preference_class)
      write_preference!(
        operation: :save, actor: Actor.current,
        submitted: { theme: short_code },
      ) do |preference, _time, submitted|
        option_id = {
          "li" => ComPreferenceThemeOption::LIGHT,
          "dr" => ComPreferenceThemeOption::DARK,
          "sy" => ComPreferenceThemeOption::SYSTEM,
        }.fetch(submitted.fetch(:theme))
        load_or_create_theme_child(preference).update!(option_id: option_id)
      end
      return short_code
    end
    if anonymous_preference_claim_shape?(preference_class)
      write_preference!(
        operation: :save, actor: preference_write_actor,
        submitted: { theme: PreferenceBase::THEME_OPTION_MAP.fetch(short_code) },
      )
      return short_code
    end

    raise PreferenceBase::ResolutionError, "unsupported Preference theme model"
  rescue StandardError => e
    Rails.logger.error("[PreferenceWebThemeEndpoint] theme update failed: #{e.class}")
    raise
  end

  # The requested theme code, or nil when the request names no accepted theme. A nil here is a
  # refused request, not "keep the current theme".
  def requested_theme_value
    raw_value = params.to_unsafe_h["theme"]
    return nil unless raw_value.is_a?(String)

    normalize_theme(raw_value)
  end

  def decoded_theme_preference_payload
    @decoded_theme_preference_payload ||= decode_theme_jwt
  end

  def decode_theme_jwt
    jwt = matching_access_token_value
    return nil if jwt.blank?

    decode_matching_access_token(jwt)
  end

  def load_or_create_theme_child(preference)
    record_class = PreferenceClassRegistry.record_class(preference_prefix(preference), :theme)
    relation = record_class.where(preference_id: preference.id)
    child = relation.first
    return child if child.present?

    option_class = PreferenceClassRegistry.option_class(preference_prefix, :theme)
    relation.create!(option_id: option_class::SYSTEM)
  end
end

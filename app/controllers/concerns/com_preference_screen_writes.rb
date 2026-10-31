# typed: false
# frozen_string_literal: true

# Shared com screen writers; callers supply their own statically selected screen.
module ComPreferenceScreenWrites
  extend ActiveSupport::Concern
  include ::ComSelectablePreferenceScreen
  include ::PreferenceWebThemeEndpoint
  include ::PreferenceWebCookieEndpoint

  protected

  def update_theme_preference_screen
    raw = preference_theme_params[:option_id]
    raw = raw.downcase if raw.is_a?(String)
    code =
      case raw
      when 1, "1", "li", "light" then "li"
      when 2, "2", "dr", "dark" then "dr"
      when 3, "3", "sy", "system" then "sy"
      end
    return head :unprocessable_content if code.nil?

    apply_theme_update!(code)
    return render_preference_update_response if request.format.json?

    redirect_to(
      safe_pt_path || preference_edit_url(:theme, preference_write_redirect_params(except: :ct)),
      status: :see_other,
    )
  end

  def update_cookie_preference_screen
    submitted = preference_cookie_params.to_h.slice(*PreferenceWebCookieEndpoint::COOKIE_CONSENT_FIELDS)
    values = submitted.transform_values { |value| cookie_boolean(value) }
    return head :unprocessable_content if values.empty? || values.values.any?(&:nil?)

    persist_anonymous_com_cookie_consent!(values.symbolize_keys)
    return render_preference_update_response if request.format.json?

    redirect_to(preference_edit_url(:cookie, preference_context_redirect_params), status: :see_other)
  end

  def update_selectable_preference_screen(screen)
    return super unless screen == :currency

    raw = selectable_preference_params(:currency)[:option_id]
    raw = raw.downcase if raw.is_a?(String)
    option_id =
      case raw
      when 1, "1", "usd" then ComPreferenceCurrencyOption::USD
      when 2, "2", "jpy" then ComPreferenceCurrencyOption::JPY
      end
    return head :unprocessable_content if option_id.nil?

    write_preference!(
      operation: :save, actor: Actor.current,
      submitted: { currency: option_id },
    ) do |preference, _time, submitted|
      currency = ComPreferenceCurrency.find_or_initialize_by(preference_id: preference.id)
      currency.update!(option_id: submitted.fetch(:currency))
    end
    return render_preference_update_response if request.format.json?

    redirect_to(
      preference_edit_url(:currency, preference_write_redirect_params(except: :cu)), status: :see_other,
    )
  end

  def update_region_preference_screen
    raw = preference_region_params[:option_id]
    raw = raw.downcase if raw.is_a?(String)
    region_id =
      case raw
      when 1, "1", "us" then ComPreferenceRegionOption::US
      when 2, "2", "jp" then ComPreferenceRegionOption::JP
      end
    return head :unprocessable_content if region_id.nil?

    defaults = regional_default_option_ids(region_id)
    raise PreferenceBase::ResolutionError, "missing regional preference defaults" unless defaults

    write_preference!(
      operation: :save, actor: Actor.current,
      submitted: defaults.merge(region: region_id),
    ) do |preference, _time, submitted|
      [ComPreferenceRegionOption, ComPreferenceLanguageOption, ComPreferenceDateFormatOption,
       ComPreferenceTimeFormatOption, ComPreferenceCurrencyOption,].each { |klass| ensure_model_defaults!(klass) }
      [[ComPreferenceRegion, submitted.fetch(:region)], [ComPreferenceLanguage, submitted.fetch(:language)],
       [ComPreferenceDateFormat, submitted.fetch(:date_format)],
       [ComPreferenceTimeFormat, submitted.fetch(:time_format)],
       [ComPreferenceCurrency, submitted.fetch(:currency)],].each do |klass, option_id|
        klass.find_or_initialize_by(preference_id: preference.id).update!(option_id: option_id)
      end
    end

    redirect_to(preference_edit_url(:region, preference_write_redirect_params(except: :ri)), status: :see_other)
  end
end

# typed: false
# frozen_string_literal: true

# Base com selectable screens opt in to the shared preference write transaction. The includer
# provides the screen dispatch, request context, validated token reader and response helpers.
module ComSelectablePreferenceScreen
  extend ActiveSupport::Concern

  protected

  def edit_language_preference_screen
    super
  end

  def update_language_preference_screen
    saved = write_com_option!(
      ComPreferenceLanguageOption, ComPreferenceLanguage, preference_language_params[:option_id],
    )
    return head :unprocessable_content unless saved

    redirect_to(preference_edit_url(:language, language_preference_redirect_params), status: :see_other)
  end

  def update_timezone_preference_screen
    saved = write_com_option!(
      ComPreferenceTimezoneOption, ComPreferenceTimezone, preference_timezone_params[:option_id],
    )
    return head :unprocessable_content unless saved

    redirect_to(preference_edit_url(:timezone, preference_write_redirect_params(except: :tz)), status: :see_other)
  end

  def update_selectable_preference_screen(screen)
    option_class, record_class =
      case screen
      when :date_format then [ComPreferenceDateFormatOption, ComPreferenceDateFormat]
      when :time_format then [ComPreferenceTimeFormatOption, ComPreferenceTimeFormat]
      when :motion then [ComPreferenceMotionOption, ComPreferenceMotion]
      when :density then [ComPreferenceDensityOption, ComPreferenceDensity]
      when :page_size then [ComPreferencePageSizeOption, ComPreferencePageSize]
      else raise ArgumentError, "unsupported com preference screen"
      end

    saved = write_com_option!(option_class, record_class, selectable_preference_params(screen)[:option_id])
    return head :unprocessable_content unless saved
    return render_preference_update_response if request.format.json?

    redirect_to(
      preference_edit_url(screen, preference_write_redirect_params(except: preference_context_key_for_screen(screen))),
      status: :see_other,
    )
  end

  private

  def write_com_option!(option_class, record_class, raw)
    return false unless raw.is_a?(String) || raw.is_a?(Integer)

    value = raw.to_s.downcase
    options = option_class::DEFAULTS.map { |id| option_class.new(id: id) }
    options.select! { |candidate| candidate.name.present? }
    option = options.find { |candidate| candidate.id == value.to_i } if value.match?(/\A[0-9]+\z/)
    option ||= options.find { |candidate| candidate.name.downcase == value }
    return false if option.nil?

    write_preference!(
      operation: :save, actor: Actor.current,
      submitted: { option_id: option.id },
    ) do |preference, _time, submitted|
      ensure_model_defaults!(option_class)
      record = record_class.find_or_initialize_by(preference_id: preference.id)
      record.update!(option_id: submitted.fetch(:option_id))
    end
    true
  end

  def set_preferences_cookie
    return if preference_write_request?

    super
  end

  def ensure_preferences_record
    return if preference_write_request?

    super
  end

  def render_preference_dependency_failure
    head :service_unavailable
  end
end

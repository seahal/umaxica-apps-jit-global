# typed: false
# frozen_string_literal: true

module PreferenceSignScreenActions
  extend ActiveSupport::Concern
  include PreferenceCore

  protected

  def edit_region_preference_screen
    set_region_preferences_edit
  end

  def update_region_preference_screen
    ensure_preference_access_token_audience_for_write!
    set_region_preferences_update
    redirect_to(
      preference_edit_url(:region, preference_write_redirect_params(except: :ri)),
    )
  end

  def edit_language_preference_screen
    set_language_preferences_edit
  end

  def update_language_preference_screen
    ensure_preference_access_token_audience_for_write!
    set_language_preferences_update
    apply_language_preference_to_session
    redirect_to(
      preference_edit_url(:language, language_preference_redirect_params),
    )
  end

  def edit_timezone_preference_screen
    set_timezone_preferences_edit
  end

  def update_timezone_preference_screen
    ensure_preference_access_token_audience_for_write!
    set_timezone_preferences_update
    redirect_to(
      preference_edit_url(:timezone, preference_write_redirect_params(except: :tz)),
    )
  rescue PreferenceOperationError
    redirect_to(
      preference_edit_url(:timezone, preference_write_redirect_params(except: :tz)),
    )
  end

  def edit_theme_preference_screen
    set_theme_preferences_edit
  end

  def update_theme_preference_screen
    ensure_preference_access_token_audience_for_write!
    set_theme_preferences_update
    return render_preference_update_response if request.format.json?

    redirect_to(
      safe_pt_path || preference_edit_url(:theme, preference_write_redirect_params(except: :ct)),
    )
  end

  def edit_cookie_preference_screen
    set_cookie_preferences_edit
  end

  def update_cookie_preference_screen
    ensure_preference_access_token_audience_for_write!
    set_cookie_preferences_update
    return render_preference_update_response if request.format.json?

    redirect_to(
      preference_edit_url(:cookie, preference_context_redirect_params),
    )
  end

  def edit_reset_preference_screen
    @preference = @preferences
  end

  def destroy_reset_preference_screen
    ensure_preference_access_token_audience_for_write!
    @preference = @preferences
    @preference.require_reset_confirmation(params[:confirm_reset])

    unless @preference.valid?(:reset)
      # Inertia treats any response with a 4xx status as a transport exception rather than a page,
      # so validation failures go back to the edit screen carrying the errors, which is the
      # protocol's own convention. The middleware turns this into a 303 for the DELETE.
      redirect_to(
        reset_preference_edit_url,
        inertia: { errors: @preference.errors.to_hash(true).transform_values(&:first) },
      )
      return
    end

    reset_preference_by_rebootstrap!
    redirect_to(preference_index_path_without_context, status: :see_other)
  end

  def update_selectable_preference_screen(screen)
    ensure_preference_access_token_audience_for_write!
    set_selectable_preference_update(screen)
    return render_preference_update_response if request.format.json?

    redirect_to(
      preference_edit_url(screen, preference_write_redirect_params(except: preference_context_key_for_screen(screen))),
    )
  rescue PreferenceOperationError
    redirect_to(
      preference_edit_url(screen, preference_write_redirect_params(except: preference_context_key_for_screen(screen))),
    )
  end

  # The reset screen is routed as `customization`, which `preference_url_helper_name` does not map
  # (it answers `:reset` with a `..._preference_reset_url` helper no route defines).
  def reset_preference_edit_url
    public_send(
      "edit_#{preference_route_authority}_#{preference_surface_key}_preference_customization_url",
      compact_url_params(preference_context_redirect_params),
    )
  end

  def preference_index_path_without_context
    preference_index_url(PreferenceGlobal::PARAM_CONTEXT_KEYS.index_with { nil })
  end

  private :reset_preference_edit_url, :preference_index_path_without_context
end

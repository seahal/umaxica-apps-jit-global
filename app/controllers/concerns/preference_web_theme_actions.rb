# typed: false
# frozen_string_literal: true

# Actions of the browser theme endpoint. The including controller also includes
# PreferenceWebThemeEndpoint (the preference read/update) and PreferenceBrowserApi (the HTTP
# contract, `render_preference_browser_api_invalid_fields`).
module PreferenceWebThemeActions
  extend ActiveSupport::Concern

  public

  def show
    render json: { theme: current_color_theme }, status: :ok
  end

  def update
    theme = requested_theme_value
    if theme.nil?
      render_preference_browser_api_invalid_fields(["/theme"])
      return
    end

    apply_theme_update!(theme)
    render json: { theme: theme }, status: :ok
  end
end

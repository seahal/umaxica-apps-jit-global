# typed: false
# frozen_string_literal: true

# Actions of the browser cookie-consent endpoint. The including controller also includes
# PreferenceWebCookieEndpoint (the preference read/update) and PreferenceBrowserApi (the HTTP
# contract, `render_preference_browser_api_invalid_fields`).
module PreferenceWebCookieActions
  extend ActiveSupport::Concern

  public

  def show
    render json: { show_banner: show_banner? }, status: :ok
  end

  def update
    consent = cookie_consent_request
    if consent.fetch(:invalid_pointers).any?
      render_preference_browser_api_invalid_fields(consent.fetch(:invalid_pointers))
      return
    end

    apply_cookie_consent_update!(consent.fetch(:attrs))
    head :no_content
  end
end

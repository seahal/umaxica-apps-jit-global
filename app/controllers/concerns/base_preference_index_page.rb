# typed: false
# frozen_string_literal: true

# Props for the base preference index page, shared by the app, com, and org preference controllers.
#
# The three surfaces previously shared one ERB template (base/shared/preferences/show), so the page
# is an already-reviewed shared abstraction; this concern is the Inertia equivalent of that
# template. Every string is translated and every href is generated on the server, so the React
# component stays a pure renderer and the request context stays in Rails.
#
# The hrefs come from route helpers on purpose: PreferenceGlobal#default_url_options merges the
# resolved request context into each generated URL, so `ri` is always present and `lx`, `ct`, `tz`
# ride along whenever the request carried them.
module BasePreferenceIndexPage
  extend ActiveSupport::Concern

  # Screen route segment => i18n segment under base.<surface>.preferences.
  PREFERENCE_INDEX_SCREENS = {
    region: :region_settings,
    timezone: :timezone_settings,
    language: :language_settings,
    motion: :motion_settings,
    density: :density_settings,
    pagination: :pagination_settings,
    theme: :theme_settings,
    cookie: :cookie_settings,
    calendar: :calendar_settings,
    clock: :clock_settings,
    currency: :currency_settings,
    customization: :reset_settings,
  }.freeze

  private

  def preference_index_page_props
    {
      title: t(preference_base_i18n_key(:preferences, :title)),
      description: t(preference_base_i18n_key(:preferences, :description)),
      up_link: {
        label: t(preference_base_i18n_key(:preferences, :up_link)),
        href: preference_index_return_path,
      },
      screens: PREFERENCE_INDEX_SCREENS.map do |screen, label_key|
        {
          key: screen.to_s,
          label: t(preference_index_screen_i18n_key(label_key)),
          href: public_send(preference_index_screen_helper_name(screen)),
        }
      end,
    }
  end

  # Dashboard 404s for a guest and Home 404s for a member
  # (adr/home-dashboard-authentication-boundary.md), so the return target follows the session.
  def preference_index_return_path
    destination = logged_in? ? "dashboard" : "root"
    public_send("#{preference_route_authority}_#{preference_surface_key}_#{destination}_path")
  end

  def preference_index_screen_helper_name(screen)
    "edit_#{preference_route_authority}_#{preference_surface_key}_preference_#{screen}_path"
  end

  def preference_index_screen_i18n_key(label_key)
    segments = Array(label_key)
    preference_base_i18n_key(:preferences, *segments)
  end
end

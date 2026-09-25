# typed: false
# frozen_string_literal: true

# Props for the Warp control-plane settings screen, which is the same page on every Warp surface.
#
# It replaces `render plain: "Settings"`: Warp publishes browser HTML from Rails and every other
# screen on the surface is an Inertia page, so a plain-text body was the one route that dropped the
# surface chrome, the theme and the locale. The three surfaces differ only in the route helpers
# they resolve, so the surface is read from the controller path exactly as `WarpDashboardPage` does,
# and every URL is generated here rather than composed by React.
#
# The screen carries no controls yet. It is the shell the settings controls will be added to; it
# deliberately does not invent any, because a control the surface does not implement would be a
# claim the application cannot honour.
module WarpSettingsPage
  extend ActiveSupport::Concern

  include ::SurfaceInertiaPage

  private

  def settings_page_props
    surface = controller_path.split("/").second

    {
      title: "Settings",
      heading: "Settings",
      description: "Warp #{surface} control-plane settings.",
      links: [
        { label: "Root", href: warp_settings_url_for(surface, "warp_%{surface}_root_path") },
        { label: "Dashboard", href: warp_settings_url_for(surface, "warp_%{surface}_dashboard_path") },
        { label: "Sign out", href: warp_settings_url_for(surface, "new_warp_%{surface}_sign_out_path") },
      ],
    }
  end

  def warp_settings_url_for(surface, helper_template)
    public_send(format(helper_template, surface: surface), ri: params[:ri])
  end
end

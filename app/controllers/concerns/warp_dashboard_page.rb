# typed: false
# frozen_string_literal: true

# Props for the signed-in Warp landing, which is the same screen on every Warp surface.
#
# It replaces the previous dashboard template: the three surfaces differ only in
# the route helpers they resolve, so the surface is read from the controller path exactly as the
# shared template did, and every URL is generated here rather than composed by React.
module WarpDashboardPage
  extend ActiveSupport::Concern

  include ::SurfaceInertiaPage

  private

  def dashboard_page_props
    surface = controller_path.split("/").second

    {
      title: "Dashboard",
      heading: "Dashboard",
      description: "Warp #{surface} signed-in landing.",
      sections: [
        {
          title: "Primary links",
          links: [
            { label: "Root", href: warp_dashboard_url_for(surface, "warp_%{surface}_root_path") },
            { label: "Dashboard", href: warp_dashboard_url_for(surface, "warp_%{surface}_dashboard_path") },
            { label: "Settings", href: warp_dashboard_url_for(surface, "warp_%{surface}_settings_path") },
            { label: "Sign out", href: warp_dashboard_url_for(surface, "new_warp_%{surface}_sign_out_path") },
          ],
        },
        {
          title: "Protocol links",
          links: [
            {
              label: "Authorize",
              href: warp_dashboard_url_for(surface, "warp_%{surface}_sign_show_path"),
            },
          ],
        },
      ],
    }
  end

  def warp_dashboard_url_for(surface, helper_template)
    public_send(format(helper_template, surface: surface), ri: params[:ri])
  end
end

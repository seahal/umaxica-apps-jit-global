# typed: false
# frozen_string_literal: true

# Props for the signed-in Side landing, which is the same screen on every Side surface.
#
# It replaces `app/views/side/shared/dashboards/show.html.erb`: the three surfaces differ only in
# the route helpers they resolve, so the surface is read from the controller path exactly as the
# shared template did, and every URL is generated here rather than composed by React.
module SideDashboardPage
  extend ActiveSupport::Concern

  include ::SurfaceInertiaPage

  private

  def dashboard_page_props
    surface = controller_path.split("/").second

    {
      title: "Dashboard",
      heading: "Dashboard",
      description: "Side #{surface} signed-in landing.",
      sections: [
        {
          title: "Primary links",
          links: [
            { label: "Root", href: side_dashboard_url_for(surface, "side_%{surface}_root_path") },
            { label: "Dashboard", href: side_dashboard_url_for(surface, "side_%{surface}_dashboard_path") },
            { label: "Settings", href: side_dashboard_url_for(surface, "side_%{surface}_settings_path") },
            { label: "Sign out", href: side_dashboard_url_for(surface, "new_side_%{surface}_sign_out_path") },
          ],
        },
        {
          title: "Protocol links",
          links: [
            {
              label: "Authorize",
              href: side_dashboard_url_for(surface, "side_%{surface}_sign_in_path"),
            },
          ],
        },
      ],
    }
  end

  def side_dashboard_url_for(surface, helper_template)
    public_send(format(helper_template, surface: surface), ri: params[:ri])
  end
end

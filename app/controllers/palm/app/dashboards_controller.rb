# typed: false
# frozen_string_literal: true

module Palm
  module App
    class DashboardsController < Palm::App::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private
      before_action :authenticate_browser_rp!

      public

      def show
        authorize!(current_client, to: :show?)
        render inertia: "palm/app/dashboards/show", props: dashboard_page_props
      end

      private

      def dashboard_page_props
        {
          title: t("palm.app.dashboard.title"),
          description: t("palm.app.dashboard.description"),
          sections: [
            {
              heading: t("palm.app.dashboard.status_heading"),
              items: [
                { label: t("palm.app.dashboard.status"), href: nil },
                { label: t("palm.app.dashboard.sign_out"), href: edit_palm_app_sign_out_path(ri: params[:ri]) },
              ],
            },
          ],
        }
      end
    end
  end
end

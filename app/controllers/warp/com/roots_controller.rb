# typed: false
# frozen_string_literal: true

module Warp
  module Com
    class RootsController < Warp::Com::ApplicationController
      include ::WarpDashboardPage
      include ::SessionBoundaryNotFound

      AUTHENTICATION_MODE = :open

      public

      def index
        response.headers["Cache-Control"] = "private, no-store"
        return render_session_boundary_not_found if logged_in?

        render inertia: true, props: root_landing_props,
               clear_history: session.delete(:inertia_clear_history) == true
      end

      private

      # Home/Dashboard resolve regional context without redirecting a direct request.
      def set_region
        params[:ri] = normalized_param_ri.presence || get_region
      end

      def root_landing_props
        {
          title: nil,
          heading: "Warp Com",
          description: t("base.com.roots.message"),
          sign_up: nil,
          links: [
            { label: "Settings", href: warp_com_settings_path(ri: params[:ri]) },
            { label: t("actions.continue"), href: warp_com_sign_show_path(ri: params[:ri]) },
          ],
        }
      end
    end
  end
end

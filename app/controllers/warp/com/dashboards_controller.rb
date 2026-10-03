# typed: false
# frozen_string_literal: true

module Warp
  module Com
    class DashboardsController < Warp::Com::ApplicationController
      include ::WarpDashboardPage
      include ::SessionBoundaryNotFound

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open

      public

      def show
        response.headers["Cache-Control"] = "private, no-store"
        return render_session_boundary_not_found unless logged_in?

        authorize!(current_visitor, to: :show?)
        render inertia: "warp/com/dashboards/show", props: dashboard_page_props
      end

      private

      # Home/Dashboard resolve regional context without redirecting a direct request.
      def set_region
        params[:ri] = normalized_param_ri.presence || get_region
      end
    end
  end
end

# typed: false
# frozen_string_literal: true

module Warp
  module App
    class DashboardsController < Warp::App::ApplicationController
      include ::WarpDashboardPage

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open

      public

      def show
        response.headers["Cache-Control"] = "private, no-store"
        raise ActiveRecord::RecordNotFound unless logged_in?

        authorize!(current_client, to: :show?)
        render inertia: "warp/app/dashboards/show", props: dashboard_page_props
      end

      private

      # Home/Dashboard resolve regional context without redirecting a direct request.
      def set_region
        params[:ri] = normalized_param_ri.presence || get_region
      end
    end
  end
end

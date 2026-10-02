# typed: false
# frozen_string_literal: true

module Warp
  module Org
    class RootsController < Warp::Org::ApplicationController
      include ::WarpDashboardPage

      AUTHENTICATION_MODE = :open

      public

      def index
        response.headers["Cache-Control"] = "private, no-store"
        raise ActiveRecord::RecordNotFound if logged_in?

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
          heading: "Warp Org",
          description: t("base.org.roots.message"),
          sign_up: nil,
          links: [
            { label: "Settings", href: warp_org_settings_path(ri: params[:ri]) },
            { label: t("actions.continue"), href: warp_org_sign_show_path(ri: params[:ri]) },
          ],
        }
      end
    end
  end
end

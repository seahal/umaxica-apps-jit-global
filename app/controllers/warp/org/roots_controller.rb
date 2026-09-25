# typed: false
# frozen_string_literal: true

module Warp
  module Org
    class RootsController < Warp::Org::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      def index
        redirect_to(warp_org_dashboard_path(ri: params[:ri])) and return if logged_in?

        render inertia: true, props: root_landing_props
      end

      private

      def root_landing_props
        {
          title: nil,
          heading: "Warp Org",
          description: t("base.org.roots.message"),
          sign_up: nil,
          links: [
            { label: "Settings", href: warp_org_settings_path(ri: params[:ri]) },
            { label: "Continue", href: warp_org_sign_show_path(ri: params[:ri]) },
          ],
        }
      end
    end
  end
end

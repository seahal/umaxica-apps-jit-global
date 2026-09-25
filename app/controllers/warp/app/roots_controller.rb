# typed: false
# frozen_string_literal: true

module Warp
  module App
    class RootsController < Warp::App::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      def index
        redirect_to(warp_app_dashboard_path(ri: params[:ri])) and return if logged_in?

        render inertia: true, props: root_landing_props
      end

      private

      def root_landing_props
        {
          title: nil,
          heading: "Warp App",
          description: t("base.app.roots.message"),
          sign_up: nil,
          links: [
            { label: "Settings", href: warp_app_settings_path(ri: params[:ri]) },
            { label: "Continue", href: warp_app_sign_show_path(ri: params[:ri]) },
          ],
        }
      end
    end
  end
end

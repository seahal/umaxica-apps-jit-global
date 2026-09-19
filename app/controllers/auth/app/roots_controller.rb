# typed: false
# frozen_string_literal: true

module Auth
  module App
    class RootsController < ::Auth::App::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      def index
        response.headers["Cache-Control"] = "private, no-store"
        render inertia: true, props: root_landing_props
      end

      private

      def root_landing_props
        {
          title: "Sign App",
          heading: "Sign App",
          description: t("landing.thin_endpoint"),
          sign_in: {
            label: "Sign in",
            href: auth_app_sign_in_path(ri: params[:ri]),
          },
          sign_up: nil,
        }
      end
    end
  end
end

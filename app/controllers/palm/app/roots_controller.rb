# typed: false
# frozen_string_literal: true

module Palm
  module App
    class RootsController < Palm::App::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :bare

      def index
        render inertia: true, props: root_landing_props
      end

      private

      def root_landing_props
        {
          title: nil,
          heading: "Palm App",
          description: t("palm.app.roots.message"),
          sign_in: {
            label: t("palm.app.roots.sign_in"),
            href: palm_app_sign_show_path(ri: params[:ri]),
          },
          sign_up: nil,
          links: [],
        }
      end
    end
  end
end

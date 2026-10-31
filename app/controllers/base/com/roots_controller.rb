# typed: false
# frozen_string_literal: true

module Base
  module Com
    class RootsController < Base::Com::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      public

      # The com root is the anonymous entry to the public preference screen. It carries no personal
      # dashboard, sign-in link, or session branch.
      def index
        response.headers["Cache-Control"] = "private, no-store"
        render inertia: true, props: root_landing_props,
               clear_history: session[:inertia_clear_history] == true
      end

      private

      # Corporate identity storage is being retired; anonymous Base does not read its banners.
      def chrome_banner(_domain)
        nil
      end

      def root_landing_props
        {
          title: nil,
          heading: "Base Com",
          description: t("landing.thin_endpoint"),
          sign_in: nil,
          sign_up: nil,
          links: [
            {
              label: t("ui_presentation.navigation.preferences"),
              href: base_com_preference_path(ri: params[:ri]),
            },
          ],
        }
      end
    end
  end
end

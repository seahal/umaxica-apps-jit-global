# typed: false
# frozen_string_literal: true

module Auth
  module App
    class RootsController < ::Auth::App::ApplicationController
      include ::SurfaceInertiaPage

      # D-59: the landing page routes to the sign entry; it is not itself the entry ceremony.
      sign_entry_classification! :excluded, reason: "landing page that routes to the sign entry"

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
            href: sign_in_url_with_pt(nil),
          },
          sign_up: nil,
        }
      end
    end
  end
end

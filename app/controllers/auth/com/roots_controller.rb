# typed: false
# frozen_string_literal: true

module Auth
  module Com
    class RootsController < ::Auth::Com::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      def index
        response.headers["Cache-Control"] = "private, no-store"
        render inertia: true, props: root_landing_props
      end

      private

      # The heading stays the surface name; the body is the same landing sentence the other
      # surfaces already answer with, so it uses the shared key rather than a second English copy.
      def root_landing_props
        {
          title: "Sign Com",
          heading: "Sign Com",
          description: t("landing.thin_endpoint"),
          sign_in: {
            label: "Sign in",
            href: auth_com_sign_in_path(ri: params[:ri]),
          },
          sign_up: nil,
        }
      end
    end
  end
end

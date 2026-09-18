# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class RootsController < ::Auth::Org::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      def index
        response.headers["Cache-Control"] = "private, no-store"
        render inertia: true, props: root_landing_props
      end

      private

      def root_landing_props
        {
          title: "Sign Org",
          heading: "Sign Org",
          description: t("landing.thin_endpoint"),
          sign_in: {
            label: "Sign in",
            href: auth_org_sign_in_path(ri: params[:ri]),
          },
          # The org root is staff-only and has no self-service registration to offer.
          sign_up: nil,
        }
      end
    end
  end
end

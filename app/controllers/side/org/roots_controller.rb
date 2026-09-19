# typed: false
# frozen_string_literal: true

module Side
  module Org
    class RootsController < Side::Org::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      def index
        redirect_to(side_org_dashboard_path(ri: params[:ri])) and return if logged_in?

        render inertia: true, props: root_landing_props
      end

      private

      def root_landing_props
        {
          title: nil,
          heading: "Side Org",
          description: t("base.org.roots.message"),
          sign_up: nil,
          links: [
            { label: "Settings", href: side_org_settings_path(ri: params[:ri]) },
            { label: "Sign up", href: side_org_sign_in_path(ri: params[:ri]) },
          ],
        }
      end
    end
  end
end

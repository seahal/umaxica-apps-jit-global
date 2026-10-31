# typed: false
# frozen_string_literal: true

module Warp
  module Com
    class RootsController < Warp::Com::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      public

      # Anonymous public landing. It has no signed-in branch and no sign-in continuation: the com
      # surface offers its settings shell and the Base com preference entry only.
      def index
        response.headers["Cache-Control"] = "private, no-store"
        render inertia: true, props: root_landing_props,
               clear_history: session[:inertia_clear_history] == true
      end

      private

      # Home resolves regional context without redirecting a direct request.
      def set_region
        params[:ri] = normalized_param_ri.presence || get_region
      end

      def root_landing_props
        {
          title: nil,
          heading: "Warp Com",
          description: t("base.com.roots.message"),
          sign_up: nil,
          links: [
            { label: "Settings", href: warp_com_settings_path(ri: params[:ri]) },
          ],
        }
      end
    end
  end
end

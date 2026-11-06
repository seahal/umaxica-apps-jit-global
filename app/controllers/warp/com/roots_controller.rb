# typed: false
# frozen_string_literal: true

module Warp
  module Com
    class RootsController < Warp::Com::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      public

      # Anonymous public landing. It has no signed-in branch and no sign-in continuation: the com
      # surface offers the Base com preference entry only.
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
            {
              label: t("ui_presentation.navigation.preferences"),
              href: base_com_preference_url(ri: params[:ri]),
            },
          ],
        }
      end

      # The Base com preference entry lives on another host. Building the absolute URL from the
      # registered public host keeps the link inside the allowlisted com pair instead of pointing at
      # a path this host does not serve.
      def base_com_preference_url(**options)
        options = options.merge(
          host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
          protocol: Rails.env.production? ? "https" : request.protocol,
        )
        Rails.application.routes.url_helpers.base_com_preference_url(**options)
      end
    end
  end
end

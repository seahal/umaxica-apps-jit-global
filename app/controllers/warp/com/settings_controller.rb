# typed: false
# frozen_string_literal: true

module Warp
  module Com
    class SettingsController < Warp::Com::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      public

      # Anonymous shell. Every destination is fixed here; the page offers no control that this
      # surface does not implement.
      def show
        render inertia: true, props: settings_page_props
      end

      private

      def settings_page_props
        {
          title: "Settings",
          heading: "Settings",
          description: t("ui_presentation.display_preferences_description"),
          links: [
            { label: "Root", href: warp_com_root_path(ri: params[:ri]) },
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

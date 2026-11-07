# typed: false
# frozen_string_literal: true

module Palm
  module App
    class RootsController < Palm::App::ApplicationController
      include ::SurfaceInertiaPage
      include ::SessionBoundaryNotFound

      AUTHENTICATION_MODE = :open

      public

      def index
        response.headers["Cache-Control"] = "private, no-store"
        return render_authenticated_home_forbidden if logged_in?

        render inertia: true, props: root_landing_props
      end

      private

      # An authenticated root request is refused without resolving its cell-local principal into
      # the OP's Client actor context. The root action needs only the verified RP session state.
      def set_current_actor
        return if action_name == "index" && browser_rp_authenticated?

        super
      end

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

# typed: false
# frozen_string_literal: true

module Base
  module App
    class WelcomesController < Base::App::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_client, to: :show?)
        render inertia: true, props: {
          title: "Welcome!",
          credential_warning: apple_only_credential_warning_props,
          next_link: {
            label: "Next",
            href: rp_welcome_return_path(params[AuthIoKeys::Params::PT], surface: "app") ||
              base_app_dashboard_path(ri: params[:ri]),
          },
        }
      end
    end
  end
end

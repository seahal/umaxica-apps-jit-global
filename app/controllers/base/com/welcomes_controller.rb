# typed: false
# frozen_string_literal: true

module Base
  module Com
    class WelcomesController < Base::Com::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_visitor, to: :show?)
        render inertia: true, props: {
          title: "Welcome!",
          next_link: {
            label: "Next",
            href: rp_welcome_return_path(params[AuthIoKeys::Params::PT], surface: "com") ||
              base_com_dashboard_path(ri: params[:ri]),
          },
        }
      end
    end
  end
end

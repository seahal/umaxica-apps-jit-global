# typed: false
# frozen_string_literal: true

module Base
  module Org
    class WelcomesController < Base::Org::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_operator, to: :show?)
        render inertia: true, props: {
          title: "Welcome!",
          next_link: {
            label: "Next",
            href: rp_welcome_return_path(params[AuthIoKeys::Params::PT], surface: "org") ||
              base_org_dashboard_path(ri: params[:ri]),
          },
        }
      end
    end
  end
end

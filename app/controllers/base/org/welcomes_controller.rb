# typed: false
# frozen_string_literal: true

module Base
  module Org
    class WelcomesController < Base::Org::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!
      before_action :continue_welcome_sequence_without_content!

      def show
        render inertia: true, props: {
          title: "Welcome!",
          next_link: {
            label: "Next",
            href: @welcome_next_path || base_org_dashboard_path(ri: params[:ri]),
          },
        }
      end

      private

      def after_welcome_path
        base_org_dashboard_path(ri: params[:ri])
      end
    end
  end
end

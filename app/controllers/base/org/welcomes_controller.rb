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

      # TODO: Action Policy authorization is not yet enforced here.

      # This sign-in ceremony step gates with allowed_to?, which does not satisfy

      # verify_authorized, so its render path is expected to raise UnauthorizedAction.

      # Audit the sign-in sequence boundary before choosing the authorize! rule.

      def show
        render inertia: true, props: {
          title: "Welcome!",
          next_link: {
            label: "Next",
            href: @welcome_next_path || base_org_root_path(ri: params[:ri]),
          },
        }
      end

      private

      def after_welcome_path
        base_org_root_path(ri: params[:ri])
      end
    end
  end
end

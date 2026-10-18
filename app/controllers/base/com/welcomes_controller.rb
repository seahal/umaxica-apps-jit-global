# typed: false
# frozen_string_literal: true

module Base
  module Com
    class WelcomesController < Base::Com::ApplicationController
      include ::SurfaceInertiaPage
      include ::SignInWelcomeGate
      include ::SignInPhaseBindingControllerSupport

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action -> {
        enforce_sign_in_phase_binding!(expected_phase: %w(SESSION_ISSUANCE_PENDING COMPLETED))
      }
      before_action :continue_welcome_sequence_without_content!

      def show
        authorize!(current_visitor, to: :show?)
        render inertia: true, props: {
          title: "Welcome!",
          next_link: {
            label: "Next",
            href: @welcome_next_path || base_com_dashboard_path(ri: params[:ri]),
          },
        }
      end

      private

      def after_welcome_path
        base_com_dashboard_path(ri: params[:ri])
      end

      def sign_in_sequence_surface = "com"

      # The root sign-in flow is complete before this self-RP page is reachable, so only the
      # one-shot Welcome gate decides between showing the page and going on to the Dashboard.
      def continue_welcome_sequence_without_content!
        return redirect_to(after_welcome_path) unless consume_welcome_gate!

        @welcome_next_path = welcome_return_path(params[AuthIoKeys::Params::PT])
      end
    end
  end
end

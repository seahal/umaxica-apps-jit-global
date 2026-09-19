# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Social
      # POST /social/(google|apple)/session
      #
      # Starts the social sign-in ceremony. The provider arrives as a route
      # default; an explicit `intent` param may upgrade the ceremony to
      # "link" or "step_up" when arriving from settings.
      class SessionsController < ::Auth::App::ApplicationController
        # The only page either action renders is the sign-up suspension notice, which is now the
        # Inertia entry page rather than an ERB template; the OmniAuth handoff is untouched.
        include ::SurfaceInertiaPage
        include AppSocialCeremonyEntry
        include AppSignUpEntryPage
        include ::AuthenticationModeSwitchGuard

        AUTHENTICATION_MODE = :open

        # Login intent doesn't require auth; link/step-up intents are checked
        # in require_social_link_step_up! and prepare_social_auth_intent!.
        declare_authentication_mode! :open, only: :create
        before_action :reject_sign_in_intent_while_authenticated!, only: :create
        before_action :require_social_link_step_up!, only: :create

        def create
          handoff_social_ceremony!
        end

        private

        def reject_sign_in_intent_while_authenticated!
          return if params[:intent].to_s == "link"

          reject_new_sign_in_if_authenticated!
        end
      end
    end
  end
end

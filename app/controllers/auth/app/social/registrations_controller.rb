# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Social
      # POST /social/(google|apple)/registration
      #
      # Starts the social sign-up ceremony. The provider and the sign-up entry
      # marker arrive as route defaults; the shared ceremony entry issues the
      # sign-up flow ticket when the entry is a sign-up.
      class RegistrationsController < ::Auth::App::ApplicationController
        # The only page either action renders is the sign-up suspension notice, which is now the
        # Inertia entry page rather than an ERB template; the OmniAuth handoff is untouched.
        include ::SurfaceInertiaPage
        include AppSocialCeremonyEntry
        include AppSignUpEntryPage

        AUTHENTICATION_MODE = :open
        sign_entry_classification! :parent_intent

        declare_authentication_mode! :open, only: :create
        before_action :require_social_link_step_up!, only: :create

        def create
          handoff_social_ceremony!
        end
      end
    end
  end
end

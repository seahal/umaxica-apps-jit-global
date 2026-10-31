# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Settings
      # Compatibility endpoint for credential removal (passkeys and secret credentials).
      # sign/id owns credential lifecycle. This endpoint keeps the POST .../removal URL working
      # by redirecting to the resource's canonical sign settings page.
      class RemovalsController < ::Auth::App::ApplicationController
        # D-59: credential removal redirects to the owner surface; it is not a Sign Entry.
        sign_entry_classification! :excluded, reason: "signed-in settings surface, not a sign entry"

        include ::SignAuthorityRedirect

        AUTHENTICATION_MODE = :private
        before_action :authenticate_client!

        # The endpoint only forwards to the canonical settings page, which authorizes the
        # record itself. It is still a private action, so the owner check has to run here
        # too: without it `verify_private_action_authorized!` raised
        # ActionPolicy::UnauthorizedAction on every authenticated request.
        def create
          authorize!(current_client, to: :show?)
          redirect_to_sign_authority!(canonical_resource_path, query: request.query_parameters)
        end

        private

        def canonical_resource_path
          request.path.delete_suffix("/removal")
        end
      end
    end
  end
end

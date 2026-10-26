# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Revocations
        class OthersController < BaseController
          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          step_up only: %i(create destroy), scope: "session_revoke_all"

          def create
            authorize!(ClientToken, to: :revoke_others?)
            AuthenticationOtherSessionsRevoker.call(
              owner: current_client,
              sessions: current_client.client_tokens.session_inventory,
              current_token: current_session,
              current_session_public_id: current_session_public_id,
              step_up_requirement: step_up_requirement(scope: "session_revoke_all"),
            )
            redirect_to(base_app_sessions_path(ri: params[:ri]), status: :see_other)
          rescue AuthenticationOtherSessionsRevoker::StepUpUnavailable
            require_step_up!(scope: "session_revoke_all")
          end
          alias_method :destroy, :create
        end
      end
    end
  end
end

# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Revocations
        class OthersController < BaseController
          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_client!
          def create
            authorize!(ClientToken, to: :revoke_others?)
            AuthenticationOtherSessionsRevoker.call(
              owner: current_client,
              sessions: current_client.client_tokens.session_inventory,
              current_token: current_session,
              current_session_public_id: current_session_public_id,
            )
            redirect_to(base_app_sessions_path(ri: params[:ri]), status: :see_other)
          end
          alias_method :destroy, :create
        end
      end
    end
  end
end

# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Secrets
        class RemovalsController < BaseController
          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_client!
          step_up only: :create, scope: "settings_secret_credential"

          def create
            authorize!(current_client, to: :update?)
            CredentialSecurityTransition.call(
              actor: current_client,
              current_session: current_session,
              reason: :secret_credential_changed,
              affected_surface: "app",
              request: request,
            )
            redirect_to(
              base_app_identity_secrets_path(ri: params[:ri]),
              status: :see_other,
            )
          end
        end
      end
    end
  end
end

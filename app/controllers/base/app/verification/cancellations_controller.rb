# typed: false
# frozen_string_literal: true

module Base
  module App
    module Verification
      class CancellationsController < Base::App::ApplicationController
        include BaseStepUpCancellation

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        def create
          authorize!(current_client, to: :show?)
          cancel_step_up_ceremony!(
            surface: "app",
            actor: current_client,
            token: current_session_token,
            destination: base_app_dashboard_path(ri: params[:ri]),
          )
        end

        private

        def cancellation_surface = "app"

        def cancellation_actor = current_client

        def cancellation_token = current_session_token

        def cancellation_step_up_transaction(reference)
          ClientStepUpCeremonyTransaction.connection_owner.connected_to(role: :writing) do
            ClientStepUpCeremonyTransaction.find_by!(transaction_id: reference)
          end
        end

        def actor_verification_path(**args)
          base_app_verification_path(**args)
        end
      end
    end
  end
end

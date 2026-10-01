# typed: false
# frozen_string_literal: true

module Base
  module App
    module Verification
      class CompletionsController < Base::App::ApplicationController
        include BaseStepUpCompletion

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!

        def create
          authorize!(current_client, to: :show?)
          complete_step_up_ceremony!(
            surface: "app",
            actor: current_client,
            token: current_session_token,
            fallback: base_app_dashboard_path(ri: params[:ri]),
          )
        end

        private

        def actor_verification_path(**args)
          base_app_verification_path(**args)
        end
      end
    end
  end
end

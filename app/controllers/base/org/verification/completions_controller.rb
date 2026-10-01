# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Verification
      class CompletionsController < Base::Org::ApplicationController
        include BaseStepUpCompletion

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_operator!

        def create
          authorize!(current_operator, to: :show?)
          complete_step_up_ceremony!(
            surface: "org",
            actor: current_operator,
            token: current_session_token,
            fallback: base_org_dashboard_path(ri: params[:ri]),
          )
        end

        private

        def actor_verification_path(**args)
          base_org_verification_path(**args)
        end
      end
    end
  end
end

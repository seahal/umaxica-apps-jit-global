# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Verification
      class CompletionsController < Base::Com::ApplicationController
        include BaseStepUpCompletion

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_visitor!

        def create
          authorize!(current_visitor, to: :show?)
          complete_step_up_ceremony!(
            surface: "com",
            actor: current_visitor,
            token: current_session_token,
            fallback: base_com_dashboard_path(ri: params[:ri]),
          )
        end

        private

        def actor_verification_path(**args)
          base_com_verification_path(**args)
        end
      end
    end
  end
end

# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Verification
      class CompletionsController < Base::Com::ApplicationController
        include BaseStepUpCompletion

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private
        STEP_UP_RESULT_ORIGINS = JitHostOriginEnv.trusted_origins(ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")).freeze
        protect_from_forgery using: :header_or_legacy_token, trusted_origins: STEP_UP_RESULT_ORIGINS, with: :exception

        before_action :authenticate_visitor!

        def create
          authorize!(current_visitor, to: :show?)
          complete_step_up_ceremony!(
            surface: "com",
            actor: current_visitor,
            token: current_session_token,
          )
        end

        private

        def completion_step_up_transaction(reference)
          VisitorStepUpCeremonyTransaction.connection_owner.connected_to(role: :writing) do
            VisitorStepUpCeremonyTransaction.find_by!(transaction_id: reference)
          end
        end

        def actor_verification_path(**args)
          base_com_verification_path(**args)
        end
      end
    end
  end
end

# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Verification
      class CompletionsController < Base::Org::ApplicationController
        include BaseStepUpCompletion

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private
        STEP_UP_RESULT_ORIGINS = JitHostOriginEnv.trusted_origins(ENV.fetch("PUBLIC_AUTH_STAFF_URL")).freeze
        protect_from_forgery using: :header_or_legacy_token, trusted_origins: STEP_UP_RESULT_ORIGINS, with: :exception

        before_action :authenticate_operator!

        def create
          authorize!(current_operator, to: :show?)
          complete_step_up_ceremony!(
            surface: "org",
            actor: current_operator,
            token: current_session_token,
          )
        end

        private

        def completion_step_up_transaction(reference)
          OperatorStepUpCeremonyTransaction.connection_owner.connected_to(role: :writing) do
            OperatorStepUpCeremonyTransaction.find_by!(transaction_id: reference)
          end
        end

        def actor_verification_path(**args)
          base_org_verification_path(**args)
        end
      end
    end
  end
end

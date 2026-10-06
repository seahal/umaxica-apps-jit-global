# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Verification
      class CompletionsController < Base::Org::ApplicationController
        include BaseStepUpCompletion

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        def show
          authorize!(current_operator, to: :show?)
          super
        end

        def create
          authorize!(current_operator, to: :show?)
          complete_step_up_ceremony!(
            surface: "org",
            actor: current_operator,
            token: current_session_token,
          )
        end

        private

        def finalize_completion_transaction!(actor:, token:, transaction:, result_reference:)
          return super if %w(step_up reauthentication).include?(transaction.purpose)

          unless %w(bootstrap credential_registration).include?(transaction.purpose) &&
              transaction.method == "passkey"
            raise BaseAuthAdmissionCoordinator::Denied.new(
              "registration method unavailable", code: "unsupported_method",
            )
          end

          IdentityPasskeyRegistrationFinalCommitter.call!(
            actor: actor, token: token, transaction: transaction, result_reference: result_reference,
            ip_address: request.remote_ip, user_agent: request.user_agent,
          )
          transaction.reload
        rescue IdentityPasskeyCeremonyContract::Error
          raise BaseAuthAdmissionCoordinator::Denied.new("passkey registration unavailable", code: "unsupported_method")
        end

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

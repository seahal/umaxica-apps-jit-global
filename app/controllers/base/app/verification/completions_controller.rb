# typed: false
# frozen_string_literal: true

module Base
  module App
    module Verification
      class CompletionsController < Base::App::ApplicationController
        include BaseStepUpCompletion

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private
        STEP_UP_RESULT_ORIGINS = JitHostOriginEnv.trusted_origins(ENV.fetch("PUBLIC_AUTH_SERVICE_URL")).freeze
        protect_from_forgery using: :header_or_legacy_token, trusted_origins: STEP_UP_RESULT_ORIGINS, with: :exception

        before_action :authenticate_client!

        def create
          authorize!(current_client, to: :show?)
          complete_step_up_ceremony!(
            surface: "app",
            actor: current_client,
            token: current_session_token,
          )
        end

        private

        def finalize_completion_transaction!(actor:, token:, transaction:)
          case transaction.purpose
          when "step_up", "reauthentication"
            super
          when "bootstrap", "credential_registration"
            unless transaction.method == "totp"
              raise BaseAuthAdmissionCoordinator::Denied.new(
                "registration method unavailable",
                code: "unsupported_method",
              )
            end

            IdentityTotpEnrollmentFinalCommitter.call!(
              actor: actor, token: token, transaction: transaction, raw_result: params[:result],
            )
            transaction.reload
          else
            raise BaseAuthAdmissionCoordinator::Denied.new("completion purpose unavailable", code: "malformed_request")
          end
        rescue IdentityTotpCeremonyContract::Error
          raise BaseAuthAdmissionCoordinator::Denied.new("TOTP registration unavailable", code: "unsupported_method")
        end

        def completion_step_up_transaction(reference)
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

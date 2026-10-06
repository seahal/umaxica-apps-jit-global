# typed: false
# frozen_string_literal: true

module Base
  module App
    module Verification
      class CompletionsController < Base::App::ApplicationController
        include BaseStepUpCompletion

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        def show
          authorize!(current_client, to: :show?)
          super
        end

        def create
          authorize!(current_client, to: :show?)
          complete_step_up_ceremony!(
            surface: "app",
            actor: current_client,
            token: current_session_token,
          )
        end

        private

        def finalize_completion_transaction!(actor:, token:, transaction:, result_reference:)
          case transaction.purpose
          when "step_up", "reauthentication"
            super
          when "bootstrap", "credential_registration"
            case transaction.method
            when "totp"
              IdentityTotpEnrollmentFinalCommitter.call!(
                actor: actor, token: token, transaction: transaction, result_reference: result_reference,
              )
            when "passkey"
              @registered_passkey = IdentityPasskeyRegistrationFinalCommitter.call!(
                actor: actor, token: token, transaction: transaction, result_reference: result_reference,
                ip_address: request.remote_ip, user_agent: request.user_agent,
              )
              if transaction.purpose == "credential_registration"
                @secret_issuance = ClientSecretPasskeyReservationIssuer.call!(
                  actor_context: ActorValuesContext.empty.with(
                    subject: actor, actor_type: :client, tld: :app, surface: :base,
                  ),
                  token: token, passkey: @registered_passkey,
                  expires_after: ClientSecretLifetimesValue.issuance_ttl,
                )
              end
            else
              raise BaseAuthAdmissionCoordinator::Denied.new(
                "registration method unavailable", code: "unsupported_method",
              )
            end
            transaction.reload
          else
            raise BaseAuthAdmissionCoordinator::Denied.new("completion purpose unavailable", code: "malformed_request")
          end
        rescue IdentityTotpCeremonyContract::Error, IdentityPasskeyCeremonyContract::Error
          raise BaseAuthAdmissionCoordinator::Denied.new("registration unavailable", code: "unsupported_method")
        end

        def completion_step_up_transaction(reference)
          ClientStepUpCeremonyTransaction.connection_owner.connected_to(role: :writing) do
            ClientStepUpCeremonyTransaction.find_by!(transaction_id: reference)
          end
        end

        def completion_redirect_target(transaction)
          return super unless @secret_issuance

          base_app_secret_issuance_url(
            @secret_issuance.public_id, ri: params[:ri], host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), protocol: "https",
          )
        end

        def actor_verification_path(**args)
          base_app_verification_path(**args)
        end
      end
    end
  end
end

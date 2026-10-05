# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Settings
      module Totps
        # POST starts the admitted candidate once; DELETE cancels the exact Base permission.
        class EnrollmentsController < ::Auth::App::ApplicationController
          include ::SignSettingsTotpRegistration
          include ::AuthStepUpCeremonyContext

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          before_action :load_registration_ceremony_context!

          public

          def create
            authorize!(ClientTotpCredential, to: :new?, context: { user: @step_up_ceremony_actor })
            return render_invalid_step_up_context! unless admitted_step_up_methods.include?(:totp)

            discard_legacy_totp_enrollment!
            IdentityTotpEnrollmentIssuer.call!(
              actor: @step_up_ceremony_actor, token: ceremony_session_token(@step_up_ceremony_session),
              transaction: @step_up_ceremony_transaction,
            )
            redirect_to(new_auth_app_settings_totp_path(ri: params[:ri]), status: :see_other)
          rescue ClientTotpCredential::SlotLimitExceeded
            render plain: t("session_limit.totp_limit_reached", count: ClientTotpCredential::MAX_TOTP_SLOTS),
                   status: :unprocessable_content
          end

          def destroy
            authorize!(ClientTotpCredential, to: :new?, context: { user: @step_up_ceremony_actor })
            canceled = IdentityStepUpCeremonyCancellationCommitter.call!(
              actor: @step_up_ceremony_actor, token: ceremony_session_token(@step_up_ceremony_session),
              transaction: @step_up_ceremony_transaction,
            )
            return render_invalid_step_up_context! unless canceled

            discard_legacy_totp_enrollment!
            cookies.delete(auth_ceremony_sid_cookie_name, path: "/")
            reset_session
            redirect_to_surface_url(
              base_app_dashboard_url(host: base_authority_host, protocol: "https", ri: params[:ri]),
              status: :see_other,
            )
          end

          private

          def ceremony_actor_model = Client

          def ceremony_step_up_session_model = ClientStepUpSession

          def ceremony_session_token(record) = record.user_token

          def ceremony_token_owned_by?(token, actor) = token.user_id == actor.id

          def ceremony_supported_methods = [:totp]

          def authorize_step_up_ceremony_actor!(actor)
            authorize!(actor, to: :show?, context: { user: actor })
          end

          rescue_from IdentityTotpCeremonyContract::Error, IdentityStepUpCeremonyContract::Error,
                      ActiveRecord::RecordNotFound, with: :render_invalid_step_up_context!
        end
      end
    end
  end
end

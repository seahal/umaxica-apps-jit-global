# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Settings
      module Totps
        # Starts (POST) and cancels (DELETE) the enrolment of a new authenticator app. Starting always
        # issues a fresh secret; cancelling discards it and all temporary enrolment state. The QR
        # display (`totps#new`) and the confirmation (`totps#create`) keep their own step-up gate.
        class EnrollmentsController < ::Auth::App::ApplicationController
          include ::SignSettingsTotpRegistration

          AUTHENTICATION_MODE = :private

          before_action :authenticate_client!

          public

          def create
            authorize!(ClientTotpCredential, to: :new?)
            if ClientTotpCredential.slot_consuming.where(user_id: current_client.id).count >=
                ClientTotpCredential::MAX_TOTP_SLOTS
              return render plain: t("session_limit.totp_limit_reached", count: ClientTotpCredential::MAX_TOTP_SLOTS),
                            status: :unprocessable_content
            end

            start_totp_enrollment!
            redirect_to(new_auth_app_settings_totp_path(ri: params[:ri]), status: :see_other)
          end

          def destroy
            authorize!(ClientTotpCredential, to: :new?)
            end_totp_enrollment!
            redirect_to(auth_app_settings_totps_path(ri: params[:ri]), status: :see_other)
          end
        end
      end
    end
  end
end

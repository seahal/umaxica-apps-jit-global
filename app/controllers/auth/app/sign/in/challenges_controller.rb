# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module In
        class ChallengesController < ::Auth::App::ApplicationController
          include ::AuthenticationModeSwitchGuard
          include ::SurfaceInertiaPage

          AUTHENTICATION_MODE = :guest

          before_action :ensure_pending_mfa!

          def show
            @mfa_user = pending_mfa_user
            @can_use_totp = @mfa_user&.totp_enabled?
            @can_use_passkey = @mfa_user&.client_passkeys&.exists?(status_id: ClientPasskeyStatus::ACTIVE)

            render inertia: true, props: mfa_challenge_props
          end

          private

          def mfa_challenge_props
            scope = "sign.app.in.mfa"
            any_method = @can_use_totp || @can_use_passkey

            {
              title: page_t("#{scope}.title"),
              description: page_t("#{scope}.description"),
              methods: mfa_challenge_methods(scope),
              no_methods_notice: any_method ? nil : page_t("#{scope}.no_methods_available"),
              back_link: any_method ? nil : mfa_challenge_back_link,
            }
          end

          def mfa_challenge_methods(scope)
            methods = []
            if @can_use_totp
              methods << {
                key: "totp",
                label: page_t("#{scope}.methods.totp"),
                href: new_auth_app_sign_in_challenge_totp_path,
              }
            end
            if @can_use_passkey
              methods << {
                key: "passkey",
                label: page_t("#{scope}.methods.passkey"),
                href: new_auth_app_sign_in_challenge_passkey_path,
              }
            end
            methods
          end

          def mfa_challenge_back_link
            {
              key: "back",
              label: t("sign.app.authentication.new.back"),
              href: auth_app_sign_in_path,
            }
          end

          def ensure_pending_mfa!
            return unless !pending_mfa_valid? || pending_mfa_user.nil?

            clear_pending_mfa!
            redirect_to(
              auth_app_sign_in_path,
              status: :see_other,
            )
          end
        end
      end
    end
  end
end

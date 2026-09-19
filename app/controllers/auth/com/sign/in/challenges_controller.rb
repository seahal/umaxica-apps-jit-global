# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module In
        class ChallengesController < ::Auth::Com::ApplicationController
          include ::AuthenticationModeSwitchGuard
          include ::SurfaceInertiaPage

          AUTHENTICATION_MODE = :guest

          before_action :ensure_pending_mfa!

          def show
            @mfa_user = pending_mfa_user
            @can_use_passkey = @mfa_user&.visitor_passkeys&.exists?(status_id: VisitorPasskeyStatus::ACTIVE)

            render inertia: true, props: mfa_challenge_props
          end

          private

          def mfa_challenge_props
            {
              title: t("sign.app.in.mfa.title"),
              description: t("sign.app.in.mfa.description"),
              methods: mfa_challenge_methods,
              no_methods_notice: @can_use_passkey ? nil : t("sign.app.in.mfa.no_methods_available"),
              back_link: mfa_challenge_back_link,
            }
          end

          def mfa_challenge_methods
            return [] unless @can_use_passkey

            [
              {
                key: "passkey",
                label: t("sign.app.in.mfa.methods.passkey"),
                href: new_auth_com_sign_in_challenge_passkey_path,
              },
            ]
          end

          def mfa_challenge_back_link
            return nil if @can_use_passkey

            {
              key: "back",
              label: t("sign.app.authentication.new.back"),
              href: auth_com_sign_in_path,
            }
          end

          def ensure_pending_mfa!
            return unless !pending_mfa_valid? || pending_mfa_user.nil?

            clear_pending_mfa!
            ri = params[:ri].presence || current_region_identifier
            redirect_to(
              auth_com_sign_in_path(ri: ri),
              status: :see_other,
            )
          end
        end
      end
    end
  end
end

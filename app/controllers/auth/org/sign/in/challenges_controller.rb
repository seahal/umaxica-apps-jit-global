# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module In
        class ChallengesController < ::Auth::Org::ApplicationController
          include ::AuthenticationModeSwitchGuard
          include ::SurfaceInertiaPage

          AUTHENTICATION_MODE = :guest

          before_action :ensure_pending_mfa!

          def show
            @mfa_staff = pending_mfa_user
            @can_use_passkey = @mfa_staff&.staff_passkeys&.exists?(status_id: OperatorPasskeyStatus::ACTIVE)
            render inertia: true, props: challenge_props
          end

          private

          # A factor the actor cannot use is omitted rather than sent with a flag, so the page can
          # never offer a ceremony the server would reject.
          def challenge_props
            {
              title: t("sign.org.in.mfa.title"),
              description: t("sign.org.in.mfa.description"),
              methods: if @can_use_passkey
                         [{
                           key: "passkey",
                           label: t("sign.org.in.mfa.methods.passkey"),
                           href: new_auth_org_sign_in_challenge_passkey_path,
                         }]
                       else
                         []
                       end,
              no_methods_notice: @can_use_passkey ? nil : t("sign.org.in.mfa.no_methods_available"),
              back_link: if @can_use_passkey
                           nil
                         else
                           { key: "back", label: t("sign.org.in.back"), href: auth_org_sign_in_path }
                         end,
            }
          end

          def ensure_pending_mfa!
            return unless !pending_mfa_valid? || pending_mfa_user.nil?

            clear_pending_mfa!
            redirect_to(
              auth_org_sign_in_path,
              status: :see_other,
            )
          end
        end
      end
    end
  end
end

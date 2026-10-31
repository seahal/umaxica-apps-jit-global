# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Privacy
        class ErasuresController < BaseController
          include ::SurfaceInertiaPage
          include CommonRedirect
          include WithdrawalCeremonyAuthentication
          include PrivacyErasureRequestFlow

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          skip_before_action :set_preferences_cookie, only: :create
          before_action :withdrawal_ceremony_required!

          def new
            render_privacy_erasure_new(current_withdrawal_subject)
            return if performed?

            render inertia: true, props: {
              title: "Early personal data erasure",
              notices: [
                t("privacy_erasure.forbidden"),
                t("privacy_erasure.existing_requests"),
                t("privacy_erasure.withdrawal_separate"),
              ],
              form: {
                action: base_app_identity_privacy_erasure_path(ri: params[:ri]),
                jurisdiction: "unknown",
                submit_label: t("privacy_erasure.unavailable_action"),
              },
            }
          end

          def create
            render_privacy_erasure_forbidden
          end

          private

          def withdrawal_ceremony_class = ClientWithdrawalCeremony

          def withdrawal_new_path(extra_params = {})
            new_base_app_identity_withdrawal_session_path({ ri: params[:ri] }.merge(extra_params))
          end

          def withdrawal_public_fallback_path = auth_app_sign_in_path
        end
      end
    end
  end
end

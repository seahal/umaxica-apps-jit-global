# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class RecoveriesController < BaseController
        include ::SurfaceInertiaPage
        include EnforcementRecoveryCeremonyCookie
        include IdentityRecoveryPage

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        before_action :require_recovery_ceremony!

        def show
          render_identity_recovery(
            enforcement_cases: AppEnforcementCase.in_force.includes(:appeal).where(
              principal_public_id: current_recovery_ceremony.subject.public_id, kind: "security_lock",
              visibility: "visible", release_mode: "verification_required",
            ),
          )
        end

        private

        def recovery_ceremony_class = ClientEnforcementRecoveryCeremony

        def require_recovery_ceremony!
          return if current_recovery_ceremony

          clear_recovery_ceremony_cookie!
          safe_redirect_to(
            new_base_app_identity_recovery_session_path, fallback: auth_app_sign_in_path,
                                                         status: :see_other,
          )
        end
      end
    end
  end
end

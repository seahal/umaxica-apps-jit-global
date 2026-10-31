# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Recovery
        class CompletionsController < ::Base::App::Identity::BaseController
          include CommonRedirect
          include EnforcementRecoveryCeremonyCookie

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open
          before_action :require_recovery_ceremony!

          def create
            EnforcementCaseEndOperation.call(
              enforcement_case: recovery_case, reason: "verification_completed",
              recovery_ceremony: current_recovery_ceremony,
            )
            clear_recovery_ceremony_cookie!
            safe_redirect_to(
              auth_app_sign_in_path, fallback: new_base_app_identity_recovery_session_path,
                                     status: :see_other,
            )
          end

          private

          def recovery_case
            AppEnforcementCase.in_force.find_by!(
              public_id: params.expect(:enforcement_case_id),
              principal_public_id: current_recovery_ceremony.subject.public_id,
              kind: "security_lock", visibility: "visible", release_mode: "verification_required",
            )
          end

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
end

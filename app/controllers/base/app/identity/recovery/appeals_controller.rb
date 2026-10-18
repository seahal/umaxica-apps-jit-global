# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Recovery
        class AppealsController < ::Base::App::Identity::BaseController
          include ::SurfaceInertiaPage
          include CommonRedirect
          include EnforcementRecoveryCeremonyCookie
          include IdentityRecoveryPage

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open
          before_action :require_recovery_ceremony!

          def create
            appeal = AppEnforcementAppeal.new(
              enforcement_case: appealable_case,
              reason_code: appeal_params.fetch(:reason_code),
              statement: appeal_params.fetch(:statement),
              submitted_at: Time.current,
            )
            appeal.submit!
            safe_redirect_to(
              base_app_identity_recovery_path, fallback: new_base_app_identity_recovery_session_path,
                                               status: :see_other,
            )
          rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
            render_identity_recovery(
              enforcement_cases: appealable_cases,
              appeal_error: e.message,
              status: :unprocessable_content,
            )
          end

          private

          def appeal_params = params.expect(appeal: %i(enforcement_case_id reason_code statement))

          def appealable_case
            appealable_cases.find_by!(public_id: appeal_params.fetch(:enforcement_case_id))
          end

          def appealable_cases
            AppEnforcementCase.in_force.includes(:appeal).where(
              principal_public_id: current_recovery_ceremony.subject.public_id, visibility: "visible",
            ).where.not(kind: "method_protection")
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

# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      module Recovery
        class AppealsController < ::Base::Com::ApplicationController
          include ::SurfaceInertiaPage
          include ::ComIdentityRecoveryPage
          include CommonRedirect
          include EnforcementRecoveryCeremonyCookie

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open
          before_action :require_recovery_ceremony!

          def create
            appeal = ComEnforcementAppeal.new(
              enforcement_case: appealable_case,
              reason_code: appeal_params.fetch(:reason_code),
              statement: appeal_params.fetch(:statement),
              submitted_at: Time.current,
            )
            appeal.submit!
            safe_redirect_to(
              base_com_identity_recovery_path, fallback: new_base_com_identity_recovery_session_path,
                                               status: :see_other,
            )
          rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
            @appeal_error = e.message
            @enforcement_cases = appealable_cases
            render_com_identity_recovery(
              enforcement_cases: @enforcement_cases,
              appeal_error: @appeal_error,
              status: :unprocessable_content,
            )
          end

          private

          def appeal_params = params.expect(appeal: %i(enforcement_case_id reason_code statement))

          def appealable_case
            appealable_cases.find_by!(public_id: appeal_params.fetch(:enforcement_case_id))
          end

          def appealable_cases
            ComEnforcementCase.in_force.includes(:appeal).where(
              principal_public_id: current_recovery_ceremony.subject.public_id, visibility: "visible",
            ).where.not(kind: "method_protection")
          end

          def recovery_ceremony_class = VisitorEnforcementRecoveryCeremony

          def require_recovery_ceremony!
            return if current_recovery_ceremony

            clear_recovery_ceremony_cookie!
            safe_redirect_to(
              new_base_com_identity_recovery_session_path, fallback: auth_com_sign_in_path,
                                                           status: :see_other,
            )
          end
        end
      end
    end
  end
end

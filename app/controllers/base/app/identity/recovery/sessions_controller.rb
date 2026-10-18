# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Recovery
        class SessionsController < ::Base::App::Identity::BaseController
          include ::SurfaceInertiaPage
          include CommonRedirect
          include EnforcementRecoveryCeremonyCookie
          include EnforcementRecoveryCeremonyFlow

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          rate_limit to: 5, within: 1.minute, by: -> { request.remote_ip }, scope: "base_app_enforcement_recovery",
                     name: "email_create_ip_burst", store: rate_limit_store, only: :create,
                     with: -> { render_rate_limited(retry_after: 60) }

          private

          def render_recovery_reentry_new(status: :ok)
            render inertia: "base/app/identity/recovery/sessions/new",
                   props: recovery_session_new_props,
                   status: status
          end

          def recovery_session_new_props
            {
              title: "Account recovery",
              description: t("base.app.identity.recovery.sessions.new.description"),
              address_form: {
                action: base_app_identity_recovery_session_path,
                label: "Email address",
                address: @email_record&.address.to_s,
                submit_label: "Send verification code",
              },
              pass_code_form: @reentry_state.present? ? {
                action: base_app_identity_recovery_session_path,
                label: "Verification code",
                submit_label: "Continue",
              } : nil,
            }
          end

          def identity_email_model = ClientEmail

          def recovery_email_ceremony_model = ClientEmailCeremonyTransaction

          def recovery_subject_from_email(email) = Client.find_by(id: email&.user_id)

          def recovery_surface = :app

          def recovery_ceremony_class = ClientEnforcementRecoveryCeremony

          def recovery_case_class = AppEnforcementCase

          def recovery_email_status_column = :user_email_status_id

          def recovery_verified_email_status_ids = ClientEmail::EDITABLE_SUBSCRIPTION_PREFERENCE_STATUS_IDS

          def recovery_entry_path = new_base_app_identity_recovery_session_path

          def recovery_status_path = base_app_identity_recovery_path
        end
      end
    end
  end
end

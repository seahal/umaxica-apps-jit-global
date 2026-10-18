# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      module Recovery
        class SessionsController < ::Base::Com::ApplicationController
          include ::SurfaceInertiaPage
          include CommonRedirect
          include EnforcementRecoveryCeremonyCookie
          include EnforcementRecoveryCeremonyFlow

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          rate_limit to: 5, within: 1.minute, by: -> { request.remote_ip }, scope: "base_com_enforcement_recovery",
                     name: "email_create_ip_burst", store: rate_limit_store, only: :create,
                     with: -> { render_rate_limited(retry_after: 60) }

          private

          # Overrides the shared re-entry transport seam: this surface answers with an Inertia page.
          def render_recovery_reentry_new(status: :ok)
            render inertia: "base/com/identity/recovery/sessions/new",
                   props: new_page_props,
                   status: status
          end

          def new_page_props
            {
              title: "Account recovery",
              description: t("base.com.identity.recovery.sessions.new.description"),
              address_form: {
                url: base_com_identity_recovery_session_path,
                scope: "recovery_reentry",
                field: "address",
                label: "Email address",
                value: @email_record&.address.to_s,
                submit_label: "Send verification code",
              },
              pass_code_form: pass_code_form_props,
            }
          end

          def pass_code_form_props
            return if @reentry_state.blank?

            {
              url: base_com_identity_recovery_session_path,
              field: "pass_code",
              label: "Verification code",
              submit_label: "Continue",
            }
          end

          def identity_email_model = VisitorEmail

          def recovery_email_ceremony_model = VisitorEmailCeremonyTransaction

          def recovery_subject_from_email(email) = email && Visitor.find(email.visitor_id)

          def recovery_surface = :com

          def recovery_ceremony_class = VisitorEnforcementRecoveryCeremony

          def recovery_case_class = ComEnforcementCase

          def recovery_email_status_column = :visitor_email_status_id

          # VisitorEmail has no EDITABLE_SUBSCRIPTION_PREFERENCE_STATUS_IDS counterpart to the app
          # surface's ClientEmail constant; the verified-status set this needs already exists as
          # AuthMethodGuard::VISITOR_VERIFIED_EMAIL_STATUSES and carries the same two statuses.
          def recovery_verified_email_status_ids = AuthMethodGuard::VISITOR_VERIFIED_EMAIL_STATUSES

          def recovery_entry_path = new_base_com_identity_recovery_session_path

          def recovery_status_path = base_com_identity_recovery_path
        end
      end
    end
  end
end

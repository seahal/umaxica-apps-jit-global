# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Emails
        class RedeliveriesController < BaseController
          include CloudflareTurnstile
          include CommonRedirect
          include CommonOtp
          include SignEmailRegistrable
          include SignEmailRegistrationFlow
          include SignSettingsEmailRegistration
          include VerificationClient

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :preserve_email_registration_redirect_parameter, only: :create
          before_action :authorize_email_redelivery!, only: :create
          step_up only: :create, bootstrap: true
          def create = resend

          private

          # Reissuing the pending registration's passcode is part of the same create ceremony the
          # registrations controller gates, so it is authorized with the same rule. Without this the
          # private-action check rejects every request.
          def authorize_email_redelivery! = authorize!(ClientEmail, to: :create?)

          def email_registration_target_user = current_client

          def after_email_registration_started_path(params = {})
            edit_base_app_identity_emails_registration_path(params)
          end

          def new_email_registration_path(params = {}) = new_base_app_identity_emails_registration_path(params)

          def after_email_registration_verified_path
            email_registration_return_path(
              base_app_identity_emails_url(
                ri: params[:ri], host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
              ),
            )
          end

          def verification_required_action? = step_up_bootstrap_active?

          def verification_scope = "settings_email"

          def pending_email_status_id = ClientEmailStatus::UNVERIFIED

          def verified_email_status_id = ClientEmailStatus::VERIFIED

          def on_email_registration_verified!(*); nil end

          def create_audit_event!(event_id)
            ClientChronicle.create!(
              actor_type: "Client", actor_id: current_client.id, event_id: event_id,
              subject_id: current_client.id.to_s, subject_type: "Client", occurred_at: Time.current,
            )
          end

          def cleanup_pending_signup!; nil end

          def remove_existing_unverified_emails!; nil end
        end
      end
    end
  end
end

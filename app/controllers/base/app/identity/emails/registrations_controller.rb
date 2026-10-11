# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Emails
        class RegistrationsController < BaseController
          include ::SurfaceInertiaPage
          include CloudflareTurnstile
          include CommonRedirect
          include CommonOtp
          include SignEmailRegistrable
          include SignEmailRegistrationFlow
          include SignSettingsEmailRegistration
          include EnforcementIdentifierGate
          include VerificationClient

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_client!
          before_action :preserve_email_registration_redirect_parameter, only: %i(new create edit update resend)
          before_action :authorize_email_registration!, only: %i(new create edit update)
          step_up only: %i(new create edit update), bootstrap: true

          def new = super

          def edit = super

          def create = super

          def update = super

          def resend = super

          private

          def render_email_registration_new(status: :ok)
            render inertia: "base/app/identity/emails/registrations/new",
                   props: email_registration_new_props,
                   status: status
          end

          def render_email_registration_edit(status: :ok)
            render inertia: "base/app/identity/emails/registrations/edit",
                   props: email_registration_edit_props,
                   status: status
          end

          def email_registration_new_props
            {
              title: "Add an email address",
              back_link: { label: t("sign.app.settings.show.back"), href: preference_return_url },
              cancel_link: { label: "Cancel", href: preference_return_url },
              form: {
                action: base_app_identity_emails_registration_path,
                address_label: t("activerecord.attributes.user_email.address"),
                address: @user_email&.address.to_s,
                submit_label: "Submit",
                promotional: {
                  checked: @user_email&.promotional.present?,
                  label: t("sign.app.settings.email.edit.promotional_label"),
                  description: t("sign.app.settings.email.edit.promotional_description"),
                },
                notifiable: {
                  checked: @user_email&.notifiable.present?,
                  label: t("sign.app.settings.email.edit.notifiable_label"),
                  description: t("sign.app.settings.email.edit.notifiable_description"),
                },
              },
              errors: Array(@user_email&.errors&.full_messages),
            }
          end

          def email_registration_edit_props
            {
              title: "Verify your email address",
              description: t("base.app.identity.emails.registrations.edit.description"),
              cancel_link: { label: "Cancel", href: preference_return_url },
              form: {
                action: base_app_identity_emails_registration_path,
                code_label: "Verification code",
                code_placeholder: "123456",
                delivery_help: t("base.app.identity.emails.registrations.edit.delivery_help"),
                submit_label: "Verify",
                verification_token: @verification_token.presence,
              },
              resend: {
                label: t("otp.resend.button"),
                url: base_app_identity_emails_registration_redelivery_path(ri: params[:ri], pt: signed_pt_param),
              },
              errors: Array(@user_email&.errors&.full_messages),
            }
          end

          def preference_return_url
            base_app_preference_url(
              ri: params[:ri],
              host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
              protocol: request.protocol,
            )
          end

          def authorize_email_registration! = authorize!(ClientEmail, to: :create?)

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

          def on_email_registration_verified!(*)
            CredentialSecurityTransition.call(
              actor: current_client,
              current_session: current_session,
              reason: :email_address_verified,
              affected_surface: "app",
              request: request,
            )
          end

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

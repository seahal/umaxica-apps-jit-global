# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Emails
        class RegistrationsController < BaseController
          include ::SurfaceInertiaPage
          include ::TurnstilePageProps
          include CloudflareTurnstile
          include CommonRedirect
          include CommonOtp
          include SignEmailRegistrable
          include SignEmailRegistrationFlow
          include SignSettingsEmailRegistration
          include EnforcementIdentifierGate
          include VerificationClient
          include StepUpCeremonyLogging
          include BaseStepUpTransactionMarker

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :preserve_email_registration_redirect_parameter, only: %i(new create edit update resend)
          before_action :authorize_email_registration!, only: %i(new create edit update)
          step_up only: %i(new create edit update), bootstrap: true
          before_action :require_email_bootstrap_when_unconfigured!, only: %i(new create edit update)

          def new = super

          def edit = super

          def create = super

          def update = super

          def resend = super

          private

          def send_verification_email(code)
            flow = ContactRegistrationOtpIssuer.call!(
              actor: current_client, token: current_session_token, contact: @user_email, channel: :email,
              browser_nonce: ensure_base_admission_browser_nonce!, code:,
            )
            deliver_registration_email_otp!(code:, transaction: flow)
          end

          def finish_email_ceremony!(surface:, actor:, session_ref:, candidate:)
            unless surface == "app" && actor == current_client && session_ref == current_session_token.public_id
              raise IdentityEmailCeremonyContract::Error, "registration controller binding mismatch"
            end

            bootstrap = open_email_bootstrap_transaction
            status = ContactRegistrationOtpFinalizer.call!(
              actor:, actor_context: current_actor.with(surface: :base),
              token: current_session_token, contact: candidate,
              transaction: registration_email_otp_transaction, channel: :email,
              browser_nonce: base_admission_browser_nonce,
              requirement: step_up_requirement(scope: verification_scope),
              bootstrap_transaction: bootstrap,
            )
            unless status == :finalized
              raise IdentityEmailCeremonyContract::Error, "registration finalization is unavailable"
            end

            @email_bootstrap_return_to = bootstrap.return_to if bootstrap
            on_email_registration_verified!(user_email: candidate, target_user: actor)
            candidate
          end

          def require_step_up_unless_bootstrap!(scope:, **policy)
            return true if scope == "settings_email" && policy.empty? && bootstrap_receipt_recoverable?

            super
          end

          def verification_satisfied?
            return true if bootstrap_receipt_recoverable?

            super
          end

          def bootstrap_receipt_recoverable?
            return false unless action_name == "update"

            @user_email = current_registration_email
            bootstrap = open_email_bootstrap_transaction
            flow = registration_email_otp_transaction
            return false unless @user_email && bootstrap && flow

            ContactRegistrationOtpFinalizer.bootstrap_receipt_pending?(
              actor: current_client, actor_context: current_actor.with(surface: :base),
              token: current_session_token, contact: @user_email, transaction: flow, channel: :email,
              browser_nonce: base_admission_browser_nonce,
              requirement: step_up_requirement(scope: "settings_email"), bootstrap_transaction: bootstrap,
            )
          end

          def step_up_requirement(scope:)
            unless scope == "settings_email"
              raise StepUpRequirement::Invalid, "registration operation scope mismatch"
            end

            contact = @user_email || ClientEmail.new(user: current_client)
            ClientEmailPolicy.new(contact, user: current_client)
              .credential_registration_requirement(token: current_session_token)
          end

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
              back_link: { label: t("sign.app.settings.show.back"), href: emails_return_url },
              cancel_link: { label: "Cancel", href: emails_return_url },
              form: {
                action: base_app_identity_emails_registration_path,
                address_label: t("activerecord.attributes.user_email.address"),
                address: @user_email&.address.to_s,
                submit_label: "Submit",
                turnstile: turnstile_stealth_props,
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
              cancel_link: { label: "Cancel", href: emails_return_url },
              form: {
                action: base_app_identity_emails_registration_path,
                code_label: "Verification code",
                code_placeholder: "123456",
                delivery_help: t("base.app.identity.emails.registrations.edit.delivery_help"),
                submit_label: "Verify",
                verification_token: @verification_token.presence,
                turnstile: turnstile_stealth_props,
              },
              resend: {
                label: t("otp.resend.button"),
                url: base_app_identity_emails_registration_redelivery_path(ri: params[:ri], pt: signed_pt_param),
              },
              errors: Array(@user_email&.errors&.full_messages),
            }
          end

          def emails_return_url
            base_app_identity_emails_url(
              ri: params[:ri],
              host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
              protocol: request.protocol,
            )
          end

          def email_registration_turnstile_validation = cloudflare_turnstile_stealth_validation

          def authorize_email_registration! = authorize!(ClientEmail, to: :create?)

          def email_registration_target_user = current_client

          def after_email_registration_started_path(params = {})
            edit_base_app_identity_emails_registration_path(params)
          end

          def new_email_registration_path(params = {}) = new_base_app_identity_emails_registration_path(params)

          # A first address may be registered only inside the email bootstrap the person chose on
          # Base; without one the browser returns to that choice.
          def require_email_bootstrap_when_unconfigured!
            return unless step_up_bootstrap_unconfigured?
            return if open_email_bootstrap_transaction

            redirect_to(
              base_app_verification_setup_path(
                scope: "settings_email", ri: params[:ri],
                pt: encoded_relative_pt(base_app_identity_emails_path(ri: params[:ri])),
              ), status: :see_other,
            )
          end

          def open_email_bootstrap_transaction
            step_up_session = ClientStepUpSession.find_by(user_token_id: current_session_token.id)
            reference = step_up_session&.step_up_ceremony_transaction_ref
            return unless reference.is_a?(String) && reference.present? &&
              base_step_up_transaction_marker(
                reference:, surface: "app", actor: current_client, token: current_session_token,
              )

            ClientStepUpCeremonyTransaction.connection_owner.connected_to(role: :writing) do
              transaction = ClientStepUpCeremonyTransaction.find_by(
                transaction_id: reference, purpose: "bootstrap", status: "pending",
                actor_ref: current_client.public_id, session_ref: current_session_token.public_id,
              )
              next unless transaction &&
                transaction.allowed_methods_array == [IdentityEmailBootstrapCommitter::METHOD] &&
                !transaction.expired?(now: ClientStepUpCeremonyTransaction.database_now)

              transaction
            end
          end

          def after_email_registration_verified_path
            return @email_bootstrap_return_to if @email_bootstrap_return_to

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

# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      module Emails
        class RegistrationsController < ::Base::Org::ApplicationController
          include ::CloudflareTurnstile

          include EnforcementIdentifierGate

          include ::VerificationOperator

          include ::SurfaceInertiaPage
          include ::TurnstilePageProps

          AUTHENTICATION_MODE = :private

          # Object-level authorization (ActionPolicy): registering an email is a fresh-record action
          # for the authenticated operator, so gate by actor type. Each flow step builds/looks up the
          # email through current_operator.staff_emails (owner-scoped). Step-up/turnstile remain below.
          before_action :authorize_email_registration!, only: %i(new create edit update)
          step_up only: %i(new create edit update)

          def new
            @staff_email = OperatorEmail.new
            reset_registration_session!
            render inertia: true, props: new_page_props
          end

          def edit
            @staff_email = current_registration_email
            return render(inertia: true, props: edit_page_props) if valid_registration_session?

            reset_registration_session!
            redirect_to(
              new_base_org_identity_emails_registration_path,
            )
          end

          def create
            email_params = params.slice(:staff_email).permit(staff_email: %i(raw_address address notifiable)).fetch(
              :staff_email, {},
            )
            email_address = email_params[:raw_address] || email_params[:address]
            email_preferences = email_params.slice(:notifiable)
            @staff_email = current_operator.staff_emails.build(
              { raw_address: email_address, confirm_policy: "1" }.merge(email_preferences),
            )
            @staff_email.staff_email_status_id = OperatorEmailStatus::UNVERIFIED

            # adr/unified-enforcement.md, Identifier attachment enforcement: an in-force
            # Identifier Effect with attachment_blocked rejects attaching this identifier to
            # an existing account, at the same enumeration-resistance discipline as the
            # ordinary validation failure.
            if email_address.present? && enforcement_blocks_email_attachment?(
              effect_class: OrgEnforcementIdentifierEffect, realm: "org", email: email_address,
            )
              @staff_email.errors.add(:address, :blank)
              render_new_failure
              return
            end

            unless cloudflare_turnstile_stealth_validation["success"]
              @staff_email.errors.add(:base, t("sign.org.registration.email.create.turnstile_validation_failed"))
              render_new_failure
              return
            end

            unless @staff_email.save
              render_new_failure
              return
            end

            unless issue_registration_email_otp!
              render_new_failure
              return
            end

            session[registration_session_key] = @staff_email.public_id
            redirect_to(
              edit_base_org_identity_emails_registration_path,
            )
          end

          def update
            @staff_email = current_registration_email
            return fail_registration_session unless valid_registration_session?
            return fail_turnstile unless cloudflare_turnstile_stealth_validation["success"]

            submitted_code = params.dig(:staff_email, :pass_code)
            return fail_code_required if submitted_code.blank?

            result = EmailCredentialRegistrationOtpVerificationCommitter.call(
              actor: current_operator, token: current_session_token, email: @staff_email,
              transaction: registration_email_otp_transaction, browser_nonce: base_admission_browser_nonce,
              code: submitted_code,
            )
            return fail_otp_invalid unless result.verified_evidence?

            complete_registration!(submitted_code)
          end

          private

          def issue_registration_email_otp!
            issued = EmailCredentialRegistrationOtpIssuer.call(
              actor: current_operator, token: current_session_token, email: @staff_email,
              browser_nonce: ensure_base_admission_browser_nonce!,
            )
            unless issued.success?
              @staff_email.errors.add(:base, :invalid)
              return false
            end

            Notify::Org::OtpNotifier.issue(
              record: @staff_email,
              otp_code: issued.code,
              verification_token: nil,
              public_id: @staff_email.public_id,
              purpose: "credential_registration",
              contact_ceremony_transaction_ref: issued.transaction.transaction_id,
              contact_otp_generation: issued.transaction.otp_generation,
            )

            session[:staff_email_registration_transaction_ref] = issued.transaction.transaction_id
            true
          end

          def render_new_failure
            render inertia: "base/org/identity/emails/registrations/new",
                   props: new_page_props,
                   status: :unprocessable_content
          end

          def render_edit_failure
            render inertia: "base/org/identity/emails/registrations/edit",
                   props: edit_page_props,
                   status: :unprocessable_content
          end

          def new_page_props
            {
              title: t("sign.org.settings.email.new.page_title"),
              form: {
                action: base_org_identity_emails_registration_path,
                scope: "staff_email",
                address_label: OperatorEmail.human_attribute_name(:address),
                notifiable: @staff_email.notifiable,
                notifiable_label: t("sign.org.settings.email.edit.notifiable_label"),
                notifiable_description: t("sign.org.settings.email.edit.notifiable_description"),
                submit: t("helpers.submit.create", model: OperatorEmail.model_name.human),
                turnstile: turnstile_stealth_props,
              },
              cancel_link: {
                label: t("actions.cancel"),
                href: base_org_identity_emails_path(ri: params[:ri]),
              },
              error_messages: @staff_email.errors.full_messages,
            }
          end

          def edit_page_props
            {
              title: t("sign.org.authentication.email.edit.page_title"),
              description: t("sign.org.authentication.email.edit.description"),
              delivery_help: t("sign.org.authentication.email.edit.delivery_help"),
              form: {
                action: base_org_identity_emails_registration_path,
                scope: "staff_email",
                code_label: t("sign.org.authentication.email.edit.code_label"),
                code_placeholder: t("sign.org.authentication.email.edit.code_placeholder"),
                submit: t("sign.org.authentication.email.edit.submit"),
                turnstile: turnstile_stealth_props,
              },
              cancel_link: {
                label: t("sign.common.cancel"),
                href: base_org_identity_emails_path(ri: params[:ri]),
              },
              error_messages: @staff_email.errors.full_messages,
            }
          end

          def authorize_email_registration!
            authorize!(OperatorEmail, to: :create?)
          end

          def current_registration_email
            current_operator.staff_emails.find_by(public_id: session[registration_session_key])
          end

          def valid_registration_session?
            EmailCredentialRegistrationOtpFormQuery.call(
              actor: current_operator, token: current_session_token, email: @staff_email,
              transaction: registration_email_otp_transaction, browser_nonce: base_admission_browser_nonce,
            )
          end

          def registration_email_otp_transaction
            reference = session[:staff_email_registration_transaction_ref]
            return unless reference

            OperatorEmailCeremonyTransaction.find_by(transaction_id: reference)
          end

          def registration_session_key
            :staff_email_registration_public_id
          end

          def reset_registration_session!
            session.delete(registration_session_key)
            session.delete(:staff_email_registration_transaction_ref)
          end

          def fail_registration_session
            reset_registration_session!
            redirect_to(
              new_base_org_identity_emails_registration_path,
            )
          end

          def fail_turnstile
            @staff_email.errors.add(:base, t("turnstile_error"))
            render_edit_failure
          end

          def fail_code_required
            @staff_email.errors.add(:pass_code, t("sign.org.registration.email.update.code_required"))
            render_edit_failure
          end

          def fail_otp_invalid
            if @staff_email.locked?
              reset_registration_session!
              redirect_to(
                new_base_org_identity_emails_registration_path,
              )
            else
              @staff_email.errors.add(:pass_code, t("sign.org.registration.email.update.invalid_code"))
              render_edit_failure
            end
          end

          def complete_registration!(code)
            status = OperatorEmailRegistrationOtpFinalizer.call!(
              actor: current_operator, actor_context: current_actor.with(surface: :base),
              token: current_session_token, email: @staff_email, transaction: registration_email_otp_transaction,
              browser_nonce: base_admission_browser_nonce, code: code,
              requirement: step_up_requirement(scope: "settings_email"),
            )
            return fail_registration_session unless status == :finalized

            reset_registration_session!
            redirect_to_surface_url(
              bootstrap_return_path(
                base_org_identity_emails_url(
                  ri: params[:ri],
                  host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
                ),
              ),
            )
          end

          def verification_required_action?
            true
          end

          def step_up_requirement(scope:)
            raise StepUpRequirement::Invalid, "ORG Email registration scope mismatch" unless scope == "settings_email"

            OperatorEmailPolicy.new(@staff_email || OperatorEmail.new(staff: current_operator), user: current_operator)
              .credential_registration_requirement(token: current_session_token)
          end

          def verification_scope
            "settings_email"
          end
        end
      end
    end
  end
end

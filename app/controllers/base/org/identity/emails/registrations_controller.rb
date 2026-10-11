# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      module Emails
        class RegistrationsController < ::Base::Org::ApplicationController
          include ::CloudflareTurnstile

          include ::CommonOtp
          include SignSettingsEmailRegistration

          include EnforcementIdentifierGate

          include ::VerificationOperator

          include ::SurfaceInertiaPage
          include ::TurnstilePageProps

          AUTHENTICATION_MODE = :private

          before_action :authenticate_operator!
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
            email_params = params(staff_email: %i(raw_address address notifiable))
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

            otp_code = generate_otp_attributes(@staff_email)
            unless @staff_email.save
              render_new_failure
              return
            end

            OtpAdapter.for(surface: :org, channel: :email).deliver(
              record: @staff_email,
              otp_code: otp_code,
              verification_token: nil,
              public_id: @staff_email.public_id,
            )

            session[registration_session_key] = @staff_email.public_id
            start_email_ceremony!(
              surface: "org",
              actor: current_operator,
              session_ref: current_session_public_id,
              candidate: @staff_email,
            )
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

            result = verify_otp_code_and_consume(@staff_email, submitted_code)
            return fail_otp_invalid unless result[:success]

            complete_registration!
          end

          private

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
              title: t("sign.app.authentication.email.edit.page_title"),
              description: t("sign.app.authentication.email.edit.description"),
              delivery_help: t("sign.app.authentication.email.edit.delivery_help"),
              form: {
                action: base_org_identity_emails_registration_path,
                scope: "staff_email",
                code_label: t("sign.app.authentication.email.edit.code_label"),
                code_placeholder: t("sign.app.authentication.email.edit.code_placeholder"),
                submit: t("sign.app.authentication.email.edit.submit"),
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
            @staff_email.present? &&
              !@staff_email.otp_expired? &&
              @staff_email.staff_email_status_id == OperatorEmailStatus::UNVERIFIED
          end

          def registration_session_key
            :staff_email_registration_public_id
          end

          def reset_registration_session!
            session.delete(registration_session_key)
            reset_email_ceremony_session!
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
              @staff_email.destroy!
              reset_registration_session!
              redirect_to(
                new_base_org_identity_emails_registration_path,
              )
            else
              @staff_email.errors.add(:pass_code, t("sign.org.registration.email.update.invalid_code"))
              render_edit_failure
            end
          end

          def complete_registration!
            finish_email_ceremony!(
              surface: "org",
              actor: current_operator,
              session_ref: current_session_public_id,
              candidate: @staff_email,
            )
            reset_registration_session!
            redirect_to(
              bootstrap_return_path(
                base_org_identity_emails_url(
                  ri: params[:ri],
                  host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
                ),
              ),
              allow_other_host: cross_host_redirect_allowed?,
            )
          end

          def verification_required_action?
            true
          end

          def verification_scope
            "settings_email"
          end
        end
      end
    end
  end
end

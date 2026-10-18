# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      module Emails
        class RegistrationsController < ::Base::Com::ApplicationController
          include ::SurfaceInertiaPage
          include ::TurnstilePageProps
          include ::CloudflareTurnstile

          include CommonRedirect
          # `preserve_pt` and `retrieve_pt` below come from here; BrowserRpAuthentication does not
          # bring them in.
          include ::AuthenticationRedirects

          include EnforcementIdentifierGate

          include ::VerificationVisitor
          include BaseStepUpTransactionMarker

          AUTHENTICATION_MODE = :private

          # Object-level authorization (ActionPolicy): registering an email is a fresh-record action
          # for the authenticated visitor, so gate by actor type. Each flow step builds/looks up the
          # email through current_visitor.visitor_emails (owner-scoped). Step-up/turnstile remain below.
          before_action :authorize_email_registration!, only: %i(new create edit update)
          before_action :preserve_email_registration_redirect_parameter, only: %i(new create edit update)
          step_up only: %i(new create edit update), bootstrap: true
          before_action :require_email_bootstrap_when_unconfigured!, only: %i(new create edit update)

          def new
            @user_email = VisitorEmail.new
            reset_email_registration_flow!
            render inertia: true, props: new_page_props
          end

          def edit
            @user_email = current_registration_email
            @verification_token = params[:token]
            return render inertia: true, props: edit_page_props if valid_registration_email_session?

            reset_email_registration_flow!
            redirect_to(new_registration_path_with_notice)
          end

          def create
            email_params = params.slice(:visitor_email).permit(visitor_email: %i(raw_address address notifiable)).fetch(
              :visitor_email, {},
            )
            email_address = email_params[:raw_address] || email_params[:address]

            # adr/unified-enforcement.md, Identifier attachment enforcement: an in-force
            # Identifier Effect with attachment_blocked rejects attaching this identifier to
            # an existing account, at the same enumeration-resistance discipline as the
            # ordinary validation failure.
            if email_address.present? && enforcement_blocks_email_attachment?(
              effect_class: ComEnforcementIdentifierEffect, realm: "com", email: email_address,
            )
              @user_email = VisitorEmail.new
              @user_email.errors.add(:address, :blank)
              render_registration_new_failure
              return
            end

            unless initiate_visitor_email_verification!(
              email_address,
              email_preferences: email_params.slice(:notifiable),
            )
              render_registration_new_failure
              return
            end

            session[registration_email_session_key] = @user_email.public_id
            redirect_params = build_notice_params(
              t("sign.app.registration.email.create.verification_code_sent"),
              email_registration_pt_session_key,
            )
            sanitize_redirect_params!(redirect_params)
            redirect_to(edit_base_com_identity_emails_registration_path(redirect_params))
          end

          def update
            @user_email = current_registration_email

            unless valid_registration_email_session?
              reset_email_registration_flow!
              redirect_to(new_registration_path_with_notice)
              return
            end

            submitted_code = params.dig(:visitor_email, :pass_code)
            if submitted_code.blank?
              @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.code_required"))
              render_registration_edit_failure
              return
            end

            result = EmailCredentialRegistrationOtpVerificationCommitter.call(
              actor: current_visitor, token: current_session_token, email: @user_email,
              transaction: registration_email_otp_transaction,
              browser_nonce: base_admission_browser_nonce, code: submitted_code,
            )
            unless result.verified_evidence?
              @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.invalid_code"))
              render_registration_edit_failure
              return
            end

            finish_email_ceremony!(
              surface: "com",
              actor: current_visitor,
              session_ref: current_session_public_id,
              candidate: @user_email,
              code: submitted_code,
            )
            reset_email_registration_flow!
            redirect_to_surface_url(
              email_registration_return_path(
                base_com_identity_emails_url(
                  ri: params[:ri],
                  host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
                ),
              ),
            )
          end

          private

          # Both failure paths keep the page and the 422 the ERB flow answered with; only the
          # transport changed.
          def render_registration_new_failure
            render inertia: "base/com/identity/emails/registrations/new",
                   props: new_page_props,
                   status: :unprocessable_content
          end

          def render_registration_edit_failure
            render inertia: "base/com/identity/emails/registrations/edit",
                   props: edit_page_props,
                   status: :unprocessable_content
          end

          def new_page_props
            {
              title: t("sign.app.settings.email.new.page_title"),
              back_link: {
                label: t("sign.app.settings.show.back"),
                href: base_com_identity_emails_path(ri: params[:ri]),
              },
              errors: @user_email.errors.map(&:full_message),
              form: {
                url: base_com_identity_emails_registration_path,
                method: "post",
                scope: "visitor_email",
                # The ERB used a bare `form.submit`, whose label is Rails' create default.
                submit_label: t("helpers.submit.create", model: VisitorEmail.model_name.human),
              },
              address_label: VisitorEmail.human_attribute_name(:address),
              address_value: @user_email.address.to_s,
              notifiable: {
                label: t("sign.com.settings.email.edit.notifiable_label"),
                description: t("sign.com.settings.email.edit.notifiable_description"),
                checked: @user_email.notifiable?,
              },
              cancel_link: {
                label: t("actions.cancel"),
                href: base_com_identity_emails_path(ri: params[:ri]),
              },
              turnstile: turnstile_stealth_props,
            }
          end

          # The verification token is the one the visitor already holds from the delivery link; it is
          # echoed back so the submit carries it, exactly as the ERB hidden field did.
          def edit_page_props
            {
              title: t("sign.app.authentication.email.edit.page_title"),
              description: t("sign.app.authentication.email.edit.description"),
              errors: @user_email.errors.map(&:full_message),
              form: {
                url: base_com_identity_emails_registration_path,
                method: "patch",
                scope: "visitor_email",
                submit_label: t("sign.app.authentication.email.edit.submit"),
              },
              verification_token: @verification_token.presence,
              code_label: t("sign.app.authentication.email.edit.code_label"),
              code_placeholder: t("sign.app.authentication.email.edit.code_placeholder"),
              delivery_help: t("sign.app.authentication.email.edit.delivery_help"),
              cancel_link: {
                label: t("sign.app.common.cancel"),
                href: base_com_identity_emails_path(ri: params[:ri]),
              },
              turnstile: turnstile_stealth_props,
            }
          end

          def authorize_email_registration!
            authorize!(VisitorEmail, to: :create?)
          end

          def initiate_visitor_email_verification!(email_address, email_preferences: {})
            turnstile_result = cloudflare_turnstile_stealth_validation
            unless turnstile_result["success"]
              @user_email = VisitorEmail.new(raw_address: email_address, confirm_policy: "1")
              @user_email.errors.add(:base, t("sign.app.registration.email.create.turnstile_validation_failed"))
              return false
            end

            @user_email = current_visitor.visitor_emails.build(
              { raw_address: email_address, confirm_policy: "1" }.merge(email_preferences),
            )
            @user_email.visitor_email_status_id = VisitorEmailStatus::UNVERIFIED
            return false unless @user_email.valid?

            @user_email.save!
            issued = EmailCredentialRegistrationOtpIssuer.call(
              actor: current_visitor, token: current_session_token, email: @user_email,
              browser_nonce: ensure_base_admission_browser_nonce!,
              bootstrap_transaction: open_email_bootstrap_transaction,
            )
            return false unless issued.success?

            session[:com_settings_email_registration_transaction_ref] = issued.transaction.transaction_id
            Notify::Com::OtpNotifier.issue(
              record: @user_email,
              otp_code: issued.code,
              verification_token: nil,
              public_id: @user_email.public_id,
              purpose: "credential_registration",
              contact_ceremony_transaction_ref: issued.transaction.transaction_id,
              contact_otp_generation: issued.transaction.otp_generation,
            )

            true
          rescue ActiveRecord::RecordInvalid => e
            @user_email = e.record if e.record.is_a?(VisitorEmail)
            false
          end

          def current_registration_email
            current_visitor.visitor_emails.find_by(public_id: session[registration_email_session_key])
          end

          def require_email_bootstrap_when_unconfigured!
            return unless step_up_bootstrap_unconfigured?
            return if open_email_bootstrap_transaction

            redirect_to(
              base_com_verification_setup_path(
                scope: "settings_email", ri: params[:ri],
                pt: encoded_relative_pt(base_com_identity_emails_path(ri: params[:ri])),
              ), status: :see_other,
            )
          end

          def open_email_bootstrap_transaction
            step_up_session = VisitorStepUpSession.find_by(visitor_token_id: current_session_token.id)
            reference = step_up_session&.step_up_ceremony_transaction_ref
            return unless reference.is_a?(String) && reference.present? &&
              base_step_up_transaction_marker(
                reference:, surface: "com", actor: current_visitor, token: current_session_token,
              )

            VisitorStepUpCeremonyTransaction.connection_owner.connected_to(role: :writing) do
              transaction = VisitorStepUpCeremonyTransaction.find_by(
                transaction_id: reference, purpose: "bootstrap", status: "pending",
                actor_ref: current_visitor.public_id, session_ref: current_session_token.public_id,
              )
              next unless transaction && transaction.allowed_methods_array == ["email_otp"] &&
                !transaction.expired?(now: VisitorStepUpCeremonyTransaction.database_now)

              transaction
            end
          end

          def valid_registration_email_session?
            EmailCredentialRegistrationOtpFormQuery.call(
              actor: current_visitor, token: current_session_token, email: @user_email,
              transaction: registration_email_otp_transaction, browser_nonce: base_admission_browser_nonce,
            )
          end

          def registration_email_otp_transaction
            reference = session[:com_settings_email_registration_transaction_ref]
            return unless reference

            VisitorEmailCeremonyTransaction.find_by(transaction_id: reference)
          end

          def finish_email_ceremony!(surface:, actor:, session_ref:, candidate:, code:)
            unless surface == "com" && actor == current_visitor && session_ref == current_session_token.public_id
              raise IdentityEmailCeremonyContract::Error, "registration controller binding mismatch"
            end

            bootstrap = registration_email_bootstrap_transaction
            status = EmailCredentialRegistrationOtpFinalizer.call!(
              actor:, actor_context: current_actor.with(surface: :base),
              token: current_session_token, email: candidate,
              transaction: registration_email_otp_transaction,
              browser_nonce: base_admission_browser_nonce, code: code,
              requirement: step_up_requirement(scope: verification_scope),
              bootstrap_transaction: bootstrap,
            )
            unless status == :finalized
              raise IdentityEmailCeremonyContract::Error, "registration finalization is unavailable"
            end

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
            bootstrap = registration_email_bootstrap_transaction
            flow = registration_email_otp_transaction
            return false unless @user_email && bootstrap && flow

            EmailCredentialRegistrationOtpFinalizer.bootstrap_receipt_pending?(
              actor: current_visitor, actor_context: current_actor.with(surface: :base),
              token: current_session_token, email: @user_email, transaction: flow,
              browser_nonce: base_admission_browser_nonce,
              code: params.dig(:visitor_email, :pass_code),
              requirement: step_up_requirement(scope: "settings_email"), bootstrap_transaction: bootstrap,
            )
          end

          def registration_email_bootstrap_transaction
            reference = registration_email_otp_transaction&.bootstrap_ceremony_transaction_ref
            return unless reference

            VisitorStepUpCeremonyTransaction.find_by(transaction_id: reference)
          end

          def step_up_requirement(scope:)
            unless scope == "settings_email"
              raise StepUpRequirement::Invalid, "registration operation scope mismatch"
            end

            contact = @user_email || VisitorEmail.new(visitor: current_visitor)
            VisitorEmailPolicy.new(contact, user: current_visitor)
              .credential_registration_requirement(token: current_session_token)
          end

          def registration_email_session_key
            :com_settings_email_registration_public_id
          end

          def reset_email_registration_flow!
            session.delete(registration_email_session_key)
            session.delete(:com_settings_email_registration_transaction_ref)
          end

          def new_registration_path_with_notice
            redirect_params = build_notice_params(
              t("sign.app.registration.email.edit.session_expired"),
              email_registration_pt_session_key,
            )
            sanitize_redirect_params!(redirect_params)
            new_base_com_identity_emails_registration_path(redirect_params)
          end

          def email_registration_return_path(default_path)
            encoded = retrieve_pt(email_registration_pt_session_key)
            return default_path if encoded.blank?

            path_from_signed_pt(encoded) || default_path
          end

          def preserve_email_registration_redirect_parameter
            preserve_pt(email_registration_pt_session_key)
          end

          def email_registration_pt_session_key
            :com_settings_email_registration_pt
          end

          def sanitize_redirect_params!(redirect_params)
            return if redirect_params[:pt].blank?

            redirect_params[:pt] = sanitize_encoded_redirect(redirect_params[:pt])
            redirect_params.delete(:pt) if redirect_params[:pt].blank?
          end

          def sanitize_encoded_redirect(encoded_url)
            signed_pt_token(encoded_url)
          end

          def verification_required_action?
            step_up_bootstrap_active?
          end

          def on_email_registration_verified!(*)
            CredentialSecurityTransition.call(
              actor: current_visitor,
              current_session: current_session,
              reason: :email_address_verified,
              affected_surface: "com",
              revoke_other_sessions: false,
              request: request,
            )
          end

          def verification_scope
            "settings_email"
          end
        end
      end
    end
  end
end

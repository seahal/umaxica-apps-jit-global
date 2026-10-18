# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Telephones
        class RegistrationsController < BaseController
          include ::SurfaceInertiaPage
          include CloudflareTurnstile
          include CommonRedirect
          include EnforcementIdentifierGate
          include VerificationClient

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          TELEPHONE_VERIFICATION_RATE_LIMIT = 5
          TELEPHONE_VERIFICATION_RATE_WINDOW = 60

          before_action :authorize_telephone_registration!, only: %i(new create edit update)

          def new
            @user_telephone = ClientTelephone.new
            reset_registration_session!
            render_registration_new
          end

          def edit
            @user_telephone = current_registration_telephone
            unless valid_registration_session?
              reset_registration_session!
              return redirect_to(
                new_base_app_identity_telephones_registration_path,
              )
            end
            render_registration_edit
          end

          def create
            unless cloudflare_turnstile_stealth_validation["success"]
              @user_telephone = ClientTelephone.new
              @user_telephone.errors.add(:base, t("turnstile_error"))
              return render_registration_new(status: :unprocessable_content)
            end
            tel_params = params.expect(user_telephone: [:raw_number, :number])
            number = tel_params[:raw_number] || tel_params[:number]

            # adr/unified-enforcement.md, Identifier attachment enforcement: an in-force
            # Identifier Effect with attachment_blocked rejects attaching this identifier to
            # an existing account, at the same enumeration-resistance discipline as the
            # ordinary validation failure.
            if number.present? && enforcement_blocks_telephone_attachment?(
              effect_class: AppEnforcementIdentifierEffect, realm: "app", telephone: number,
            )
              @user_telephone = ClientTelephone.new
              @user_telephone.errors.add(:raw_number, :blank)
              return render_registration_new(status: :unprocessable_content)
            end

            return render_registration_new(status: :unprocessable_content) unless initiate_telephone_verification(
              current_client,
              number, auto_accept_confirmations: true,
            )

            session[registration_session_key] = @user_telephone.id
            redirect_to(
              edit_base_app_identity_telephones_registration_path,
            )
          end

          def update
            @user_telephone = current_registration_telephone
            unless valid_registration_session?
              reset_registration_session!
              return redirect_to(
                new_base_app_identity_telephones_registration_path,
              )
            end
            unless cloudflare_turnstile_stealth_validation["success"]
              @user_telephone.errors.add(:base, t("turnstile_error"))
              return render_registration_edit(status: :unprocessable_content)
            end
            submitted_code = params.dig(:user_telephone, :pass_code)
            status = complete_telephone_verification(@user_telephone.id, submitted_code)
            handle_registration_update_status(status, submitted_code)
          end

          private

          def authorize_telephone_registration! = authorize!(ClientTelephone, to: :create?)

          def handle_registration_update_status(status, code)
            case status
            when :success
              finish_telephone_ceremony!(
                surface: "app", actor: current_client, session_ref: current_session_public_id,
                candidate: @user_telephone, code: code,
              )
              reset_registration_session!
              redirect_to(
                base_app_identity_telephones_url(
                  ri: params[:ri],
                  host: preferred_base_service_host,
                ),
                status: :see_other,
              )
            when :session_expired
              reset_registration_session!
              redirect_to(
                new_base_app_identity_telephones_registration_path,
              )
            else
              render_registration_edit(status: :unprocessable_content)
            end
          end

          def render_registration_new(status: :ok)
            render inertia: "base/app/identity/telephones/registrations/new",
                   props: registration_new_props,
                   status: status
          end

          def render_registration_edit(status: :ok)
            render inertia: "base/app/identity/telephones/registrations/edit",
                   props: registration_edit_props,
                   status: status
          end

          def registration_new_props
            {
              title: t("sign.app.settings.telephone.new.title"),
              description: t("views.sign.app.settings.telephones.registrations.new.description"),
              help_text: t("views.sign.app.settings.telephones.registrations.new.help_text"),
              number_label: "Number",
              number_placeholder: "+819012345678",
              form: {
                action: base_app_identity_telephones_registration_path,
                submit_label: "Submit",
              },
              cancel_link: { label: "Cancel", href: base_app_identity_telephones_path(ri: params[:ri]) },
              errors: Array(@user_telephone&.errors&.full_messages),
            }
          end

          def registration_edit_props
            {
              title: "Verify your telephone number",
              description: t("sign.app.registration.telephone.create.verification_code_sent"),
              code_label: "Verification code",
              code_placeholder: "123456",
              delivery_help: t("base.app.identity.telephones.registrations.edit.delivery_help"),
              form: {
                action: base_app_identity_telephones_registration_path,
                submit_label: "Verify",
              },
              cancel_link: { label: "Cancel", href: base_app_identity_telephones_path(ri: params[:ri]) },
              errors: Array(@user_telephone&.errors&.full_messages),
            }
          end

          def preferred_base_service_host
            ENV.fetch("PUBLIC_BASE_SERVICE_URL")
          end

          def current_registration_telephone = ClientTelephone.find_by(id: session[registration_session_key])

          def valid_registration_session?
            TelephoneCredentialRegistrationOtpFormQuery.call(
              actor: current_client, token: current_session_token, telephone: @user_telephone,
              transaction: registration_otp_transaction, browser_nonce: base_admission_browser_nonce,
            )
          end

          def initiate_telephone_verification(user, number, auto_accept_confirmations: false)
            return false if user.blank?

            check_telephone_verification_rate_limit!(number)
            @user_telephone = user.client_telephones.build(raw_number: number)
            if auto_accept_confirmations
              @user_telephone.confirm_policy = true
              @user_telephone.confirm_using_mfa = true
            end
            return false unless @user_telephone.valid?

            @user_telephone.save!
            issued = TelephoneCredentialRegistrationOtpIssuer.call(
              actor: user, token: current_session_token, telephone: @user_telephone,
              browser_nonce: ensure_base_admission_browser_nonce!,
            )
            return false unless issued.success?

            session[registration_transaction_session_key] = issued.transaction.transaction_id
            OtpAdapter.for(surface: :app, channel: :telephone).deliver(
              record: @user_telephone, otp_code: issued.code, purpose: "credential_registration",
              public_id: @user_telephone.public_id, message_style: :localized_verification,
              contact_ceremony_transaction_ref: issued.transaction.transaction_id,
              contact_otp_generation: issued.transaction.otp_generation,
            )
            true
          end

          def complete_telephone_verification(id, submitted_code)
            return :session_expired unless @user_telephone && @user_telephone.id == id && registration_otp_transaction

            result = TelephoneCredentialRegistrationOtpVerificationCommitter.call(
              actor: current_client, token: current_session_token, telephone: @user_telephone,
              transaction: registration_otp_transaction,
              browser_nonce: base_admission_browser_nonce, code: submitted_code,
            )
            return :success if result.verified_evidence?
            return :session_expired if %i(unavailable result_expired session_mismatch locked).include?(result.status)

            @user_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.invalid_code"))
            result.status
          end

          def finish_telephone_ceremony!(surface:, actor:, session_ref:, candidate:, code:)
            unless surface == "app" && actor == current_client && session_ref == current_session_token.public_id
              raise IdentityTelephoneCeremony::Error, "registration controller binding mismatch"
            end

            status = TelephoneCredentialRegistrationOtpFinalizer.call!(
              actor:, actor_context: current_actor.with(surface: :base),
              token: current_session_token, telephone: candidate, code: code,
              transaction: registration_otp_transaction,
              browser_nonce: base_admission_browser_nonce,
              requirement: step_up_requirement(scope: verification_scope),
            )
            return candidate if status == :finalized

            raise IdentityTelephoneCeremony::Error, "registration finalization is unavailable"
          end

          def registration_otp_transaction
            reference = session[registration_transaction_session_key]
            return unless reference

            ClientTelephoneCeremonyTransaction.find_by(transaction_id: reference)
          end

          def step_up_requirement(scope:)
            unless scope == "settings_telephone"
              raise StepUpRequirement::Invalid, "registration operation scope mismatch"
            end

            contact = @user_telephone || ClientTelephone.new(user: current_client)
            ClientTelephonePolicy.new(contact, user: current_client)
              .credential_registration_requirement(token: current_session_token)
          end

          def registration_session_key = :settings_telephone_registration_id

          def registration_transaction_session_key = :settings_telephone_registration_transaction_ref

          def reset_registration_session!
            session.delete(registration_session_key)
            session.delete(registration_transaction_session_key)
          end

          def check_telephone_verification_rate_limit!(number)
            phone_digest = IdentifierBlindIndex.bidx_for_telephone(number, realm: :app).presence || "unknown"
            cache_key = "rate-limit:telephone_verification:ip:#{request.remote_ip}:phone:#{phone_digest}"
            count = Rails.configuration.x.rate_limit.fetch(:store).increment(
              cache_key, 1, expires_in: TELEPHONE_VERIFICATION_RATE_WINDOW.seconds,
            )
            return unless count && count > TELEPHONE_VERIFICATION_RATE_LIMIT

            AuthenticationSecurityEventEmitter.emit(
              "rate_limit.exceeded", severity: "warning", reason_code: "telephone_verification_rate_limit",
                                     ip: request.remote_ip, phone_digest: phone_digest,
                                     retry_after: TELEPHONE_VERIFICATION_RATE_WINDOW,
            )
            raise ActionController::TooManyRequests
          end

          def verification_required_action? = true

          def verification_scope = "settings_telephone"
        end
      end
    end
  end
end

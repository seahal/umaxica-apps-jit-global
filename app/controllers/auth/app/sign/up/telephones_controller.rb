# typed: false
# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength

module Auth
  module App
    module Sign
      module Up
        class TelephonesController < ::Auth::App::ApplicationController
          include ::SurfaceInertiaPage
          include ::TurnstilePageProps
          include CloudflareTurnstile

          include CommonRedirect

          include CommonOtp

          include EnforcementIdentifierGate

          include SignUpSuspensionGuard
          include AppSignUpEntryPage

          AUTHENTICATION_MODE = :guest

          before_action :reject_suspended_sign_up!

          declare_authentication_mode! :guest, status: :unauthorized,
                                               message: I18n.t("errors.messages.already_authenticated"),
                                               no_redirect: true

          def new
            @user_telephone = ClientTelephone.new

            # to avoid session attack
            session[:user_telephone_registration] = nil
            sign_up_flow_locator.clear!
            log_sign_signup_event(
              "sign.signup.telephone.new.rendered",
              sign_signup_request_flags.merge(step: "telephone_otp"),
            )
            render_sign_up_telephone_new
          end

          def create
            log_sign_signup_event(
              "sign.signup.telephone.create.received",
              sign_signup_request_flags.merge(step: "telephone_otp"),
            )
            ensure_signup_reference_defaults!

            telephone_params = telephone_signup_params.permit(
              :raw_number, :number, :confirm_policy, :confirm_using_mfa,
            )

            if telephone_params.blank?
              @user_telephone = ClientTelephone.new
              @user_telephone.errors.add(:raw_number, :blank)
              log_sign_signup_event(
                "sign.signup.telephone.create.rejected",
                sign_signup_request_flags.merge(step: "telephone_otp", reason: "telephone_blank").compact,
              )
              render_sign_up_telephone_new(status: :unprocessable_content)
              return
            end

            # adr/unified-enforcement.md, Signup enforcement: an in-force Identifier
            # Effect with registration_blocked rejects signup before turnstile/OTP
            # work happens, at the same enumeration-resistance discipline as an
            # ordinary validation failure.
            raw_number = telephone_params[:raw_number].presence || telephone_params[:number].presence
            if raw_number.present? && enforcement_blocks_telephone_registration?(
              effect_class: AppEnforcementIdentifierEffect, realm: "app", telephone: raw_number,
            )
              @user_telephone = ClientTelephone.new
              @user_telephone.errors.add(:raw_number, :blank)
              render_sign_up_telephone_new(status: :unprocessable_content)
              return
            end

            @user_telephone = ClientTelephone.new(telephone_params || {})

            res = cloudflare_turnstile_validation

            unless res["success"]
              @user_telephone.errors.add(
                :base,
                t("sign.app.registration.telephone.create.turnstile_validation_failed"),
              )
              log_sign_signup_event(
                "sign.signup.telephone.create.rejected",
                sign_signup_request_flags.merge(step: "telephone_otp", reason: "turnstile_failed").compact,
              )
              render_sign_up_telephone_new(status: :unprocessable_content)
              return
            end

            @user_telephone.validate

            has_errors = @user_telephone.errors.details.except(:user, :user_id).any?

            if has_errors
              log_signup_telephone_errors
              log_sign_signup_event(
                "sign.signup.telephone.create.rejected",
                sign_signup_request_flags.merge(step: "telephone_otp", reason: "telephone_invalid").compact,
              )
              render_sign_up_telephone_new(status: :unprocessable_content)
              return
            end

            begin
              result = SignAppUpTelephoneSignupCreator.call(
                telephone: @user_telephone,
                pending_public_id: session_public_id_from_registration,
              )

              @user_telephone = result.telephone
              session[:user_telephone_registration] = result.session_payload
              bind_sign_up_flow_to_telephone!(@user_telephone)
              redirect_to(
                auth_app_sign_up_check_telephone_otp_path,
              )
            rescue ActiveRecord::RecordInvalid => e
              @user_telephone = e.record
              log_signup_telephone_errors
              log_sign_signup_event(
                "sign.signup.telephone.create.rejected",
                sign_signup_request_flags.merge(step: "telephone_otp", reason: "unexpected_error").compact,
              )
              render_sign_up_telephone_new(status: :unprocessable_content)
            end
          end

          private

          def sign_up_surface = :app

          # The registration form. `pt` travels in the generated action URL rather than as a prop,
          # so the signed target never becomes page data the browser holds separately.
          def render_sign_up_telephone_new(status: :ok)
            render inertia: "auth/app/sign/up/telephones/new",
                   props: sign_up_telephone_new_props,
                   status: status
          end

          def sign_up_telephone_new_props
            errors = sign_up_telephone_errors

            {
              title: t("sign.app.registration.telephone.new.page_title"),
              action: auth_app_sign_up_telephone_path(pt: signed_pt_param),
              scope: "client_telephone",
              field: {
                name: "raw_number",
                label: ClientTelephone.human_attribute_name(:number),
                type: "tel",
                autocomplete: "tel",
              },
              checkboxes: [
                {
                  name: "confirm_policy",
                  label: t("views.sign.app.up.telephones.new.confirm_policy_label"),
                  description: nil,
                },
                {
                  name: "confirm_using_mfa",
                  label: t("views.sign.app.up.telephones.new.confirm_using_mfa_label"),
                  description: nil,
                },
              ],
              error_heading: errors.any? ? sign_up_telephone_error_heading(errors.count) : nil,
              errors: errors,
              turnstile: turnstile_visible_props,
              submit_label: sign_up_telephone_submit_label,
              links: [
                {
                  key: "other_methods",
                  label: t("sign.app.registration.telephone.new.link_to_other_methods"),
                  href: auth_app_sign_up_path,
                },
                {
                  key: "sign_in",
                  label: t("sign.app.registration.telephone.new.link_to_sign_in"),
                  href: auth_app_sign_in_path,
                },
              ],
            }
          end

          # The OTP step. Only what the page shows crosses: never the code, the ceremony nonce or
          # the number the server already holds in the flow.
          def render_sign_up_telephone_edit(status: :ok)
            render inertia: "auth/app/sign/up/telephones/edit",
                   props: sign_up_telephone_edit_props,
                   status: status
          end

          def sign_up_telephone_edit_props
            errors = sign_up_telephone_errors

            {
              title: t("sign.app.registration.telephone.edit.page_title"),
              description: t("sign.app.registration.telephone.create.verification_code_sent"),
              action: auth_app_sign_up_check_telephone_otp_path(ri: params[:ri]),
              scope: "client_telephone",
              code_label: t("sign.app.registration.telephone.edit.code_label"),
              code_placeholder: t("sign.app.registration.telephone.edit.code_placeholder"),
              submit_label: t("sign.app.registration.telephone.edit.submit"),
              delivery_help: t("sign.app.registration.telephone.edit.delivery_help"),
              error_heading: errors.any? ? sign_up_telephone_error_heading(errors.count) : nil,
              errors: errors,
              # The code has been sent and a ticket exists, so /sign/up is not a step back: the only exit
              # ends the sign-up through the existing DELETE cancellation.
              cancel: { label: t("actions.cancel"),
                        action: auth_app_sign_up_check_telephone_otp_path(ri: params[:ri]),
                        method: "delete", },
            }
          end

          def sign_up_telephone_errors
            @user_telephone&.errors&.map(&:full_message) || []
          end

          # The wording the ERB built with `pluralize`, kept verbatim.
          def sign_up_telephone_error_heading(count)
            "#{helpers.pluralize(count, "error")} prohibited this telephone from being saved:"
          end

          # Mirrors the label `form.submit` looked up, so the button keeps its wording.
          def sign_up_telephone_submit_label
            I18n.t(
              :"helpers.submit.#{ClientTelephone.model_name.param_key}.create",
              model: ClientTelephone.model_name.human,
              default: [:"helpers.submit.create", "Create %{model}"],
            )
          end

          def valid_telephone_session?
            return false unless @user_telephone.present? && !@user_telephone.otp_expired?

            @user_telephone.user_telephone_status_id == ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
          end

          def redirect_telephone_session_expired
            redirect_to(
              new_auth_app_sign_up_telephone_path,
            )
          end

          def render_otp_resend_too_soon
            render plain: t("sign.app.registration.email.create.otp_resend_too_soon"), status: :too_many_requests
          end

          def render_telephone_session_expired
            @user_telephone.errors.add(:base, t("sign.app.registration.telephone.edit.session_expired"))
            render_sign_up_telephone_edit(status: :unprocessable_content)
          end

          def telephone_signup_params
            params.fetch(:client_telephone, params.fetch(:user_telephone, {}))
          end

          def session_public_id_from_registration(registration_session = session[:user_telephone_registration])
            registration_session&.dig("public_id") || registration_session&.dig(:public_id)
          end

          # Read by the check-step OTP controller, which inherits from this one.
          def otp_resend_rate_limited?
            last_sent_at = session[:user_telephone_otp_last_sent_at]
            return false if last_sent_at.blank?

            last_sent_at.to_i > CommonOtpPolicy::SEND_COOLDOWN.ago.to_i
          end

          def cleanup_pending_telephone_signup!
            pending_public_id =
              session.dig(:user_telephone_registration, "public_id") ||
              session.dig(:user_telephone_registration, :public_id)
            sign_up_flow_locator.clear!
            return if pending_public_id.blank?

            pending_telephone = ClientTelephone.find_by(public_id: pending_public_id)
            return unless pending_telephone

            pending_user = pending_telephone.user
            pending_telephone.destroy!
            pending_user.destroy! if pending_user&.status_id == ClientStatus::UNVERIFIED_WITH_SIGN_UP
          end

          def log_signup_telephone_errors
            return unless @user_telephone&.errors&.any?

            Rails.logger.warn(
              JitLogEvent.format(
                "sign.signup.telephone.validation_failed",
                errors: @user_telephone.errors.full_messages,
              ),
            )
          end

          def issue_sign_up_flow!
            sign_up_flow_locator.issue!(
              ClientSignUpFlow.create!(
                principal_id: nil,
                status_id: ClientSignUpFlowStatus::STARTED,
                step: "start",
                nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
                issued_at: Time.current,
                expires_at: ClientSignUpFlow.default_ttl.from_now,
                entry_method: "telephone",
              ),
            )
          end

          def current_sign_up_flow
            sign_up_flow_locator.current || issue_sign_up_flow!
          end

          def bind_sign_up_flow_to_telephone!(telephone)
            cycle = current_sign_up_flow
            cycle.update!(
              principal_id: telephone.user_id,
              pending_contact_type: "telephone",
              pending_contact_id: telephone.id,
            )
            SignUpStateMachine.call(ticket: cycle, event: :submit_contact, actor_context: Actor.authn)
            session[:auth_app_up_sequence_id] = cycle.public_id
          end

          def sign_up_flow_locator
            SignUpCycleLocator.new(session, surface: :app, cycle_class: ClientSignUpFlow)
          end

          def ensure_signup_reference_defaults!
            ClientStatus.ensure_defaults!
            ClientVisibility.ensure_defaults!
            ClientMfaLevel.ensure_defaults!
            ClientMfaStatus.ensure_defaults!
            ClientTelephoneStatus.ensure_defaults!
          end

          def current_registration_telephone
            public_id = session_public_id_from_registration
            return if public_id.blank?

            ClientTelephone.find_by(public_id: public_id)
          end
        end
      end
    end
  end
end

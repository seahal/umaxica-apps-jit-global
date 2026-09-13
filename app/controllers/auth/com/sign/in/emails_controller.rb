# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module In
        class EmailsController < ::Auth::Com::ApplicationController
          include ::CloudflareTurnstile

          include EmailValidation

          include CommonRedirect

          include CommonOtp

          include SessionLimitGate
          include ::SurfaceInertiaPage
          include ::TurnstilePageProps
          include ::AuthenticationModeSwitchGuard

          AUTHENTICATION_MODE = :guest

          rate_limit(
            to: 5,
            within: 1.minute,
            by: -> { request.remote_ip },
            scope: "auth_com_sign_in",
            name: "email_create_ip_burst",
            store: rate_limit_store,
            only: :create,
            with: -> { render_rate_limited(retry_after: 60) },
          )
          rate_limit(
            to: 20,
            within: 15.minutes,
            by: -> { request.remote_ip },
            scope: "auth_com_sign_in",
            name: "email_create_ip_sustained",
            store: rate_limit_store,
            only: :create,
            with: -> { render_rate_limited(retry_after: 900) },
          )
          declare_authentication_mode!(
            :guest,
            status: :bad_request,
            message: I18n.t("sign.app.authentication.email.new.you_have_already_logged_in"),
            no_redirect: true,
          )

          before_action :load_user_email, only: %i(edit update)

          def identity_email_model
            VisitorEmail
          end

          def new
            @user_email = VisitorEmail.new
            render inertia: true, props: sign_in_email_new_props
          end

          def edit
            # `load_user_email` redirects when the ceremony has no live email session.
            return if performed?

            render inertia: true, props: sign_in_email_edit_props
          end

          def create
            address_params = params.slice(:user_email).permit(user_email: [:address])[:user_email] || {}
            address = address_params[:address]
            unless cloudflare_turnstile_validation["success"] && address.present?
              @user_email = VisitorEmail.new(address: address)
              return render_sign_in_email_new_with_errors
            end

            normalized_address = validate_and_normalize_email(address)
            unless normalized_address
              @user_email = VisitorEmail.new(address: address)
              @user_email.errors.add(:address, t("sign.app.authentication.email.create.invalid_format"))
              return render_sign_in_email_new_with_errors
            end

            if sign_in_email_cooldown_active?(normalized_address)
              # One message for every address. Branching on whether the account exists
              # would turn the cooldown response into an account-existence oracle,
              # which is exactly what the dummy OTP work below exists to prevent.
              render plain: t("sign.app.authentication.email.create.cooldown"), status: :too_many_requests
              return
            end

            result = process_email_authentication(normalized_address)

            if result == :cooldown
              render plain: t("sign.app.authentication.email.create.cooldown"), status: :too_many_requests
              return
            end

            return render_session_limit_hard_reject if @session_limit_hard_reject

            record_sign_in_email_cooldown!(normalized_address)
            preserve_pt

            redirect_to(edit_auth_com_sign_in_email_path(pt: peek_pt, ri: current_region_identifier))
          end

          def update
            @user_email.pass_code = update_pass_code_params[:pass_code]
            unless @user_email.valid?
              @user_email.errors.add(:pass_code, t("sign.app.authentication.email.update.invalid_code"))
              return render inertia: "auth/com/sign/in/emails/edit", props: sign_in_email_edit_props,
                            status: :unprocessable_content
            end

            result = verify_otp_code(@user_email, @user_email.pass_code)
            unless result[:success] && @user_email.visitor&.login_allowed?
              increment_otp_attempts!(@user_email) unless result[:success]
              @user_email.errors.add(:pass_code, t("sign.app.authentication.email.update.invalid_code"))
              return render inertia: "auth/com/sign/in/emails/edit", props: sign_in_email_edit_props,
                            status: :unprocessable_content
            end

            visitor = @user_email.visitor
            clear_otp(@user_email)
            session.delete(:user_email_authentication_id)
            session.delete(:user_email_authentication_address)
            result = AuthenticationSessionCommitter.call(
              controller: self, resource: visitor, pt: peek_pt, ri: current_region_identifier, auth_method: "email",
            )
            sign_in_result = sign_in_result_from_session_result(result, actor: visitor)
            unless sign_in_result.success? || sign_in_result.mfa_required? || sign_in_result.session_limit_pending?
              return render_session_limit_hard_reject(
                message: sign_in_result.message,
                http_status: sign_in_result.response_status,
              )
            end

            # The successful destination is the base corporate dashboard, a different host
            # from this surface, so a bare `redirect_to` raises OpenRedirectError. Branch
            # exactly as AuthenticationSequenceGate#redirect_to_sign_in_sequence! does:
            # same-origin paths redirect directly, full URLs go through the jump gateway.
            destination = sign_in_result.redirect_to.presence || auth_com_root_path
            if destination.start_with?("/")
              redirect_to(destination, allow_other_host: false, status: :see_other)
            else
              redirect_to_jump_url(destination, status: :see_other)
            end
          end

          private

          # A rejected submission re-renders this page with 422 and the errors the page reads.
          # Which guard rejected the submission, and what it says, is unchanged.
          def render_sign_in_email_new_with_errors
            render(
              inertia: "auth/com/sign/in/emails/new",
              props: sign_in_email_new_props.merge(
                errors: @user_email.errors.to_hash(true).transform_values(&:first),
              ),
              status: :unprocessable_content,
            )
          end

          def sign_in_email_new_props
            pt = signed_pt_param

            {
              title: t("sign.app.authentication.email.new.page_title"),
              description: t("sign.app.registration.new.social.disclaimer", product: "UMAXICA"),
              action: auth_com_sign_in_email_path,
              pt: pt,
              field_label: VisitorEmail.human_attribute_name(:address),
              submit_label: t("actions.submit"),
              back_link: { label: t("sign.app.authentication.new.back"), href: auth_com_sign_in_path(pt: pt) },
              turnstile: turnstile_visible_props,
            }
          end

          def sign_in_email_edit_props
            pt = signed_pt_param

            {
              title: t("sign.app.authentication.email.edit.page_title"),
              description: t("sign.app.authentication.email.edit.description"),
              action: auth_com_sign_in_email_path,
              pt: pt,
              field_label: t("sign.app.authentication.email.edit.code_label"),
              field_placeholder: t("sign.app.authentication.email.edit.code_placeholder"),
              submit_label: t("sign.app.authentication.email.edit.submit"),
              delivery_help: t("sign.app.authentication.email.edit.delivery_help"),
              return_link: { label: t("sign.app.authentication.email.edit.return_page"),
                             href: new_auth_com_sign_in_email_path(pt: pt), },
              resend: {
                endpoint: auth_com_web_v0_in_email_otp_path,
                state: @otp_resend_state.to_s,
                messages: {
                  button_label: t("otp.resend.button"),
                  sent_message: t("otp.resend.sent"),
                  too_soon_message: t("otp.resend.too_soon"),
                  failed_message: t("otp.resend.failed"),
                },
              },
              turnstile: turnstile_visible_props,
            }
          end

          def load_user_email
            if session[:user_email_authentication_id].present?
              @user_email = load_session_record(
                :user_email_authentication_id,
                VisitorEmail,
                check_otp_expiry: false,
                custom: ->(email) { email.present? && !email.otp_expired? },
              )

              unless @user_email
                redirect_to(new_auth_com_sign_in_email_path(pt: peek_pt, ri: current_region_identifier))
                return
              end
              @otp_resend_state = SignInOtpResendState.issue(kind: :email, target: @user_email.address)
            elsif session[:user_email_authentication_address].present?
              @user_email = VisitorEmail.new(address: session[:user_email_authentication_address])
              @otp_resend_state = SignInOtpResendState.issue(
                kind: :email,
                target: session[:user_email_authentication_address],
              )
            else
              redirect_to(new_auth_com_sign_in_email_path(pt: peek_pt, ri: current_region_identifier))
            end
          end

          # Slice before permitting, as the app surface does: `permit` on the whole
          # parameter set reports every unrelated key (`ri`, and anything else the
          # request carries) as unpermitted, which raises under the dev and test
          # setting for `action_on_unpermitted_parameters`.
          def update_pass_code_params
            permitted = params
              .slice(:visitor_email, :user_email)
              .permit(visitor_email: [:pass_code], user_email: [:pass_code])
            permitted.fetch(:visitor_email, {}).presence || permitted.fetch(:user_email, {}).presence || {}
          rescue ActionController::ParameterMissing
            {}
          end

          def process_email_authentication(normalized_address)
            existing_email = find_email_with_timing_protection(normalized_address)

            if existing_email&.visitor&.login_allowed?
              visitor = existing_email.visitor
              if session_limit_hard_reject_for?(visitor)
                @session_limit_hard_reject = true
                return
              end

              session[:user_email_authentication_id] = existing_email.id
              session[:user_email_authentication_address] = nil

              return :ok if existing_email.locked?
              return :cooldown if otp_request_rate_limited?(existing_email)

              otp_code = generate_otp_for(existing_email)

              OtpAdapter.for(surface: :com, channel: :email).deliver(
                record: existing_email,
                otp_code: otp_code,
              )
            else
              perform_dummy_otp_generation

              session[:user_email_authentication_id] = nil
              session[:user_email_authentication_address] = normalized_address
            end

            :ok
          end

          def otp_request_rate_limited?(user_email)
            user_email.otp_cooldown_active?
          end

          def sign_in_email_cooldown_active?(normalized_address)
            return false if session[:sign_in_email_cooldown_address] != normalized_address

            last_sent_at = session[:sign_in_email_cooldown_at]
            return false if last_sent_at.blank?

            last_sent_at.to_i > CommonOtpPolicy::SEND_COOLDOWN.ago.to_i
          end

          def record_sign_in_email_cooldown!(normalized_address)
            session[:sign_in_email_cooldown_address] = normalized_address
            session[:sign_in_email_cooldown_at] = Time.current.to_i
          end
        end
      end
    end
  end
end

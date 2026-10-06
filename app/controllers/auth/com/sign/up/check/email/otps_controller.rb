# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module Up
        module Check
          module Email
            class OtpsController < ::Auth::Com::Sign::Up::EmailsController
              include SignUpExplicitStepControllerSupport
              include SignUpContactOtpControllerSupport

              AUTHENTICATION_MODE = :guest
              skip_before_action :enforce_email_flow!

              def show
                return unless load_gate_context!(gate_for_show)

                @user_email = current_registration_email
                return redirect_invalid_session unless valid_email_session?

                render_sign_up_email_edit
              end

              def create
                return unless load_gate_context!(gate_for_create)

                @user_email = current_registration_email
                return redirect_invalid_session unless @user_email

                result = issue_otp_ceremony!
                return render_otp_ceremony_result(result) unless result.success?

                redirect_to(
                  auth_com_sign_up_check_email_otp_path(
                    **sign_up_flow_binding_params, ri: params[:ri],
                                                   pt: signed_pt_param,
                  ),
                )
              end

              def update
                return unless load_gate_context!(gate_for_update)

                @user_email = current_registration_email
                return redirect_invalid_session unless valid_email_session?
                return unless verify_otp_turnstile!

                submitted_code = submitted_pass_code
                return render_code_required if submitted_code.blank?

                result = verify_otp_ceremony!(submitted_code)
                return handle_locked_result if result.status == :locked
                return render_otp_ceremony_result(result) unless result.success?

                @user_email.update!(visitor_email_status_id: VisitorEmailStatus::VERIFIED_WITH_SIGN_UP)
                progress_email_flow!(:update)

                flow_result = advance_sign_up_after_contact_otp!
                return render_sign_up_result(flow_result) unless flow_result.success?
                return finalize_sign_up_from_checkpoint! if flow_result.next_event == :finalize

                complete_update_and_redirect
              end

              def destroy
                cancel_from_explicit_step
              end

              private

              def sign_up_surface = :com

              def sign_up_ticket_class = VisitorSignUpFlow

              def sign_up_sequence_session_key = :auth_com_up_sequence_id

              def sign_up_family = "email"

              def sign_up_step = :otp

              def verify_otp_turnstile!
                return true if cloudflare_turnstile_validation["success"]

                @user_email.errors.add(
                  :base,
                  t("sign.com.registration.email.create.turnstile_validation_failed"),
                )
                render_sign_up_email_edit(status: :unprocessable_content)
                false
              end

              def issue_otp_ceremony!
                SignOtpCeremony.issue!(
                  purpose: :sign_up,
                  surface: :com,
                  channel: :email,
                  subject: @sign_up_ticket,
                  destination: @user_email.address,
                  session_nonce: @sign_up_ticket.public_id,
                  request_context: request,
                )
              end

              def verify_otp_ceremony!(submitted_code)
                SignOtpCeremony.verify!(
                  purpose: :sign_up,
                  surface: :com,
                  channel: :email,
                  subject: @sign_up_ticket,
                  destination: @user_email.address,
                  code: submitted_code,
                  session_nonce: @sign_up_ticket.public_id,
                  request_context: request,
                )
              end

              def submitted_pass_code
                params.dig("visitor_email", "pass_code").presence ||
                  params.dig("user_email", "pass_code").presence
              end

              def render_code_required
                @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.code_required"))
                render_sign_up_email_edit(status: :unprocessable_content)
              end

              def handle_locked_result
                reset_email_flow!
                @user_email.errors.add(:base, t("sign.app.registration.email.update.attempts_exceeded"))
                render_sign_up_email_edit(status: :too_many_requests)
              end

              def complete_update_and_redirect
                redirect_to(
                  auth_com_sign_up_check_email_birthdate_path(
                    **sign_up_flow_binding_params, ri: params[:ri],
                                                   pt: signed_pt_param,
                  ),
                )
              end

              def render_otp_ceremony_result(result)
                if result.status == :rate_limited
                  @user_email.errors.add(:base, t("sign.app.registration.email.create.otp_resend_too_soon"))
                  return render_sign_up_email_edit(status: :too_many_requests)
                end

                @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.invalid_code"))
                render_sign_up_email_edit(status: :unprocessable_content)
              end

              def redirect_invalid_session
                reset_email_flow!
                @user_email ||= VisitorEmail.new
                @user_email.errors.add(:base, t("sign.app.registration.email.edit.session_expired"))
                render_sign_up_email_edit(status: :unprocessable_content)
              end
            end
          end
        end
      end
    end
  end
end

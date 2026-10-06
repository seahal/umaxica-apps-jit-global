# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module Up
        module Check
          module Telephone
            class OtpsController < ::Auth::App::Sign::Up::TelephonesController
              include SignUpExplicitStepControllerSupport
              include SignUpContactOtpControllerSupport

              AUTHENTICATION_MODE = :guest

              def show
                return unless load_gate_context!(gate_for_show)

                @user_telephone = current_registration_telephone
                return redirect_telephone_session_expired unless valid_telephone_session?

                render_sign_up_telephone_edit
              end

              def create
                return unless load_gate_context!(gate_for_create)

                @user_telephone = current_registration_telephone
                return redirect_telephone_session_expired unless @user_telephone
                return render_otp_resend_too_soon if otp_resend_rate_limited?

                result = issue_otp_ceremony!
                return render_otp_ceremony_result(result) unless result.success?

                registration = (session[:user_telephone_registration] || {}).dup
                registration["public_id"] ||= @user_telephone.public_id
                registration["expires_at"] = @user_telephone.reload.otp_expires_at.to_i
                session[:user_telephone_registration] = registration
                session[:user_telephone_otp_last_sent_at] = Time.current.to_i
                redirect_to(
                  auth_app_sign_up_check_telephone_otp_path(
                    **sign_up_flow_binding_params, ri: params[:ri],
                                                   pt: signed_pt_param,
                  ),
                )
              end

              def update
                return unless load_gate_context!(gate_for_update)

                @user_telephone = current_registration_telephone
                return redirect_telephone_session_expired unless valid_telephone_session?

                submitted_code = submitted_pass_code
                return render_code_required if submitted_code.blank?

                result = verify_otp_ceremony!(submitted_code)
                return handle_locked_result if result.status == :locked
                return render_otp_ceremony_result(result) unless result.success?

                verify_telephone_ownership!

                flow_result = advance_sign_up_after_contact_otp!
                return render_sign_up_result(flow_result) unless flow_result.success?
                return finalize_sign_up_from_checkpoint! if flow_result.next_event == :finalize

                complete_update_and_redirect
              end

              def destroy
                cancel_from_explicit_step
              end

              private

              def sign_up_surface = :app

              def sign_up_ticket_class = ClientSignUpFlow

              def sign_up_sequence_session_key = :auth_app_up_sequence_id

              def sign_up_family = "telephone"

              def sign_up_step = :otp

              def issue_otp_ceremony!
                SignOtpCeremony.issue!(
                  purpose: :sign_up,
                  surface: :app,
                  channel: :telephone,
                  subject: @sign_up_ticket,
                  destination: @user_telephone.number,
                  session_nonce: @sign_up_ticket.public_id,
                  request_context: request,
                )
              end

              def verify_otp_ceremony!(submitted_code)
                SignOtpCeremony.verify!(
                  purpose: :sign_up,
                  surface: :app,
                  channel: :telephone,
                  subject: @sign_up_ticket,
                  destination: @user_telephone.number,
                  code: submitted_code,
                  session_nonce: @sign_up_ticket.public_id,
                  request_context: request,
                )
              end

              def verify_telephone_ownership!
                registration = (session[:user_telephone_registration] || {}).dup
                registration["public_id"] ||= @user_telephone.public_id
                registration["otp_verified"] = true
                session[:user_telephone_registration] = registration
              end

              def render_otp_ceremony_result(result)
                if result.status == :rate_limited
                  @user_telephone.errors.add(:base, t("sign.app.registration.email.create.otp_resend_too_soon"))
                  return render_sign_up_telephone_edit(status: :too_many_requests)
                end

                @user_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.invalid_code"))
                render_sign_up_telephone_edit(status: :unprocessable_content)
              end

              def render_code_required
                @user_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.code_required"))
                render_sign_up_telephone_edit(status: :unprocessable_content)
              end

              def handle_locked_result
                reset_telephone_flow!
                @user_telephone.errors.add(:base, t("sign.app.registration.telephone.update.attempts_exceeded"))
                render_sign_up_telephone_edit(status: :too_many_requests)
              end

              def complete_update_and_redirect
                redirect_to(auth_app_sign_up_guard_telephone_path(ri: params[:ri], pt: signed_pt_param))
              end

              def submitted_pass_code
                params.dig("client_telephone", "pass_code").presence ||
                  params.dig("user_telephone", "pass_code").presence
              end

              def reset_telephone_flow!
                session[:user_telephone_registration] = nil
                sign_up_flow_locator.clear!
              end

              def redirect_telephone_session_expired
                reset_telephone_flow!
                redirect_to(
                  new_auth_app_sign_up_telephone_path(ri: params[:ri]),
                )
              end
            end
          end
        end
      end
    end
  end
end

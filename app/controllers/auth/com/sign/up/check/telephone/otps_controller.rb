# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module Up
        module Check
          module Telephone
            class OtpsController < ::Auth::Com::Sign::Up::TelephonesController
              include SignUpExplicitStepControllerSupport
              include SignUpContactOtpControllerSupport

              AUTHENTICATION_MODE = :guest

              def show
                return unless load_gate_context!(gate_for_show)

                @visitor_telephone = current_registration_telephone
                return render_telephone_session_expired unless valid_telephone_session?

                render_sign_up_telephone_edit
              end

              def create
                return unless load_gate_context!(gate_for_create)

                @visitor_telephone = current_registration_telephone
                return render_telephone_session_expired unless @visitor_telephone
                return render_otp_resend_too_soon if otp_resend_rate_limited?

                result = issue_otp_ceremony!
                return render_otp_ceremony_result(result) unless result.success?

                registration = (session[:visitor_telephone_registration] || {}).dup
                registration["public_id"] ||= @visitor_telephone.public_id
                registration["expires_at"] = @visitor_telephone.reload.otp_expires_at.to_i
                session[:visitor_telephone_registration] = registration
                session[:visitor_telephone_otp_last_sent_at] = Time.current.to_i
                redirect_to(
                  auth_com_sign_up_check_telephone_otp_path(
                    **sign_up_flow_binding_params, ri: params[:ri],
                                                   pt: signed_pt_param,
                  ),
                )
              end

              def update
                return unless load_gate_context!(gate_for_update)

                @visitor_telephone = current_registration_telephone
                return render_telephone_session_expired unless valid_telephone_session?

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

              def sign_up_surface = :com

              def sign_up_ticket_class = VisitorSignUpFlow

              def sign_up_sequence_session_key = :auth_com_up_sequence_id

              def sign_up_family = "telephone"

              def sign_up_step = :otp

              def issue_otp_ceremony!
                SignOtpCeremony.issue!(
                  purpose: :sign_up,
                  surface: :com,
                  channel: :telephone,
                  subject: @sign_up_ticket,
                  destination: @visitor_telephone.number,
                  session_nonce: @sign_up_ticket.public_id,
                  request_context: request,
                )
              end

              def verify_otp_ceremony!(submitted_code)
                SignOtpCeremony.verify!(
                  purpose: :sign_up,
                  surface: :com,
                  channel: :telephone,
                  subject: @sign_up_ticket,
                  destination: @visitor_telephone.number,
                  code: submitted_code,
                  session_nonce: @sign_up_ticket.public_id,
                  request_context: request,
                )
              end

              # The telephone row stays UNVERIFIED_WITH_SIGN_UP until the
              # finalizer promotes it; ownership for the remaining checkpoint
              # steps is carried in the session, which
              # `validate_sign_up_checkpoint_contact!` reads before the passkey
              # and passcode steps.
              def verify_telephone_ownership!
                registration = (session[:visitor_telephone_registration] || {}).dup
                registration["public_id"] ||= @visitor_telephone.public_id
                registration["otp_verified"] = true
                session[:visitor_telephone_registration] = registration
              end

              def submitted_pass_code
                params.dig("visitor_telephone", "pass_code").presence ||
                  params.dig("user_telephone", "pass_code").presence
              end

              def render_code_required
                @visitor_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.code_required"))
                render_sign_up_telephone_edit(status: :unprocessable_content)
              end

              def handle_locked_result
                reset_telephone_flow!
                @visitor_telephone.errors.add(:base, t("sign.app.registration.telephone.update.attempts_exceeded"))
                render_sign_up_telephone_edit(status: :too_many_requests)
              end

              def reset_telephone_flow!
                session[:visitor_telephone_registration] = nil
                sign_up_flow_locator.clear!
              end

              def complete_update_and_redirect
                redirect_to(auth_com_sign_up_guard_telephone_path(ri: params[:ri], pt: signed_pt_param))
              end

              def render_otp_ceremony_result(result)
                if result.status == :rate_limited
                  @visitor_telephone.errors.add(:base, t("sign.app.registration.email.create.otp_resend_too_soon"))
                  return render_sign_up_telephone_edit(status: :too_many_requests)
                end

                @visitor_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.invalid_code"))
                render_sign_up_telephone_edit(status: :unprocessable_content)
              end

              def render_telephone_session_expired
                @visitor_telephone ||= VisitorTelephone.new
                @visitor_telephone.errors.add(:base, t("sign.com.registration.telephone.edit.session_expired"))
                render_sign_up_telephone_edit(status: :unprocessable_content)
              end

              def otp_resend_rate_limited?
                last_sent_at = session[:visitor_telephone_otp_last_sent_at]
                return false if last_sent_at.blank?

                last_sent_at.to_i > CommonOtpPolicy::SEND_COOLDOWN.ago.to_i
              end
            end
          end
        end
      end
    end
  end
end

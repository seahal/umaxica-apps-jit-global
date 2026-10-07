# typed: false
# frozen_string_literal: true

# Routes OTP email through a Noticed notifier while the migration is in progress.
#
# This exists only so the ~20 call sites that already go through OtpAdapter.for
# need no change while the rollout flag is flipped surface by surface. It is
# deleted together with OtpEmailAdapter and OtpEmailNotifierRollout once the call
# sites address Notify::<Surface>::OtpNotifier directly.
class OtpEmailNotifierAdapter < OtpAdapter
  def initialize(notifier, surface: nil)
    super()
    @notifier = notifier
    @surface = surface
  end

  def deliver(record:, otp_code:, verification_token: nil, public_id: nil, purpose: nil,
              auth_ceremony_session_ref: nil, auth_email_otp_generation: nil,
              sign_up_flow_ref: nil, sign_up_otp_counter: nil,
              contact_ceremony_transaction_ref: nil, contact_otp_counter: nil, **)
    binding = AuthEmailOtpDeliveryBindingValue.for(
      purpose: purpose, auth_ceremony_session_ref: auth_ceremony_session_ref,
      auth_email_otp_generation: auth_email_otp_generation,
    )
    signup_binding = SignUpOtpDeliveryBindingValue.for_email(
      purpose: purpose, surface: @surface, sign_up_flow_ref: sign_up_flow_ref,
      public_id: public_id, sign_up_otp_counter: sign_up_otp_counter,
    )
    registration_binding = ContactRegistrationOtpDeliveryBindingValue.for_email(
      purpose: purpose.to_s, surface: @surface.to_s,
      contact_ceremony_transaction_ref: contact_ceremony_transaction_ref,
      public_id: public_id, contact_otp_counter: contact_otp_counter,
    )
    notifier_params = {
      record: record,
      otp_code: otp_code,
      verification_token: verification_token,
      public_id: public_id,
    }
    notifier_params[:purpose] = purpose if purpose.present?
    notifier_params.merge!(binding.to_h) if binding
    notifier_params.merge!(signup_binding.email_params) if signup_binding
    notifier_params.merge!(registration_binding.email_params) if registration_binding
    begin
      @notifier.issue(**notifier_params)
    rescue StandardError => e
      record_email_enqueue_failure!(record: record, purpose: purpose, error: e)
      raise
    end

    record_email_enqueue!(record: record, purpose: purpose)
  end
end

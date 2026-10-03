# frozen_string_literal: true

# Concrete notifiers provide step_up_email_model. Only ciphertext and the canonical code
# generation enter Noticed params; recipient addresses are resolved at delivery time.
module Notify::StepUpOtpIssuanceNotifier
  public

  def issue(record:, otp_code:, transaction_ref:, generation:)
    unless record.is_a?(step_up_email_model) && otp_code.is_a?(String) && otp_code.match?(/\A[0-9]{6}\z/) &&
        transaction_ref.is_a?(String) && transaction_ref.present? && generation.is_a?(Integer) && generation.positive?
      raise ArgumentError, "invalid step-up email delivery"
    end

    notifier = with(
      encrypted_hotp_token: OutboundSensitivePayload.encrypt_email_otp(otp_code),
      transaction_ref: transaction_ref, generation: generation,
    )
    # Ephemeral#deliver drops the return value of perform_later. Inspect that same Noticed
    # entry point so an aborted enqueue cannot be reported as successful issuance.
    job = notifier.delivery_methods.fetch(:email).ephemeral_perform_later(name, record, notifier.params)
    raise ActiveJob::EnqueueError, "step-up email enqueue rejected" unless job

    notifier
  end
end

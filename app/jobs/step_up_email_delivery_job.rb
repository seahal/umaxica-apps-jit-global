# frozen_string_literal: true

class StepUpEmailDeliveryJob < Noticed::DeliveryMethod
  self.log_arguments = false

  public

  def deliver
    event.deliver_step_up_email!(
      recipient: recipient, transaction_ref: params.fetch(:transaction_ref),
      generation: params.fetch(:generation), encrypted_code: params.fetch(:encrypted_hotp_token),
    )
  end
end

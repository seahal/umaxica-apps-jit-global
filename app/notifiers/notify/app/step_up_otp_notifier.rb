# frozen_string_literal: true

class Notify::App::StepUpOtpNotifier < Notify::ApplicationNotifier
  extend Notify::StepUpOtpIssuanceNotifier

  deliver_by :email, class: "StepUpEmailDeliveryJob"

  public

  def deliver_step_up_email!(recipient:, **arguments)
    raise ArgumentError, "APP email recipient required" unless recipient.is_a?(ClientEmail)

    IdentityStepUpEmailDeliveryRecorder.call!(credential: recipient, **arguments)
  end

  def self.step_up_email_model = ClientEmail
  private_class_method :step_up_email_model
end

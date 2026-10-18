# frozen_string_literal: true

class Notify::Com::StepUpOtpNotifier < Notify::ApplicationNotifier
  extend Notify::StepUpOtpIssuanceNotifier

  deliver_by :email, class: "StepUpEmailDeliveryJob"

  public

  def deliver_step_up_email!(recipient:, **arguments)
    raise ArgumentError, "COM email recipient required" unless recipient.is_a?(VisitorEmail)

    IdentityStepUpEmailDeliveryRecorder.call!(credential: recipient, **arguments)
  end

  def self.step_up_email_model = VisitorEmail
  private_class_method :step_up_email_model
end

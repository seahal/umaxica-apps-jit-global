# frozen_string_literal: true

class OtpMailDeliveryJob < ActionMailer::MailDeliveryJob
  self.log_arguments = false
end

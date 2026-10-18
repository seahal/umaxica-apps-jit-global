# frozen_string_literal: true

class OtpNotifierEmailDeliveryJob < Noticed::DeliveryMethods::Email
  self.log_arguments = false
end

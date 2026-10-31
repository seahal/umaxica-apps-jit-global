# frozen_string_literal: true

require "timeout"
require "net/protocol"

# Bound only the SMTP connection itself: interceptors and delivery guards run outside this timer.
class OtpSmtpDelivery < Mail::SMTP
  TRANSPORT_TIMEOUT = 15

  class << self
    public

    def wrap!(message)
      transport = message.delivery_method
      return message unless transport.instance_of?(Mail::SMTP)

      message.delivery_method(self, transport.settings.merge(otp_transport_timeout: TRANSPORT_TIMEOUT))
      message
    end
  end

  def initialize(values)
    @transport_timeout = values.fetch(:otp_transport_timeout)
    unless @transport_timeout.is_a?(Numeric) && @transport_timeout.finite? && @transport_timeout.positive?
      raise ArgumentError, "OTP SMTP timeout must be a finite positive number"
    end

    super(values.except(:otp_transport_timeout))
  end

  public

  def deliver!(message)
    Timeout.timeout(@transport_timeout, Net::ReadTimeout) { super }
  end
end

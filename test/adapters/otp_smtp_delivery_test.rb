# frozen_string_literal: true

require "test_helper"
require "socket"

class OtpSmtpDeliveryTest < ActiveSupport::TestCase
  test "SMTP transport stops waiting at its total deadline" do
    server = TCPServer.new("127.0.0.1", 0)
    finished = Queue.new
    peer =
      Thread.new do
        socket = server.accept
        finished.pop
      ensure
        socket&.close
      end
    mail = Mail.new(from: "sender@example.test", to: "recipient@example.test", subject: "test", body: "test")
    delivery = OtpSmtpDelivery.new(
      address: "127.0.0.1", port: server.addr[1], enable_starttls: false,
      open_timeout: 1, read_timeout: 1, otp_transport_timeout: 0.05,
    )

    assert_raises(Net::ReadTimeout) { delivery.deliver!(mail) }
  ensure
    finished << true if finished
    server&.close
    peer&.join(2)
  end

  test "wrapping SMTP preserves its settings and leaves other delivery methods intact" do
    smtp_message = Mail.new
    smtp_message.delivery_method(:smtp, address: "127.0.0.1", port: 2525, open_timeout: 4)
    OtpSmtpDelivery.wrap!(smtp_message)

    assert_instance_of OtpSmtpDelivery, smtp_message.delivery_method
    assert_equal 2525, smtp_message.delivery_method.settings.fetch(:port)
    assert_equal 4, smtp_message.delivery_method.settings.fetch(:open_timeout)

    test_message = Mail.new
    test_message.delivery_method(:test)
    original = test_message.delivery_method
    OtpSmtpDelivery.wrap!(test_message)

    assert_same original, test_message.delivery_method
  end
end

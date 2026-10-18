# frozen_string_literal: true

require "net/http"
require_relative "../../test/support/outbound_http_guard"

# No provider simulation: an attempted outbound request is an explicit error.
module RailsE2eHttpDenyTransport
  private

  # Net::HTTP.get/start opens the socket before request(), so deny at connection time.
  def connect
    raise TestSupport::ExternalCommunicationError, "Rails browser E2E forbids outbound Net::HTTP"
  end
end

Net::HTTP.prepend(RailsE2eHttpDenyTransport)

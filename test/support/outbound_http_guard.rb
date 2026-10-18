# frozen_string_literal: true

require "concurrent"
require "faraday"

module TestSupport
  class ExternalCommunicationError < StandardError; end

  module OutboundHttpGuard
    ALLOWED = Concurrent::AtomicReference.new(false)

    module_function

    def allowed?
      ALLOWED.value
    end

    def allow
      previous = ALLOWED.value
      ALLOWED.value = true
      yield
    ensure
      ALLOWED.value = previous
    end
  end
end

module TestSupport::OutboundHttpDenyTransport
  def run_request(...)
    unless TestSupport::OutboundHttpGuard.allowed?
      raise TestSupport::ExternalCommunicationError,
            "outbound HTTP is not stubbed in the test environment"
    end

    super
  end
end

Faraday::Connection.prepend(TestSupport::OutboundHttpDenyTransport)

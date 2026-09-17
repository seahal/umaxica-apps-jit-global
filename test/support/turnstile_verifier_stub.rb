# frozen_string_literal: true

# Test substitute for the Turnstile verifier, injected through
# config.x.turnstile.verifier (see test/test_helper.rb). It keeps the ability to bypass a
# third-party challenge inside the test suite instead of in application code.
#
# Two independent slots preserve the reach the previous in-application overrides had:
#
# - `challenge_enabled` / `challenge_response` apply to `verify`, which is what the
#   CloudflareTurnstile concern calls. The response is only used while enabled, matching
#   the override this replaced.
# - `enabled` / `response` apply to every call, including the `verify_for_ceremony` path
#   used by the social sign-up confirmation controllers. A set response applies on its own.
#
# Anything not stubbed fails closed. Tests that exercise the real verifier must use an explicit
# Faraday test adapter (see `OutboundHttpStub`) or stub the connection builder themselves.
class TurnstileVerifierStub
  CHALLENGE_ENABLED = Concurrent::AtomicReference.new(false)
  CHALLENGE_RESPONSE = Concurrent::AtomicReference.new
  ENABLED = Concurrent::AtomicReference.new(false)
  RESPONSE = Concurrent::AtomicReference.new

  class << self
    def challenge_enabled
      CHALLENGE_ENABLED.value
    end

    def challenge_enabled=(value)
      CHALLENGE_ENABLED.value = value
    end

    def challenge_response
      CHALLENGE_RESPONSE.value
    end

    def challenge_response=(value)
      CHALLENGE_RESPONSE.value = value
    end

    def enabled
      ENABLED.value
    end

    def enabled=(value)
      ENABLED.value = value
    end

    def response
      RESPONSE.value
    end

    def response=(value)
      RESPONSE.value = value
    end

    def reset!
      self.challenge_enabled = false
      self.challenge_response = nil
      self.enabled = false
      self.response = nil
    end

    def verify(**_arguments)
      # The challenge slot wins: it is the narrower of the two, and the override it
      # replaced was consulted before the verifier-level one.
      challenge_stubbed_response || stubbed_response || unstubbed_failure
    end

    def verify_for_ceremony(**_arguments)
      stubbed_response || unstubbed_failure
    end

    private

    def stubbed_response
      response.presence || (enabled ? { "success" => true } : nil)
    end

    def challenge_stubbed_response
      return nil unless challenge_enabled

      challenge_response.presence || { "success" => true }
    end

    def unstubbed_failure
      raise TestSupport::ExternalCommunicationError,
            "Turnstile verification is not stubbed in the test environment"
    end
  end
end

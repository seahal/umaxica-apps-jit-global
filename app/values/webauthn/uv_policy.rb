# typed: false
# frozen_string_literal: true

module Webauthn
  # Closed enumeration of the user-verification policy per ceremony purpose.
  # Every purpose currently resolves to "required": each ceremony must be
  # usable on the AAL2-aligned path, and a UV=false response is rejected
  # server-side regardless of what the client requested.
  #
  # The purposes are kept distinct so that a future decision can relax exactly
  # one of them (e.g. ordinary_step_up) without touching the others. Call sites
  # must go through this registry - passing a raw user-verification string to
  # the verifiers is forbidden (test/unit/security/webauthn_invariants_test.rb).
  class UvPolicy
    class UnknownPurposeError < StandardError; end

    REQUIRED = "required"

    attr_reader :purpose, :client_value

    def initialize(purpose, client_value:)
      @purpose = purpose
      @client_value = client_value
      freeze
    end

    # A required policy is enforced server-side too: the verifier passes
    # user_verification: true to the gem and re-checks the UV flag itself.
    def enforce_server_side? = client_value == REQUIRED

    REGISTRY = {
      registration: new(:registration, client_value: REQUIRED),
      direct_sign_in: new(:direct_sign_in, client_value: REQUIRED),
      emergency_sign_in: new(:emergency_sign_in, client_value: REQUIRED),
      mfa_challenge: new(:mfa_challenge, client_value: REQUIRED),
      ordinary_step_up: new(:ordinary_step_up, client_value: REQUIRED),
      high_risk_step_up: new(:high_risk_step_up, client_value: REQUIRED),
    }.freeze

    def self.for(purpose)
      return purpose if purpose.is_a?(UvPolicy)

      REGISTRY.fetch(purpose.to_sym) do
        raise UnknownPurposeError,
              "Unknown UV policy purpose: #{purpose.inspect} (expected one of #{REGISTRY.keys.inspect})"
      end
    end

    def self.all = REGISTRY.values
  end
end

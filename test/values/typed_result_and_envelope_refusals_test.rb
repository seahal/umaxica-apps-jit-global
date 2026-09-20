# typed: false
# frozen_string_literal: true

require "test_helper"

# Typed results and encrypted envelopes that refuse a shape they cannot be
# trusted to mean. Each construction guard exists so that a caller cannot build a
# result that claims success while carrying a failure, or decrypt a payload whose
# fields no longer match what the producer promised.
class TypedResultAndEnvelopeRefusalsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def principal
    ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "sub-1",
      issuer: "https://accounts.google.com",
      audience: "client-1",
      verified_at: Time.current,
      verification_authority: "id_token",
    )
  end

  test "a verified callback result cannot be built without a principal or while carrying a failure" do
    assert ExternalAuthentication::CallbackResult.verified(principal: principal)

    assert_raises(ArgumentError) do
      ExternalAuthentication::CallbackResult.new(
        status: :verified, principal: nil, credential_candidate: nil, failure: nil,
      )
    end

    assert_raises(ArgumentError) do
      ExternalAuthentication::CallbackResult.new(
        status: :verified, principal: principal, credential_candidate: nil,
        failure: ExternalAuthentication::Failure.new(
          code: :verification_failed, provider: "google", retryable: false, safe_reason: :assertion_invalid,
        ),
      )
    end
  end

  test "a failed callback result cannot carry a principal or an untyped failure" do
    assert_raises(ArgumentError) do
      ExternalAuthentication::CallbackResult.new(
        status: :failed, principal: principal, credential_candidate: nil, failure: nil,
      )
    end

    assert_raises(ArgumentError) do
      ExternalAuthentication::CallbackResult.new(
        status: :failed, principal: nil, credential_candidate: nil, failure: "denied",
      )
    end
  end

  test "a status the result type does not define is refused" do
    assert_raises(ArgumentError) do
      ExternalAuthentication::CallbackResult.new(
        status: :maybe, principal: nil, credential_candidate: nil, failure: nil,
      )
    end
  end

  # An envelope whose fields do not match what the producer promised is refused
  # rather than partially read, and a token that is not an envelope at all is
  # refused as invalid rather than surfacing a JSON error.
  test "an envelope with the wrong schema or an unreadable token is refused" do
    keys = %w(version subject body)

    assert_raises(ArgumentError) do
      OutboundSensitivePayload.validate_envelope!({ "version" => 1, "subject" => "s" }, required_keys: keys)
    end

    assert_raises(ArgumentError) do
      OutboundSensitivePayload.validate_envelope!("not a hash", required_keys: keys)
    end
  end

  # The port declares the two decisions a provider availability adapter has to
  # answer. An adapter that inherits without implementing them must fail loudly
  # rather than silently allowing the ceremony.
  test "the availability port refuses to answer either decision itself" do
    adapter = Class.new { include ExternalAuthentication::ProviderAvailabilityPort }.new

    assert_raises(NotImplementedError) do
      adapter.start_decision(provider: "entra", operation: "login", context: {})
    end
    assert_raises(NotImplementedError) do
      adapter.callback_decision(provider: "entra", ceremony: nil, context: {})
    end
  end
end

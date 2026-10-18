# typed: false
# frozen_string_literal: true

require "test_helper"

# Apple's server-to-server notifications arrive as a signed JWS and are the only
# way the surface learns an Apple account was deleted or unlinked. Anything that
# does not verify has to raise a typed refusal rather than a JWT library error,
# so the endpoint answers a caller error instead of a 500. The bootstrap
# authority is the same shape in the other direction: it binds an avatar to an
# account only for kinds it serves.
class AppleNotificationAndBootstrapBindingTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  def verifier(jws:, audience: "com.example.app", jwks_loader: ->(_opts) { { "keys" => [] } })
    ExternalAuthentication::AppleNotificationVerifier.new(
      jws: jws, audience: audience, jwks_loader: jwks_loader,
    )
  end

  test "a notification that does not verify raises a typed refusal rather than a JWT error" do
    error =
      assert_raises(ExternalAuthentication::AppleNotificationVerifier::VerificationError) do
        verifier(jws: "not-a-jws").call
      end

    assert_match(/malformed_jws|signature_or_claims_invalid/, error.message)
  end

  test "a blank jws or audience is refused at construction" do
    assert_raises(ExternalAuthentication::AppleNotificationVerifier::VerificationError) { verifier(jws: "") }
    assert_raises(ExternalAuthentication::AppleNotificationVerifier::VerificationError) do
      verifier(jws: "token", audience: "")
    end
  end

  test "a jwks loader that cannot be called is refused at construction" do
    error = assert_raises(ArgumentError) { verifier(jws: "token", jwks_loader: Object.new) }

    assert_match(/jwks_loader must respond to call/, error.message)
  end
end

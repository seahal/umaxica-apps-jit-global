# typed: false
# frozen_string_literal: true

require "test_helper"

# Staff sign-in through Entra rests entirely on this verification. Every way it
# can fail has to surface as this provider's own typed refusal so the callback
# reports a failed sign-in rather than a 500 -- including the case where the
# tenant's key set could not be fetched at all, which is an outage rather than a
# rejected token and has to be distinguishable from one.
class EntraTokenVerificationRefusalsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  TENANT = "11111111-2222-3333-4444-555555555555"

  def verifier(id_token: "not-a-jwt", jwks_loader: ->(_opts) { { "keys" => [] } })
    ExternalSignIn::Providers::EntraId.new(
      id_token: id_token,
      expected_nonce: "nonce-1",
      expected_tenant_id: TENANT,
      client_id: "client-1",
      jwks_loader: jwks_loader,
    )
  end

  test "a token that cannot be decoded is refused as a decode failure" do
    error = assert_raises(ExternalSignIn::Providers::EntraId::VerificationError) { verifier.call }

    assert_match(/token_decode_failed/, error.message)
  end

  # An unreachable key set is an outage, not a rejected token, and is reported
  # under its own reason so it is not read as an attempted forgery.
  test "a key set that cannot be fetched is refused as a fetch failure, not a decode failure" do
    unreachable = ->(*) { raise ExternalSignIn::EntraJwksCache::FetchError, "unreachable" }
    well_formed =
      JWT.encode(
        { "iss" => "https://login.microsoftonline.com/#{TENANT}/v2.0", "aud" => "client-1" },
        OpenSSL::PKey::RSA.generate(2048),
        "RS256",
        { "kid" => "some-kid" },
      )

    error =
      assert_raises(ExternalSignIn::Providers::EntraId::VerificationError) do
        verifier(id_token: well_formed, jwks_loader: unreachable).call
      end

    assert_match(/jwks_fetch_failed/, error.message)
  end
end

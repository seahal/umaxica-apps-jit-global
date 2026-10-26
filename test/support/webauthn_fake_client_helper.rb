# typed: false
# frozen_string_literal: true

require "webauthn/fake_client"

# Real-cryptography WebAuthn test harness. Builds attestation/assertion
# payloads with the gem's FakeClient so tests exercise the actual signature,
# RP ID, origin, and flag verification paths instead of stubbing #verify.
module WebauthnFakeClientHelper
  def webauthn_fake_client(origin: "https://auth.umaxica.app", authenticator: nil)
    authenticator ||= WebAuthn::FakeAuthenticator.new
    WebAuthn::FakeClient.new(origin, encoding: :base64url, authenticator: authenticator)
  end

  # The fake client's authenticator, for building a second client (e.g. a
  # rogue origin) that holds the same credentials.
  def webauthn_authenticator_of(client)
    client.send(:authenticator)
  end

  # Returns the raw params hash a browser would POST for a registration.
  def fake_attestation(client, challenge:, rp_id: nil, user_verified: true, user_present: true,
                       backup_eligibility: false, backup_state: false, extensions: nil)
    client.create(
      challenge: challenge,
      rp_id: rp_id,
      user_present: user_present,
      user_verified: user_verified,
      backup_eligibility: backup_eligibility,
      backup_state: backup_state,
      extensions: extensions,
    )
  end

  # Registers a credential on the fake client's authenticator and returns the
  # attributes a server-side passkey record stores for it.
  def fake_credential_record_attrs(client, user_verified: true)
    challenge = Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false)
    params = client.create(challenge: challenge, user_verified: user_verified)
    relying_party = WebAuthn::RelyingParty.new(
      id: URI.parse(client.origin).host,
      allowed_origins: [client.origin],
      encoding: :base64url,
    )
    credential = WebAuthn::Credential.from_create(params, relying_party: relying_party)

    { webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0 }
  end

  # Returns the raw params hash a browser would POST for an authentication.
  # sign_count defaults to a value above any freshly registered credential.
  def fake_assertion(client, challenge:, rp_id: nil, user_verified: true, user_present: true, sign_count: 1,
                     user_handle: nil)
    client.get(
      challenge: challenge,
      rp_id: rp_id,
      user_present: user_present,
      user_verified: user_verified,
      sign_count: sign_count,
      user_handle: user_handle,
    )
  end
end

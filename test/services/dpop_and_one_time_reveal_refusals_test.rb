# typed: false
# frozen_string_literal: true

require "test_helper"

# A DPoP proof binds a request to a key the caller holds. Anything it cannot make
# sense of has to be a plain refusal rather than an exception escaping into the
# request, and the request URI it is compared against has to be normalised the
# same way on both sides or a proof for the right request looks like one for the
# wrong request. One-time reveals fail the same way: an unreadable payload is
# nothing to reveal, not an error.
class DpopAndOneTimeRevealRefusalsTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  def verifier(proof_jwt:, request_uri: "https://id.example.test/oauth/token")
    DpopProofVerifier.new(
      proof_jwt: proof_jwt, request_method: "POST", request_uri: request_uri, record_jti: false,
    )
  end

  test "a proof that is missing, malformed or undecodable is refused rather than raised" do
    assert_equal "missing_proof", verifier(proof_jwt: "").call.error
    assert_equal "malformed_proof", verifier(proof_jwt: "not-a-jwt").call.error
  end

  test "a proof whose header decodes but whose key material is unusable is refused" do
    unusable = JWT.encode({ "jti" => SecureRandom.uuid, "htm" => "POST" }, nil, "none", { "jwk" => { "kty" => "EC" } })
    result = verifier(proof_jwt: unusable).call

    assert_not result.valid?
    assert_predicate result.error, :present?
  end

  # A reveal is single-use: consuming it twice, or with the wrong actor, nonce or
  # purpose, has to answer nothing rather than reveal the value again.
  test "a one-time reveal is consumable once and only by the actor it was issued to" do
    actor = clients(:one)
    token = IdentityOneTimeReveal.issue!(
      actor: actor, session_nonce: "nonce-1", value: %w(passcode-1), purpose: "client.recovery_secret_credential",
    ).token

    wrong_actor = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)

    assert_nil IdentityOneTimeReveal.consume!(
      actor: wrong_actor, session_nonce: "nonce-1", token: token, purpose: "client.recovery_secret_credential",
    )
    assert_nil IdentityOneTimeReveal.consume!(
      actor: actor, session_nonce: "another-nonce", token: token, purpose: "client.recovery_secret_credential",
    )
    assert_nil IdentityOneTimeReveal.consume!(
      actor: actor, session_nonce: "nonce-1", token: token, purpose: "client.some_other_purpose",
    )

    revealed = IdentityOneTimeReveal.consume!(
      actor: actor, session_nonce: "nonce-1", token: token, purpose: "client.recovery_secret_credential",
    )

    assert_equal %w(passcode-1), revealed.value
    assert_nil IdentityOneTimeReveal.consume!(
      actor: actor, session_nonce: "nonce-1", token: token, purpose: "client.recovery_secret_credential",
    ), "a reveal is single-use"
  end

  test "a token that was never issued reveals nothing rather than raising" do
    assert_nil IdentityOneTimeReveal.consume!(
      actor: clients(:one), session_nonce: "nonce-1", token: "not-a-token", purpose: "client.recovery",
    )
  end
end

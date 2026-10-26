# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageEasyWinsTest < ActiveSupport::TestCase
  test "ExternalAuthentication::LinkResult rejects unsupported status and missing peers" do
    assert_raises(ArgumentError) { ExternalAuthentication::LinkResult.new(status: :other, user: Object.new, identity: Object.new) }
    assert_raises(ArgumentError) { ExternalAuthentication::LinkResult.new(status: :linked, user: nil, identity: Object.new) }
    assert_raises(ArgumentError) { ExternalAuthentication::LinkResult.new(status: :linked, user: Object.new, identity: nil) }
    result = ExternalAuthentication::LinkResult.new(status: :linked, user: :u, identity: :i)

    assert_equal :linked, result.status
  end

  test "Webauthn::UvPolicy.for accepts an already constructed policy" do
    policy = Webauthn::UvPolicy::REGISTRY.fetch(:registration)

    assert_same policy, Webauthn::UvPolicy.for(policy)
  end

  test "DbscProofVerifier covers missing proof challenge and claim failure arms" do
    assert_equal "missing_proof",
                 DbscProofVerifier.call(proof: "", challenge: "c", challenge_issued_at: Time.current).error_code
    assert_equal "missing_challenge",
                 DbscProofVerifier.call(proof: "x.y.z", challenge: "", challenge_issued_at: Time.current).error_code
    assert_equal "challenge_expired",
                 DbscProofVerifier.call(proof: "x.y.z", challenge: "c", challenge_issued_at: 1.hour.ago).error_code

    key = OpenSSL::PKey::EC.generate("prime256v1")
    public_jwk = JWT::JWK.new(key).export
    now = Time.current
    proof = JWT.encode(
      { "jti" => "c", "aud" => "https://test.host/x", "iat" => now.to_i },
      key,
      "ES256",
      { typ: "wrong", jwk: public_jwk },
    )

    assert_equal "invalid_type",
                 DbscProofVerifier.call(proof: proof, challenge: "c", challenge_issued_at: now).error_code

    proof = JWT.encode(
      { "jti" => "c", "aud" => "", "iat" => now.to_i },
      key,
      "ES256",
      { typ: "dbsc+jwt", jwk: public_jwk },
    )

    assert_equal "missing_audience",
                 DbscProofVerifier.call(proof: proof, challenge: "c", challenge_issued_at: now).error_code

    proof = JWT.encode(
      { "jti" => "c", "aud" => "https://test.host/x", "iat" => now.to_i },
      key,
      "ES256",
      { typ: "dbsc+jwt", jwk: public_jwk },
    )

    assert_equal "audience_mismatch",
                 DbscProofVerifier.call(
                   proof: proof,
                   challenge: "c",
                   challenge_issued_at: now,
                   expected_audience: "https://other.host/x",
                 ).error_code

    proof = JWT.encode(
      { "jti" => "other", "aud" => "https://test.host/x", "iat" => now.to_i },
      key,
      "ES256",
      { typ: "dbsc+jwt", jwk: public_jwk },
    )

    assert_equal "challenge_mismatch",
                 DbscProofVerifier.call(proof: proof, challenge: "c", challenge_issued_at: now).error_code
  end
end

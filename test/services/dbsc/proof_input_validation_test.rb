# frozen_string_literal: true

require "minitest/autorun"
require "active_support/all"
require "active_support/testing/assertions"
require "jwt"
require "base64"
require_relative "../../../app/lib/dbsc_proof_verifier"

class DbscProofInputValidationTest < Minitest::Test
  include ActiveSupport::Testing::Assertions

  def test_rejects_missing_or_wrong_type_issued_at_without_time_conversion_errors
    Time.use_zone("UTC") do
      now = Time.current
      [nil, "", "123", [], {}, false].each do |issued_at|
        # The JWT encoder rejects malformed iat claims, so construct the attacker
        # envelope directly. This refusal precedes signature verification.
        header = Base64.urlsafe_encode64({ typ: "dbsc+jwt", alg: "ES256" }.to_json, padding: false)
        payload = Base64.urlsafe_encode64(
          { "jti" => "challenge", "aud" => "https://example.com/dbsc", "iat" => issued_at }.to_json, padding: false,
        )
        proof = "#{header}.#{payload}.invalid-signature"

        result = DbscProofVerifier.call(
          proof: proof, challenge: "challenge", challenge_issued_at: now, now: now,
          expected_audience: "https://example.com/dbsc",
        )

        assert_not result.ok
        assert_equal "missing_issued_at", result.error_code
      end
    end
  end

  def test_verifies_a_decoded_proof_with_the_real_signature_boundary
    Time.use_zone("UTC") do
      key = OpenSSL::PKey::EC.generate("prime256v1")
      now = Time.current
      proof = JWT.encode(
        { "jti" => "challenge", "aud" => "https://example.com/dbsc", "iat" => now.to_i },
        key, "ES256", { typ: "dbsc+jwt" },
      )
      verifier = DbscProofVerifier.new(
        proof: proof, challenge: "challenge", challenge_issued_at: now, now: now,
        expected_audience: "https://example.com/dbsc",
      )

      assert verifier.call.ok
      assert verifier.verify_signature(key, "ES256").ok
      assert_not verifier.verify_signature(OpenSSL::PKey::EC.generate("prime256v1"), "ES256").ok
    end
  end

  def test_rejects_a_missing_issued_at_claim
    now = Time.at(1_800_000_000).utc
    key = OpenSSL::PKey::EC.generate("prime256v1")
    proof = JWT.encode(
      { "jti" => "challenge", "aud" => "https://example.com/dbsc" },
      key, "ES256", { typ: "dbsc+jwt" },
    )

    result = DbscProofVerifier.call(
      proof: proof, challenge: "challenge", challenge_issued_at: now, now: now,
      expected_audience: "https://example.com/dbsc",
    )

    assert_equal "missing_issued_at", result.error_code
  end

  def test_checks_issued_at_boundaries_before_converting_untrusted_numeric_dates
    now = Time.at(1_800_000_000).utc
    key = OpenSSL::PKey::EC.generate("prime256v1")
    {
      -301 => "issued_at_expired",
      -300 => nil,
      -299 => nil,
      29 => nil,
      30 => nil,
      31 => "issued_at_future",
      1e300 => "issued_at_future",
      -1e300 => "issued_at_expired",
      0 => "issued_at_expired",
    }.each do |offset, error|
      issued_at = offset.zero? ? 0 : now.to_i + offset
      proof = JWT.encode(
        { "jti" => "challenge", "aud" => "https://example.com/dbsc", "iat" => issued_at },
        key, "ES256", { typ: "dbsc+jwt" },
      )

      result = DbscProofVerifier.call(
        proof: proof, challenge: "challenge", challenge_issued_at: now, now: now,
        expected_audience: "https://example.com/dbsc",
      )

      if error
        assert_equal error, result.error_code, offset.to_s
      else
        assert result.ok
      end
    end
  end
end

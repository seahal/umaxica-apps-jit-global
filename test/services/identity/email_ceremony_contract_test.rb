# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityEmailCeremonyContractTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @now = Time.zone.parse("2026-06-03 12:00:00")
  end

  teardown do
    travel_back
  end

  test "valid grant and result serialize and verify" do
    travel_to @now do
      grant_token = IdentityEmailCeremonyGrant.issue(valid_grant_claims, issuer_id: acme_issuer_id, now: @now)
      grant = IdentityEmailCeremonyGrant.decode(grant_token, issuer_id: acme_issuer_id, now: @now)

      assert_equal "email_ceremony", grant["purpose"]
      assert_equal IdentityEmailCeremonyContract.sign_audience("app"), grant["aud"]

      result_token = IdentityEmailCeremonyResult.issue(valid_result_claims, issuer_id: sign_issuer_id, now: @now)
      result = IdentityEmailCeremonyResult.decode(result_token, issuer_id: sign_issuer_id, now: @now)

      assert_equal "email_ceremony_result", result["purpose"]
      assert_equal "email_otp", result["proof_method"]
      assert_equal IdentityEmailCeremonyContract.acme_audience("app"), result["aud"]
    end
  end

  test "grant rejects binding, audience, purpose, surface, operation, expiry, and forbidden fields" do
    assert_email_ceremony_error("actor_ref") do
      IdentityEmailCeremonyGrant.new(valid_grant_claims.except("actor_ref"), now: @now)
    end
    assert_email_ceremony_error("aud is invalid") do
      IdentityEmailCeremonyGrant.new(valid_grant_claims.merge("aud" => "https://evil.example"), now: @now)
    end
    assert_email_ceremony_error("purpose is invalid") do
      IdentityEmailCeremonyGrant.new(valid_grant_claims.merge("purpose" => "wrong"), now: @now)
    end
    assert_email_ceremony_error("surface is invalid") do
      IdentityEmailCeremonyGrant.new(valid_grant_claims.merge("surface" => "bad"), now: @now)
    end
    assert_email_ceremony_error("operation is invalid") do
      IdentityEmailCeremonyGrant.new(valid_grant_claims.merge("operation" => "delete"), now: @now)
    end
    assert_email_ceremony_error("exp is expired") do
      IdentityEmailCeremonyGrant.new(valid_grant_claims.merge("exp" => (@now - 1.second).to_i), now: @now)
    end
    %w(otp otp_digest session_token refresh_token raw_address recent_auth sudo step_up_freshness).each do |claim|
      assert_email_ceremony_error("forbidden claims") do
        IdentityEmailCeremonyGrant.new(valid_grant_claims.merge(claim => "secret"), now: @now)
      end
    end
  end

  test "result rejects binding, proof, expiry, redirect, and forbidden fields" do
    assert_email_ceremony_error("grant_jti") do
      IdentityEmailCeremonyResult.new(valid_result_claims.except("grant_jti"), now: @now)
    end
    assert_email_ceremony_error("proof_method is invalid") do
      IdentityEmailCeremonyResult.new(valid_result_claims.merge("proof_method" => "sms_otp"), now: @now)
    end
    assert_email_ceremony_error("expires_at is expired") do
      IdentityEmailCeremonyResult.new(
        valid_result_claims.merge("expires_at" => (@now - 1.second).to_i),
        now: @now,
      )
    end
    assert_email_ceremony_error("unknown claims") do
      IdentityEmailCeremonyResult.new(valid_result_claims.merge("return_to" => "/settings/emails"), now: @now)
    end
    %w(otp otp_digest session_token refresh_token email_address recent_auth sudo step_up_freshness).each do |claim|
      assert_email_ceremony_error("forbidden claims") do
        IdentityEmailCeremonyResult.new(valid_result_claims.merge(claim => "secret"), now: @now)
      end
    end
  end

  test "signature verification rejects wrong key and tampering" do
    travel_to @now do
      token = IdentityEmailCeremonyGrant.issue(valid_grant_claims, issuer_id: acme_issuer_id, now: @now)

      assert_email_ceremony_error("kid is unknown") do
        IdentityEmailCeremonyGrant.decode(token, issuer_id: "surface:ACME_COM", now: @now)
      end

      tampered_payload = valid_grant_claims.merge("actor_ref" => "attacker")
      tampered = token.split(".").tap do |parts|
        parts[1] = Base64.urlsafe_encode64(tampered_payload.to_json, padding: false)
      end.join(".")
      assert_email_ceremony_error("token verification failed") do
        IdentityEmailCeremonyGrant.decode(tampered, issuer_id: acme_issuer_id, now: @now)
      end
    end
  end

  test "validate_timestamp rejects non-integer iat" do
    assert_email_ceremony_error("iat must be an integer timestamp") do
      IdentityEmailCeremonyContract.validate_timestamp!({ "iat" => "not-a-number" }, "iat")
    end
  end

  test "validate_header rejects a case-variant algorithm" do
    assert_email_ceremony_error("alg is invalid") do
      IdentityEmailCeremonyContract.validate_header!(
        { "alg" => "eS384", "typ" => IdentityEmailCeremonyGrant::TOKEN_TYPE, "kid" => "kid-1" },
        expected_type: IdentityEmailCeremonyGrant::TOKEN_TYPE,
      )
    end
  end

  test "validate_future_timestamp rejects non-integer exp" do
    assert_email_ceremony_error("exp must be an integer timestamp") do
      IdentityEmailCeremonyContract.validate_future_timestamp!({ "exp" => "bad" }, "exp", now: @now)
    end
  end

  test "validate_return_to rejects absolute urls and protocol-relative urls" do
    assert_email_ceremony_error("return_to must be relative navigation metadata") do
      IdentityEmailCeremonyContract.validate_return_to!("return_to" => "https://evil.example")
    end

    assert_email_ceremony_error("return_to must be relative navigation metadata") do
      IdentityEmailCeremonyContract.validate_return_to!("return_to" => "//evil.example")
    end
  end

  test "validate_return_to accepts blank and relative paths" do
    assert_nil IdentityEmailCeremonyContract.validate_return_to!("return_to" => nil)
    assert_nil IdentityEmailCeremonyContract.validate_return_to!("return_to" => "")
    assert_nil IdentityEmailCeremonyContract.validate_return_to!("return_to" => "/settings/emails")
  end

  test "decode_unverified_payload rejects invalid tokens" do
    assert_email_ceremony_error("token is invalid") do
      IdentityEmailCeremonyContract.decode_unverified_payload("not.a.jwt")
    end
  end

  test "decode_unverified_payload rejects a token whose payload is not a JSON object" do
    header = Base64.urlsafe_encode64(%q({"alg":"none"}), padding: false)

    ["[1]", "5", %q("surface")].each do |body|
      token = "#{header}.#{Base64.urlsafe_encode64(body, padding: false)}."

      error =
        assert_raises(IdentityEmailCeremonyContract::Error) do
          IdentityEmailCeremonyContract.decode_unverified_payload(token)
        end
      assert_includes error.message, "must be a JSON object", "payload #{body}"
    end
  end

  private

  def acme_issuer_id = IdentityEmailCeremonyContract.acme_issuer_id("app")

  def sign_issuer_id = IdentityEmailCeremonyContract.sign_issuer_id("app")

  def valid_grant_claims
    {
      "typ" => IdentityEmailCeremonyGrant::TOKEN_TYPE,
      "iss" => IdentityEmailCeremonyContract.acme_issuer("app"),
      "aud" => IdentityEmailCeremonyContract.sign_audience("app"),
      "purpose" => IdentityEmailCeremonyGrant::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "jti" => "grant-1",
      "operation" => "registration",
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
      "email_candidate_ref" => "candidate-1",
      "normalized_email_digest" => "digest-1",
    }
  end

  def valid_result_claims
    {
      "typ" => IdentityEmailCeremonyResult::TOKEN_TYPE,
      "iss" => IdentityEmailCeremonyContract.sign_issuer("app"),
      "aud" => IdentityEmailCeremonyContract.acme_audience("app"),
      "purpose" => IdentityEmailCeremonyResult::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "grant_jti" => "grant-1",
      "result_jti" => "result-1",
      "operation" => "registration",
      "proof_method" => IdentityEmailCeremonyResult::PROOF_METHOD,
      "verified_at" => @now.to_i,
      "challenge_id" => "challenge-1",
      "expires_at" => (@now + 10.minutes).to_i,
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
      "email_candidate_ref" => "candidate-1",
      "normalized_email_digest" => "digest-1",
    }
  end

  def assert_email_ceremony_error(message)
    error = assert_raises(IdentityEmailCeremonyContract::Error) { yield }
    assert_includes error.message, message
  end
end

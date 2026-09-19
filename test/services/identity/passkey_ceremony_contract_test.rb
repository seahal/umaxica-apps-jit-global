# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityPasskeyCeremonyContractTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @now = Time.zone.parse("2026-06-03 12:00:00")
  end

  teardown do
    travel_back
  end

  test "valid grant and result serialize and verify" do
    travel_to @now do
      grant_token = IdentityPasskeyCeremonyGrant.issue(valid_grant_claims, issuer_id: acme_issuer_id, now: @now)
      grant = IdentityPasskeyCeremonyGrant.decode(grant_token, issuer_id: acme_issuer_id, now: @now)

      assert_equal "passkey_ceremony", grant["purpose"]
      assert_equal IdentityPasskeyCeremonyContract.sign_audience("app"), grant["aud"]

      result_token = IdentityPasskeyCeremonyResult.issue(valid_result_claims, issuer_id: sign_issuer_id, now: @now)
      result = IdentityPasskeyCeremonyResult.decode(result_token, issuer_id: sign_issuer_id, now: @now)

      assert_equal "passkey_ceremony_result", result["purpose"]
      assert_equal "webauthn_attestation", result["proof_method"]
      assert_equal IdentityPasskeyCeremonyContract.acme_audience("app"), result["aud"]
    end
  end

  test "grant rejects binding, audience, purpose, surface, operation, expiry, and forbidden fields" do
    assert_passkey_ceremony_error("actor_ref") do
      IdentityPasskeyCeremonyGrant.new(valid_grant_claims.except("actor_ref"), now: @now)
    end
    assert_passkey_ceremony_error("aud is invalid") do
      IdentityPasskeyCeremonyGrant.new(valid_grant_claims.merge("aud" => "https://evil.example"), now: @now)
    end
    assert_passkey_ceremony_error("purpose is invalid") do
      IdentityPasskeyCeremonyGrant.new(valid_grant_claims.merge("purpose" => "wrong"), now: @now)
    end
    assert_passkey_ceremony_error("surface is invalid") do
      IdentityPasskeyCeremonyGrant.new(valid_grant_claims.merge("surface" => "bad"), now: @now)
    end
    assert_passkey_ceremony_error("operation is invalid") do
      IdentityPasskeyCeremonyGrant.new(valid_grant_claims.merge("operation" => "replacement"), now: @now)
    end
    assert_passkey_ceremony_error("exp is expired") do
      IdentityPasskeyCeremonyGrant.new(valid_grant_claims.merge("exp" => (@now - 1.second).to_i), now: @now)
    end
    %w(private_key session_token refresh_token recent_auth sudo step_up_freshness).each do |claim|
      assert_passkey_ceremony_error("forbidden claims") do
        IdentityPasskeyCeremonyGrant.new(valid_grant_claims.merge(claim => "secret"), now: @now)
      end
    end
  end

  test "result rejects proof, expiry, redirect, and forbidden fields" do
    assert_passkey_ceremony_error("grant_jti") do
      IdentityPasskeyCeremonyResult.new(valid_result_claims.except("grant_jti"), now: @now)
    end
    assert_passkey_ceremony_error("proof_method is invalid") do
      IdentityPasskeyCeremonyResult.new(valid_result_claims.merge("proof_method" => "totp"), now: @now)
    end
    assert_passkey_ceremony_error("expires_at is expired") do
      IdentityPasskeyCeremonyResult.new(
        valid_result_claims.merge("expires_at" => (@now - 1.second).to_i),
        now: @now,
      )
    end
    assert_passkey_ceremony_error("unknown claims") do
      IdentityPasskeyCeremonyResult.new(valid_result_claims.merge("return_to" => "/settings/passkeys"), now: @now)
    end
    %w(private_key session_token refresh_token raw_password recent_auth sudo step_up_freshness).each do |claim|
      assert_passkey_ceremony_error("forbidden claims") do
        IdentityPasskeyCeremonyResult.new(valid_result_claims.merge(claim => "secret"), now: @now)
      end
    end
  end

  test "signature verification rejects wrong key and tampering" do
    travel_to @now do
      token = IdentityPasskeyCeremonyGrant.issue(valid_grant_claims, issuer_id: acme_issuer_id, now: @now)

      assert_passkey_ceremony_error("kid is unknown") do
        IdentityPasskeyCeremonyGrant.decode(token, issuer_id: "surface:ACME_COM", now: @now)
      end

      tampered_payload = valid_grant_claims.merge("actor_ref" => "attacker")
      tampered = token.split(".").tap do |parts|
        parts[1] = Base64.urlsafe_encode64(tampered_payload.to_json, padding: false)
      end.join(".")
      assert_passkey_ceremony_error("token verification failed") do
        IdentityPasskeyCeremonyGrant.decode(tampered, issuer_id: acme_issuer_id, now: @now)
      end
    end
  end

  test "contract validators reject malformed timestamps and navigation metadata" do
    assert_passkey_ceremony_error("iat must be an integer timestamp") do
      IdentityPasskeyCeremonyContract.validate_timestamp!({ "iat" => "invalid" }, "iat")
    end
    assert_passkey_ceremony_error("exp must be an integer timestamp") do
      IdentityPasskeyCeremonyContract.validate_future_timestamp!(
        { "exp" => "invalid" }, "exp", now: @now,
      )
    end
    assert_passkey_ceremony_error("return_to must be relative navigation metadata") do
      IdentityPasskeyCeremonyContract.validate_return_to!({ "return_to" => "https://evil.example" })
    end
    assert_passkey_ceremony_error("return_to must be relative navigation metadata") do
      IdentityPasskeyCeremonyContract.validate_return_to!({ "return_to" => "//evil.example" })
    end
  end

  test "unverified payload decoding wraps malformed token errors" do
    assert_passkey_ceremony_error("token is invalid") do
      IdentityPasskeyCeremonyContract.decode_unverified_payload("not-a-token")
    end
  end

  test "decode_unverified_payload rejects a token whose payload is not a JSON object" do
    header = Base64.urlsafe_encode64(%q({"alg":"none"}), padding: false)

    ["[1]", "5", %q("surface")].each do |body|
      token = "#{header}.#{Base64.urlsafe_encode64(body, padding: false)}."

      error =
        assert_raises(IdentityPasskeyCeremonyContract::Error) do
          IdentityPasskeyCeremonyContract.decode_unverified_payload(token)
        end
      assert_includes error.message, "must be a JSON object", "payload #{body}"
    end
  end

  private

  def acme_issuer_id = IdentityPasskeyCeremonyContract.acme_issuer_id("app")

  def sign_issuer_id = IdentityPasskeyCeremonyContract.sign_issuer_id("app")

  def valid_grant_claims
    {
      "typ" => IdentityPasskeyCeremonyGrant::TOKEN_TYPE,
      "iss" => IdentityPasskeyCeremonyContract.acme_issuer("app"),
      "aud" => IdentityPasskeyCeremonyContract.sign_audience("app"),
      "purpose" => IdentityPasskeyCeremonyGrant::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "jti" => "grant-1",
      "operation" => "registration",
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
    }
  end

  def valid_result_claims
    {
      "typ" => IdentityPasskeyCeremonyResult::TOKEN_TYPE,
      "iss" => IdentityPasskeyCeremonyContract.sign_issuer("app"),
      "aud" => IdentityPasskeyCeremonyContract.acme_audience("app"),
      "purpose" => IdentityPasskeyCeremonyResult::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "grant_jti" => "grant-1",
      "result_jti" => "result-1",
      "operation" => "registration",
      "proof_method" => IdentityPasskeyCeremonyResult::PROOF_METHOD,
      "verified_at" => @now.to_i,
      "challenge_id" => "challenge-1",
      "expires_at" => (@now + 10.minutes).to_i,
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
      "webauthn_id" => "credential-id",
      "public_key" => "public-key",
      "sign_count" => 0,
    }
  end

  def assert_passkey_ceremony_error(message)
    error = assert_raises(IdentityPasskeyCeremonyContract::Error) { yield }
    assert_includes error.message, message
  end
end

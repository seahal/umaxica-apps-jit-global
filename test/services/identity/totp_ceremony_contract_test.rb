# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityTotpCeremonyContractTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @now = Time.zone.parse("2026-06-03 12:00:00")
  end

  teardown do
    travel_back
  end

  test "valid grant and result serialize and verify" do
    travel_to @now do
      grant_token = IdentityTotpCeremonyGrant.issue(valid_grant_claims, issuer_id: acme_issuer_id, now: @now)
      grant = IdentityTotpCeremonyGrant.decode(grant_token, issuer_id: acme_issuer_id, now: @now)

      assert_equal "totp_ceremony", grant["purpose"]
      assert_equal IdentityTotpCeremonyContract.sign_audience("app"), grant["aud"]

      result_token = IdentityTotpCeremonyResult.issue(valid_result_claims, issuer_id: sign_issuer_id, now: @now)
      result = IdentityTotpCeremonyResult.decode(result_token, issuer_id: sign_issuer_id, now: @now)

      assert_equal "totp_ceremony_result", result["purpose"]
      assert_equal "totp", result["proof_method"]
      assert_equal IdentityTotpCeremonyContract.acme_audience("app"), result["aud"]
    end
  end

  test "grant rejects binding, audience, purpose, surface, operation, expiry, and forbidden fields" do
    assert_totp_ceremony_error("actor_ref") do
      IdentityTotpCeremonyGrant.new(valid_grant_claims.except("actor_ref"), now: @now)
    end
    assert_totp_ceremony_error("aud is invalid") do
      IdentityTotpCeremonyGrant.new(valid_grant_claims.merge("aud" => "https://evil.example"), now: @now)
    end
    assert_totp_ceremony_error("purpose is invalid") do
      IdentityTotpCeremonyGrant.new(valid_grant_claims.merge("purpose" => "wrong"), now: @now)
    end
    assert_totp_ceremony_error("surface is invalid") do
      IdentityTotpCeremonyGrant.new(valid_grant_claims.merge("surface" => "com"), now: @now)
    end
    assert_totp_ceremony_error("operation is invalid") do
      IdentityTotpCeremonyGrant.new(valid_grant_claims.merge("operation" => "replacement"), now: @now)
    end
    assert_totp_ceremony_error("exp is expired") do
      IdentityTotpCeremonyGrant.new(valid_grant_claims.merge("exp" => (@now - 1.second).to_i), now: @now)
    end
    %w(private_key session_token refresh_token totp_secret raw_totp first_token recent_auth sudo
       step_up_freshness).each do |claim|
      assert_totp_ceremony_error("forbidden claims") do
        IdentityTotpCeremonyGrant.new(valid_grant_claims.merge(claim => "secret"), now: @now)
      end
    end
  end

  test "result rejects proof, expiry, redirect, and forbidden fields" do
    assert_totp_ceremony_error("grant_jti") do
      IdentityTotpCeremonyResult.new(valid_result_claims.except("grant_jti"), now: @now)
    end
    assert_totp_ceremony_error("proof_method is invalid") do
      IdentityTotpCeremonyResult.new(valid_result_claims.merge("proof_method" => "email_otp"), now: @now)
    end
    assert_totp_ceremony_error("expires_at is expired") do
      IdentityTotpCeremonyResult.new(
        valid_result_claims.merge("expires_at" => (@now - 1.second).to_i),
        now: @now,
      )
    end
    assert_totp_ceremony_error("unknown claims") do
      IdentityTotpCeremonyResult.new(valid_result_claims.merge("return_to" => "/settings/totps"), now: @now)
    end
    %w(private_key session_token refresh_token secret_key totp_secret raw_totp first_token recent_auth sudo
       step_up_freshness).each do |claim|
      assert_totp_ceremony_error("forbidden claims") do
        IdentityTotpCeremonyResult.new(valid_result_claims.merge(claim => "secret"), now: @now)
      end
    end
  end

  test "signature verification rejects wrong key and tampering" do
    travel_to @now do
      token = IdentityTotpCeremonyGrant.issue(valid_grant_claims, issuer_id: acme_issuer_id, now: @now)

      assert_totp_ceremony_error("kid is unknown") do
        IdentityTotpCeremonyGrant.decode(token, issuer_id: "surface:ACME_COM", now: @now)
      end

      tampered_payload = valid_grant_claims.merge("actor_ref" => "attacker")
      tampered = token.split(".").tap do |parts|
        parts[1] = Base64.urlsafe_encode64(tampered_payload.to_json, padding: false)
      end.join(".")
      assert_totp_ceremony_error("token verification failed") do
        IdentityTotpCeremonyGrant.decode(tampered, issuer_id: acme_issuer_id, now: @now)
      end
    end
  end

  test "validate_timestamp rejects non-integer iat" do
    assert_totp_ceremony_error("iat must be an integer timestamp") do
      IdentityTotpCeremonyContract.validate_timestamp!({ "iat" => "not-a-number" }, "iat")
    end
  end

  test "validate_future_timestamp rejects non-integer exp" do
    assert_totp_ceremony_error("exp must be an integer timestamp") do
      IdentityTotpCeremonyContract.validate_future_timestamp!({ "exp" => "bad" }, "exp", now: @now)
    end
  end

  test "decode_unverified_payload rejects invalid tokens" do
    assert_totp_ceremony_error("token is invalid") do
      IdentityTotpCeremonyContract.decode_unverified_payload("not.a.jwt")
    end
  end

  test "TOTP candidate store persists fetches and consumes a one-shot candidate" do
    travel_to @now do
      candidate = IdentityTotpCeremonyCandidateStore.store!(
        surface: "app",
        actor_ref: "actor-1",
        session_ref: "session-1",
        private_key: "totp-private-key",
        title: "Authenticator",
        last_otp_at: @now.to_i,
        expires_at: @now + 5.minutes,
      )

      fetched = IdentityTotpCeremonyCandidateStore.fetch!(candidate.ref)

      assert_equal candidate.ref, fetched.ref
      assert_equal candidate.digest, fetched.digest
      assert_equal "totp-private-key", fetched.private_key
      assert_equal "Authenticator", fetched.title
      assert_equal @now.to_i, fetched.last_otp_at.to_i

      consumed = IdentityTotpCeremonyCandidateStore.consume!(candidate.ref)

      assert_equal candidate.ref, consumed.ref
      assert_not_nil IdentityTotpCeremonyCandidate.find_by!(ref: candidate.ref).consumed_at
      error =
        assert_raises(IdentityTotpCeremonyContract::Error) do
          IdentityTotpCeremonyCandidateStore.fetch!(candidate.ref)
        end
      assert_includes error.message, "candidate is not found"
    end
  end

  test "TOTP candidate store rejects missing secrets and expires deleted candidates" do
    travel_to @now do
      missing_error =
        assert_raises(IdentityTotpCeremonyContract::Error) do
          IdentityTotpCeremonyCandidateStore.store!(
            surface: "app", actor_ref: "actor-1", session_ref: "session-1", private_key: nil,
            title: "Missing", last_otp_at: @now.to_i, expires_at: @now + 5.minutes,
          )
        end
      assert_includes missing_error.message, "secret is required"

      expired = IdentityTotpCeremonyCandidateStore.store!(
        surface: "app", actor_ref: "actor-1", session_ref: "session-expired",
        private_key: "expired-key", title: "Expired", last_otp_at: @now.to_i,
        expires_at: @now - 1.second,
      )
      expired_error =
        assert_raises(IdentityTotpCeremonyContract::Error) do
          IdentityTotpCeremonyCandidateStore.fetch!(expired.ref)
        end
      assert_includes expired_error.message, "candidate is expired"

      deleted = IdentityTotpCeremonyCandidateStore.store!(
        surface: "app", actor_ref: "actor-1", session_ref: "session-deleted",
        private_key: "deleted-key", title: "Deleted", last_otp_at: @now.to_i,
        expires_at: @now + 5.minutes,
      )
      IdentityTotpCeremonyCandidateStore.delete(deleted.ref)
      deleted_error =
        assert_raises(IdentityTotpCeremonyContract::Error) do
          IdentityTotpCeremonyCandidateStore.fetch!(deleted.ref)
        end
      assert_includes deleted_error.message, "candidate is not found"
    end
  end

  test "decode_unverified_payload rejects a token whose payload is not a JSON object" do
    header = Base64.urlsafe_encode64(%q({"alg":"none"}), padding: false)

    ["[1]", "5", %q("surface")].each do |body|
      token = "#{header}.#{Base64.urlsafe_encode64(body, padding: false)}."

      error =
        assert_raises(IdentityTotpCeremonyContract::Error) do
          IdentityTotpCeremonyContract.decode_unverified_payload(token)
        end
      assert_includes error.message, "must be a JSON object", "payload #{body}"
    end
  end

  private

  def acme_issuer_id = IdentityTotpCeremonyContract.acme_issuer_id("app")

  def sign_issuer_id = IdentityTotpCeremonyContract.sign_issuer_id("app")

  def valid_grant_claims
    {
      "typ" => IdentityTotpCeremonyGrant::TOKEN_TYPE,
      "iss" => IdentityTotpCeremonyContract.acme_issuer("app"),
      "aud" => IdentityTotpCeremonyContract.sign_audience("app"),
      "purpose" => IdentityTotpCeremonyGrant::PURPOSE,
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
      "typ" => IdentityTotpCeremonyResult::TOKEN_TYPE,
      "iss" => IdentityTotpCeremonyContract.sign_issuer("app"),
      "aud" => IdentityTotpCeremonyContract.acme_audience("app"),
      "purpose" => IdentityTotpCeremonyResult::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "grant_jti" => "grant-1",
      "result_jti" => "result-1",
      "operation" => "registration",
      "proof_method" => IdentityTotpCeremonyResult::PROOF_METHOD,
      "verified_at" => @now.to_i,
      "challenge_id" => "challenge-1",
      "expires_at" => (@now + 10.minutes).to_i,
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
      "credential_candidate_ref" => "candidate-1",
      "credential_candidate_digest" => "candidate-digest-1",
    }
  end

  def assert_totp_ceremony_error(message)
    error = assert_raises(IdentityTotpCeremonyContract::Error) { yield }
    assert_includes error.message, message
  end
end

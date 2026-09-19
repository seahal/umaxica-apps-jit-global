# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentitySecretCredentialCeremonyContractTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @now = Time.zone.parse("2026-06-03 12:00:00")
  end

  teardown do
    travel_back
  end

  test "valid grant and result serialize and verify" do
    travel_to @now do
      grant_token = IdentitySecretCredentialCeremonyGrant.issue(
        valid_grant_claims, issuer_id: acme_issuer_id,
                            now: @now,
      )
      grant = IdentitySecretCredentialCeremonyGrant.decode(grant_token, issuer_id: acme_issuer_id, now: @now)

      assert_equal "secret_credential_ceremony", grant["purpose"]
      assert_equal IdentitySecretCredentialCeremonyContract.sign_audience("app"), grant["aud"]

      result_token = IdentitySecretCredentialCeremonyResult.issue(
        valid_result_claims, issuer_id: sign_issuer_id,
                             now: @now,
      )
      result = IdentitySecretCredentialCeremonyResult.decode(result_token, issuer_id: sign_issuer_id, now: @now)

      assert_equal "secret_credential_ceremony_result", result["purpose"]
      assert_equal "secret_credential", result["proof_method"]
      assert_equal IdentitySecretCredentialCeremonyContract.acme_audience("app"), result["aud"]
    end
  end

  test "grant rejects binding, audience, purpose, surface, operation, expiry, and forbidden fields" do
    assert_secret_credential_ceremony_error("actor_ref") do
      IdentitySecretCredentialCeremonyGrant.new(valid_grant_claims.except("actor_ref"), now: @now)
    end
    assert_secret_credential_ceremony_error("aud is invalid") do
      IdentitySecretCredentialCeremonyGrant.new(
        valid_grant_claims.merge("aud" => "https://evil.example"),
        now: @now,
      )
    end
    assert_secret_credential_ceremony_error("purpose is invalid") do
      IdentitySecretCredentialCeremonyGrant.new(valid_grant_claims.merge("purpose" => "wrong"), now: @now)
    end
    assert_secret_credential_ceremony_error("surface is invalid") do
      IdentitySecretCredentialCeremonyGrant.new(valid_grant_claims.merge("surface" => "net"), now: @now)
    end
    assert_secret_credential_ceremony_error("operation is invalid") do
      IdentitySecretCredentialCeremonyGrant.new(valid_grant_claims.merge("operation" => "replacement"), now: @now)
    end
    assert_secret_credential_ceremony_error("exp is expired") do
      IdentitySecretCredentialCeremonyGrant.new(
        valid_grant_claims.merge("exp" => (@now - 1.second).to_i),
        now: @now,
      )
    end
    %w(password password_digest raw_password raw_secret_credential session_token refresh_token secret recent_auth sudo
       step_up_freshness).each do |claim|
      assert_secret_credential_ceremony_error("forbidden claims") do
        IdentitySecretCredentialCeremonyGrant.new(valid_grant_claims.merge(claim => "secret"), now: @now)
      end
    end
  end

  test "result rejects proof, expiry, redirect, and forbidden fields" do
    assert_secret_credential_ceremony_error("grant_jti") do
      IdentitySecretCredentialCeremonyResult.new(valid_result_claims.except("grant_jti"), now: @now)
    end
    assert_secret_credential_ceremony_error("proof_method is invalid") do
      IdentitySecretCredentialCeremonyResult.new(
        valid_result_claims.merge("proof_method" => "email_otp"),
        now: @now,
      )
    end
    assert_secret_credential_ceremony_error("expires_at is expired") do
      IdentitySecretCredentialCeremonyResult.new(
        valid_result_claims.merge("expires_at" => (@now - 1.second).to_i),
        now: @now,
      )
    end
    assert_secret_credential_ceremony_error("unknown claims") do
      IdentitySecretCredentialCeremonyResult.new(
        valid_result_claims.merge("return_to" => "/settings/secrets"), now: @now,
      )
    end
    %w(password password_digest raw_password raw_secret_credential session_token refresh_token secret recent_auth sudo
       step_up_freshness).each do |claim|
      assert_secret_credential_ceremony_error("forbidden claims") do
        IdentitySecretCredentialCeremonyResult.new(valid_result_claims.merge(claim => "secret"), now: @now)
      end
    end
  end

  test "signature verification rejects wrong key and tampering" do
    travel_to @now do
      token = IdentitySecretCredentialCeremonyGrant.issue(valid_grant_claims, issuer_id: acme_issuer_id, now: @now)

      assert_secret_credential_ceremony_error("kid is unknown") do
        IdentitySecretCredentialCeremonyGrant.decode(token, issuer_id: "surface:ACME_COM", now: @now)
      end

      tampered_payload = valid_grant_claims.merge("actor_ref" => "attacker")
      tampered = token.split(".").tap do |parts|
        parts[1] = Base64.urlsafe_encode64(tampered_payload.to_json, padding: false)
      end.join(".")
      assert_secret_credential_ceremony_error("token verification failed") do
        IdentitySecretCredentialCeremonyGrant.decode(tampered, issuer_id: acme_issuer_id, now: @now)
      end
    end
  end

  test "secret credential candidate store persists fetches and consumes a one-shot candidate" do
    travel_to @now do
      candidate = IdentitySecretCredentialCeremonyCandidateStore.store!(
        surface: "app",
        actor_ref: "actor-1",
        session_ref: "session-1",
        transaction_id: "txn-1",
        operation: "enrollment",
        password_digest: "password-digest",
        name: "API Key",
        enabled: "false",
        expires_at: @now + 5.minutes,
      )

      fetched = IdentitySecretCredentialCeremonyCandidateStore.fetch!(candidate.ref)

      assert_equal candidate.ref, fetched.ref
      assert_equal candidate.digest, fetched.digest
      assert_equal "password-digest", fetched.password_digest
      assert_equal "API Key", fetched.name
      assert_not fetched.enabled

      consumed = IdentitySecretCredentialCeremonyCandidateStore.consume!(candidate.ref)

      assert_equal candidate.ref, consumed.ref
      assert_not_nil IdentitySecretCredentialCeremonyCandidate.find_by!(ref: candidate.ref).consumed_at
      error =
        assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
          IdentitySecretCredentialCeremonyCandidateStore.fetch!(candidate.ref)
        end
      assert_includes error.message, "candidate is not found"
    end
  end

  test "secret credential candidate store rejects missing secrets and expires deleted candidates" do
    travel_to @now do
      missing_error =
        assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
          IdentitySecretCredentialCeremonyCandidateStore.store!(
            surface: "app", actor_ref: "actor-1", session_ref: "session-1",
            transaction_id: "txn-missing", operation: "enrollment", password_digest: nil,
            name: "Missing", enabled: true, expires_at: @now + 5.minutes,
          )
        end
      assert_includes missing_error.message, "password digest is required"

      expired = IdentitySecretCredentialCeremonyCandidateStore.store!(
        surface: "app", actor_ref: "actor-1", session_ref: "session-expired",
        transaction_id: "txn-expired", operation: "enrollment", password_digest: "digest",
        name: "Expired", enabled: true, expires_at: @now - 1.second,
      )
      expired_error =
        assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
          IdentitySecretCredentialCeremonyCandidateStore.fetch!(expired.ref)
        end
      assert_includes expired_error.message, "candidate is expired"

      deleted = IdentitySecretCredentialCeremonyCandidateStore.store!(
        surface: "app", actor_ref: "actor-1", session_ref: "session-deleted",
        transaction_id: "txn-deleted", operation: "enrollment", password_digest: "digest",
        name: "Deleted", enabled: true, expires_at: @now + 5.minutes,
      )
      IdentitySecretCredentialCeremonyCandidateStore.delete(deleted.ref)
      deleted_error =
        assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
          IdentitySecretCredentialCeremonyCandidateStore.fetch!(deleted.ref)
        end
      assert_includes deleted_error.message, "candidate is not found"
    end
  end

  test "decode_unverified_payload rejects a token whose payload is not a JSON object" do
    header = Base64.urlsafe_encode64(%q({"alg":"none"}), padding: false)

    ["[1]", "5", %q("surface")].each do |body|
      token = "#{header}.#{Base64.urlsafe_encode64(body, padding: false)}."

      error =
        assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
          IdentitySecretCredentialCeremonyContract.decode_unverified_payload(token)
        end
      assert_includes error.message, "must be a JSON object", "payload #{body}"
    end
  end

  private

  def acme_issuer_id = IdentitySecretCredentialCeremonyContract.acme_issuer_id("app")

  def sign_issuer_id = IdentitySecretCredentialCeremonyContract.sign_issuer_id("app")

  def valid_grant_claims
    {
      "typ" => IdentitySecretCredentialCeremonyGrant::TOKEN_TYPE,
      "iss" => IdentitySecretCredentialCeremonyContract.acme_issuer("app"),
      "aud" => IdentitySecretCredentialCeremonyContract.sign_audience("app"),
      "purpose" => IdentitySecretCredentialCeremonyGrant::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "jti" => "grant-1",
      "operation" => "enrollment",
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
    }
  end

  def valid_result_claims
    {
      "typ" => IdentitySecretCredentialCeremonyResult::TOKEN_TYPE,
      "iss" => IdentitySecretCredentialCeremonyContract.sign_issuer("app"),
      "aud" => IdentitySecretCredentialCeremonyContract.acme_audience("app"),
      "purpose" => IdentitySecretCredentialCeremonyResult::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "grant_jti" => "grant-1",
      "result_jti" => "result-1",
      "operation" => "enrollment",
      "proof_method" => IdentitySecretCredentialCeremonyResult::PROOF_METHOD,
      "verified_at" => @now.to_i,
      "challenge_id" => "challenge-1",
      "expires_at" => (@now + 10.minutes).to_i,
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
      "credential_candidate_ref" => "candidate-1",
      "credential_candidate_digest" => "candidate-digest-1",
    }
  end

  def assert_secret_credential_ceremony_error(message)
    error = assert_raises(IdentitySecretCredentialCeremonyContract::Error) { yield }
    assert_includes error.message, message
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentitySocialCeremonyContractTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @now = Time.zone.parse("2026-06-03 12:00:00")
  end

  teardown do
    IdentitySocialCeremonyCandidate.find_each(&:destroy!)
    travel_back
  end

  test "valid grant and result serialize and verify" do
    travel_to @now do
      grant_token = IdentitySocialCeremonyGrant.issue(valid_grant_claims, issuer_id: acme_issuer_id, now: @now)
      grant = IdentitySocialCeremonyGrant.decode(grant_token, issuer_id: acme_issuer_id, now: @now)

      assert_equal "social_ceremony", grant["purpose"]
      assert_equal IdentitySocialCeremonyContract.sign_audience("app"), grant["aud"]

      result_token = IdentitySocialCeremonyResult.issue(valid_result_claims, issuer_id: sign_issuer_id, now: @now)
      result = IdentitySocialCeremonyResult.decode(result_token, issuer_id: sign_issuer_id, now: @now)

      assert_equal "social_ceremony_result", result["purpose"]
      assert_equal "provider_subject", result["proof_method"]
      assert_equal IdentitySocialCeremonyContract.acme_audience("app"), result["aud"]
    end
  end

  test "login operation allows candidate reference without provider token claims" do
    travel_to @now do
      grant_claims = valid_grant_claims.merge("operation" => "login", "actor_ref" => "anonymous")
      grant_token = IdentitySocialCeremonyGrant.issue(grant_claims, issuer_id: acme_issuer_id, now: @now)
      grant = IdentitySocialCeremonyGrant.decode(grant_token, issuer_id: acme_issuer_id, now: @now)

      assert_equal "login", grant["operation"]
      assert_equal "anonymous", grant["actor_ref"]

      result_claims = valid_result_claims.merge(
        "operation" => "login",
        "actor_ref" => "anonymous",
        "candidate_ref" => "candidate-1",
        "candidate_digest" => "candidate-digest-1",
      )
      result_token = IdentitySocialCeremonyResult.issue(result_claims, issuer_id: sign_issuer_id, now: @now)
      result = IdentitySocialCeremonyResult.decode(result_token, issuer_id: sign_issuer_id, now: @now)

      assert_equal "login", result["operation"]
      assert_equal "candidate-1", result["candidate_ref"]
      assert_equal "candidate-digest-1", result["candidate_digest"]
      assert_not_includes result.to_json, "access_token"
      assert_not_includes result.to_json, "refresh_token"
    end
  end

  test "rejects an authentication event time from the future" do
    assert_social_ceremony_error("auth_time must not be in the future") do
      IdentitySocialCeremonyResult.new(
        valid_result_claims.merge("auth_time" => (@now + 2.minutes).to_i),
        now: @now,
      )
    end
  end

  test "candidate store is one-shot and persists only a verified principal" do
    travel_to(@now) do
      callback_result = ExternalAuthentication::CallbackResult.verified(
        principal: ExternalAuthentication::VerifiedPrincipal.new(
          provider: "google",
          subject: "candidate-google",
          issuer: "https://accounts.google.com",
          audience: "google-client-id",
          verified_at: @now,
          verification_authority: "omniauth-google-oauth2/contract",
        ),
        credential_candidate: nil,
      )
      candidate = IdentitySocialCeremonyCandidateStore.store!(
        surface: "app",
        actor_ref: "anonymous",
        session_ref: "session-1",
        transaction_id: "txn-1",
        operation: "login",
        provider: "google",
        callback_result: callback_result,
        expires_at: @now + 5.minutes,
      )

      fetched = IdentitySocialCeremonyCandidateStore.fetch!(candidate.ref)

      assert_equal "candidate-google", fetched.callback_result.principal.subject
      assert_nil fetched.callback_result.credential_candidate
      assert_equal candidate.digest, fetched.digest
      assert_equal candidate.ref, IdentitySocialCeremonyCandidate.find_by!(ref: candidate.ref).ref
      assert_not_includes encrypted_social_candidate_auth_hash(candidate.ref), "candidate-google"

      consumed = IdentitySocialCeremonyCandidateStore.consume!(candidate.ref)

      assert_equal candidate.ref, consumed.ref
      assert_not_nil IdentitySocialCeremonyCandidate.find_by!(ref: candidate.ref).consumed_at
      assert_social_ceremony_error("candidate is not found") do
        IdentitySocialCeremonyCandidateStore.fetch!(candidate.ref)
      end
    end
  end

  test "candidate store rejects an unverified callback or provider mismatch" do
    callback_result = ExternalAuthentication::CallbackResult.verified(
      principal: ExternalAuthentication::VerifiedPrincipal.new(
        provider: "google",
        subject: "candidate-google",
        issuer: "https://accounts.google.com",
        audience: "google-client-id",
        verified_at: @now,
        verification_authority: "omniauth-google-oauth2/contract",
      ),
      credential_candidate: nil,
    )

    assert_no_difference -> { IdentitySocialCeremonyCandidate.count } do
      assert_social_ceremony_error("social auth candidate is required") do
        IdentitySocialCeremonyCandidateStore.store!(
          surface: "app", actor_ref: "anonymous", session_ref: "session-1", transaction_id: "txn-1",
          operation: "login", provider: "google", callback_result: Object.new, expires_at: @now + 5.minutes,
        )
      end

      assert_social_ceremony_error("social auth candidate provider does not match") do
        IdentitySocialCeremonyCandidateStore.store!(
          surface: "app", actor_ref: "anonymous", session_ref: "session-1", transaction_id: "txn-1",
          operation: "login", provider: "apple", callback_result: callback_result, expires_at: @now + 5.minutes,
        )
      end
    end
  end

  test "candidate store rejects expired deleted malformed records and does not call Rails cache" do
    travel_to(@now) do
      cache = Minitest::Mock.new
      callback_result = ExternalAuthentication::CallbackResult.verified(
        principal: ExternalAuthentication::VerifiedPrincipal.new(
          provider: "google",
          subject: "candidate-google",
          issuer: "https://accounts.google.com",
          audience: "google-client-id",
          verified_at: @now,
          verification_authority: "omniauth-google-oauth2/contract",
        ),
        credential_candidate: nil,
      )

      Rails.stub(:cache, cache) do
        expired = IdentitySocialCeremonyCandidateStore.store!(
          surface: "app",
          actor_ref: "anonymous",
          session_ref: "session-expired",
          transaction_id: "txn-expired",
          operation: "login",
          provider: "google",
          callback_result: callback_result,
          expires_at: @now - 1.second,
        )
        deleted = IdentitySocialCeremonyCandidateStore.store!(
          surface: "app",
          actor_ref: "anonymous",
          session_ref: "session-deleted",
          transaction_id: "txn-deleted",
          operation: "login",
          provider: "google",
          callback_result: callback_result,
          expires_at: @now + 5.minutes,
        )
        IdentitySocialCeremonyCandidateStore.delete(deleted.ref)

        malformed = IdentitySocialCeremonyCandidate.create!(
          ref: SecureRandom.uuid,
          digest: "digest",
          surface: "app",
          actor_ref: "anonymous",
          session_ref: "session-malformed",
          transaction_id: "txn-malformed",
          operation: "login",
          provider: "google",
          auth_hash: {
            "principal" => {
              "provider" => "google",
              "subject" => "candidate-google",
              "issuer" => "https://accounts.google.com",
              "audience" => "google-client-id",
              "verified_at" => @now.iso8601,
              "verification_authority" => "omniauth-google-oauth2/contract",
            },
          },
          expires_at: @now + 5.minutes,
        )
        malformed.auth_hash = { "principal" => { "provider" => "google" } }
        malformed.save!(validate: false)

        assert_social_ceremony_error("candidate is expired") {
          IdentitySocialCeremonyCandidateStore.fetch!(expired.ref)
        }
        assert_social_ceremony_error("candidate is not found") {
          IdentitySocialCeremonyCandidateStore.fetch!(deleted.ref)
        }
        assert_social_ceremony_error("candidate is invalid") {
          IdentitySocialCeremonyCandidateStore.fetch!(malformed.ref)
        }
      end

      cache.verify
    end
  end

  test "grant rejects binding, provider, audience, purpose, surface, operation, expiry, and forbidden fields" do
    assert_social_ceremony_error("actor_ref") do
      IdentitySocialCeremonyGrant.new(valid_grant_claims.except("actor_ref"), now: @now)
    end
    assert_social_ceremony_error("provider is invalid") do
      IdentitySocialCeremonyGrant.new(valid_grant_claims.merge("provider" => "github"), now: @now)
    end
    assert_social_ceremony_error("aud is invalid") do
      IdentitySocialCeremonyGrant.new(valid_grant_claims.merge("aud" => "https://evil.example"), now: @now)
    end
    assert_social_ceremony_error("purpose is invalid") do
      IdentitySocialCeremonyGrant.new(valid_grant_claims.merge("purpose" => "wrong"), now: @now)
    end
    assert_social_ceremony_error("surface is invalid") do
      IdentitySocialCeremonyGrant.new(valid_grant_claims.merge("surface" => "org"), now: @now)
    end
    assert_social_ceremony_error("operation is invalid") do
      IdentitySocialCeremonyGrant.new(valid_grant_claims.merge("operation" => "signin"), now: @now)
    end
    assert_social_ceremony_error("exp is expired") do
      IdentitySocialCeremonyGrant.new(valid_grant_claims.merge("exp" => (@now - 1.second).to_i), now: @now)
    end
    %w(access_token id_token refresh_token session_token token recent_auth sudo step_up_freshness
       raw_email).each do |claim|
      assert_social_ceremony_error("forbidden claims") do
        IdentitySocialCeremonyGrant.new(valid_grant_claims.merge(claim => "secret"), now: @now)
      end
    end
  end

  test "result rejects proof, expiry, redirect, and forbidden fields" do
    assert_social_ceremony_error("grant_jti") do
      IdentitySocialCeremonyResult.new(valid_result_claims.except("grant_jti"), now: @now)
    end
    assert_social_ceremony_error("proof_method is invalid") do
      IdentitySocialCeremonyResult.new(valid_result_claims.merge("proof_method" => "oauth_token"), now: @now)
    end
    assert_social_ceremony_error("expires_at is expired") do
      IdentitySocialCeremonyResult.new(
        valid_result_claims.merge("expires_at" => (@now - 1.second).to_i),
        now: @now,
      )
    end
    assert_social_ceremony_error("unknown claims") do
      IdentitySocialCeremonyResult.new(valid_result_claims.merge("return_to" => "/settings"), now: @now)
    end
    %w(access_token id_token refresh_token session_token token recent_auth sudo step_up_freshness
       raw_email).each do |claim|
      assert_social_ceremony_error("forbidden claims") do
        IdentitySocialCeremonyResult.new(valid_result_claims.merge(claim => "secret"), now: @now)
      end
    end
  end

  test "signature verification rejects wrong key and tampering" do
    travel_to @now do
      token = IdentitySocialCeremonyGrant.issue(valid_grant_claims, issuer_id: acme_issuer_id, now: @now)

      assert_social_ceremony_error("kid is unknown") do
        IdentitySocialCeremonyGrant.decode(token, issuer_id: "surface:ACME_COM", now: @now)
      end

      tampered_payload = valid_grant_claims.merge("actor_ref" => "attacker")
      tampered = token.split(".").tap do |parts|
        parts[1] = Base64.urlsafe_encode64(tampered_payload.to_json, padding: false)
      end.join(".")
      assert_social_ceremony_error("token verification failed") do
        IdentitySocialCeremonyGrant.decode(tampered, issuer_id: acme_issuer_id, now: @now)
      end
    end
  end

  test "decode_untrusted_routing_payload rejects a token whose payload is not a JSON object" do
    header = Base64.urlsafe_encode64(%q({"alg":"none"}), padding: false)

    ["[1]", "5", %q("surface")].each do |body|
      token = "#{header}.#{Base64.urlsafe_encode64(body, padding: false)}."

      error =
        assert_raises(IdentitySocialCeremonyContract::Error) do
          IdentitySocialCeremonyContract.decode_untrusted_routing_payload(token)
        end
      assert_includes error.message, "must be a JSON object", "payload #{body}"
    end
  end

  private

  def acme_issuer_id = IdentitySocialCeremonyContract.acme_issuer_id("app")

  def sign_issuer_id = IdentitySocialCeremonyContract.sign_issuer_id("app")

  def valid_grant_claims
    {
      "typ" => IdentitySocialCeremonyGrant::TOKEN_TYPE,
      "iss" => IdentitySocialCeremonyContract.acme_issuer("app"),
      "aud" => IdentitySocialCeremonyContract.sign_audience("app"),
      "purpose" => IdentitySocialCeremonyGrant::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "jti" => "grant-1",
      "operation" => "link",
      "provider" => "google",
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
    }
  end

  def valid_result_claims
    {
      "typ" => IdentitySocialCeremonyResult::TOKEN_TYPE,
      "iss" => IdentitySocialCeremonyContract.sign_issuer("app"),
      "aud" => IdentitySocialCeremonyContract.acme_audience("app"),
      "purpose" => IdentitySocialCeremonyResult::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "grant_jti" => "grant-1",
      "result_jti" => "result-1",
      "operation" => "link",
      "provider" => "google",
      "proof_method" => IdentitySocialCeremonyResult::PROOF_METHOD,
      "provider_subject_ref" => "subject-digest",
      "provider_subject_digest" => "subject-digest",
      "verified_at" => @now.to_i,
      "challenge_id" => "challenge-1",
      "expires_at" => (@now + 10.minutes).to_i,
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
    }
  end

  def assert_social_ceremony_error(message)
    error = assert_raises(IdentitySocialCeremonyContract::Error) { yield }
    assert_includes error.message, message
  end

  def encrypted_social_candidate_auth_hash(ref)
    IdentitySocialCeremonyCandidate.connection.select_value(
      IdentitySocialCeremonyCandidate.sanitize_sql_array(
        [
          # rubocop:disable I18n/RailsI18n/DecorateString
          "SELECT auth_hash FROM identity_social_ceremony_candidates WHERE ref = ?",
          # rubocop:enable I18n/RailsI18n/DecorateString
          ref,
        ],
      ),
    ).to_s
  end
end

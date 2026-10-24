# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentitySocialCeremonyContractTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @now = ClientSocialCeremonyTransaction.database_now.change(usec: 0)
  end

  teardown do
    IdentitySocialCeremonyCandidate.find_each(&:destroy!)
    travel_back
  end

  test "a valid grant serializes and verifies" do
    travel_to @now do
      grant_token = IdentitySocialCeremonyGrant.issue(valid_grant_claims, issuer_id: acme_issuer_id, now: @now)
      grant = IdentitySocialCeremonyGrant.decode(grant_token, issuer_id: acme_issuer_id, now: @now)

      assert_equal "social_ceremony", grant["purpose"]
      assert_equal IdentitySocialCeremonyContract.sign_audience("app"), grant["aud"]
    end
  end

  test "a login grant carries no provider token claims" do
    travel_to @now do
      grant_claims = valid_grant_claims.merge("operation" => "login", "actor_ref" => "anonymous")
      grant_token = IdentitySocialCeremonyGrant.issue(grant_claims, issuer_id: acme_issuer_id, now: @now)
      grant = IdentitySocialCeremonyGrant.decode(grant_token, issuer_id: acme_issuer_id, now: @now)

      assert_equal "login", grant["operation"]
      assert_equal "anonymous", grant["actor_ref"]
    end
  end

  test "a Visa issuer is accepted for the sign-up grant while Base remains the default" do
    travel_to @now do
      issuer_id = IdentitySocialCeremonyContract.visa_issuer_id("app")
      claims = valid_grant_claims.merge(
        "operation" => "signup",
        "iss" => IdentitySocialCeremonyContract.visa_issuer("app"),
      )
      token = IdentitySocialCeremonyGrant.issue(claims, issuer_id:, now: @now)
      grant = IdentitySocialCeremonyGrant.decode(token, issuer_id:, now: @now)

      assert_equal IdentitySocialCeremonyContract.visa_issuer("app"), grant["iss"]
      assert_equal IdentitySocialCeremonyContract.acme_issuer("app"),
                   IdentitySocialCeremonyContract.issuer_for_id("app", acme_issuer_id)
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

      assert_match(/\A[A-Za-z0-9_-]{21}\z/, candidate.ref)
      assert IdentitySocialCeremonyCandidate.valid_reference?(candidate.ref)
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

  test "candidate reference contract accepts new NanoID and retained UUID values only" do
    assert IdentitySocialCeremonyCandidate.valid_reference?("a" * 21)
    assert IdentitySocialCeremonyCandidate.valid_reference?(SecureRandom.uuid)
    assert_not IdentitySocialCeremonyCandidate.valid_reference?("short")
    assert_not IdentitySocialCeremonyCandidate.valid_reference?("a" * 22)
    assert_not IdentitySocialCeremonyCandidate.valid_reference?("candidate/ref")
  end

  test "candidate store retries a generated ref collision without changing the callback binding" do
    callback_result = ExternalAuthentication::CallbackResult.verified(
      principal: ExternalAuthentication::VerifiedPrincipal.new(
        provider: "google",
        subject: "collision-google",
        issuer: "https://accounts.google.com",
        audience: "google-client-id",
        verified_at: @now,
        verification_authority: "omniauth-google-oauth2/contract",
      ),
      credential_candidate: nil,
    )
    existing = IdentitySocialCeremonyCandidateStore.store!(
      surface: "app", actor_ref: "anonymous", session_ref: "collision-session-1",
      transaction_id: "collision-transaction-1", operation: "login", provider: "google",
      callback_result: callback_result, expires_at: @now + 5.minutes,
    )
    generated = [existing.ref, "b" * 21]

    replacement =
      PublicId.stub(:generate, -> { generated.shift }) do
        IdentitySocialCeremonyCandidateStore.store!(
          surface: "app", actor_ref: "anonymous", session_ref: "collision-session-2",
          transaction_id: "collision-transaction-2", operation: "login", provider: "google",
          callback_result: callback_result, expires_at: @now + 5.minutes,
        )
      end

    assert_equal "b" * 21, replacement.ref
    assert_equal "collision-google", replacement.callback_result.principal.subject
    assert_equal 2, IdentitySocialCeremonyCandidate.count
  end

  [-1, 0, 1].each do |offset|
    test "candidate fetch and consume enforce the deadline at #{offset} microseconds" do
      deadline = (IdentitySocialCeremonyCandidate.database_now + 5.minutes).change(usec: 500_000)
      now = deadline + Rational(offset, 1_000_000)
      principal = ExternalAuthentication::VerifiedPrincipal.new(
        provider: "google", subject: "candidate-boundary-#{SecureRandom.hex(8)}",
        issuer: "https://accounts.google.com", audience: "google-client-id",
        verified_at: IdentitySocialCeremonyCandidate.database_now,
        verification_authority: "test-provider-contract",
      )
      stored = IdentitySocialCeremonyCandidateStore.store!(
        surface: "app", actor_ref: "anonymous", session_ref: "candidate-boundary-session",
        transaction_id: SecureRandom.uuid, operation: "login", provider: "google",
        callback_result: ExternalAuthentication::CallbackResult.verified(principal:, credential_candidate: nil),
        expires_at: deadline,
      )
      arguments = {
        now: now,
        error_class: IdentitySocialCeremonyContract::Error,
        not_found_message: "candidate unavailable",
        expired_message: "candidate expired",
      }
      record = IdentitySocialCeremonyCandidate.find_by!(ref: stored.ref)
      if offset.negative?
        assert_equal record.id, IdentitySocialCeremonyCandidate.find_active_by_ref!(stored.ref, **arguments).id
        assert_equal now, record.consume!(**arguments).consumed_at
      else
        assert_raises(IdentitySocialCeremonyContract::Error) do
          IdentitySocialCeremonyCandidate.find_active_by_ref!(stored.ref, **arguments)
        end
        assert_raises(IdentitySocialCeremonyContract::Error) { record.consume!(**arguments) }
        assert_nil record.reload.consumed_at
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

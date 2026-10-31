# typed: false
# frozen_string_literal: true

require "test_helper"

class EmailVerificationChallengeableTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "all surface email ceremony transactions share the EVP challenge contract" do
    assert_includes ClientEmailCeremonyTransaction.included_modules, EmailVerificationChallengeable
    assert_includes OperatorEmailCeremonyTransaction.included_modules, EmailVerificationChallengeable
  end

  test "issue stores only a nonce digest and returns the raw nonce once" do
    now = Time.zone.parse("2026-07-10 12:00:00")

    issued = ClientEmailCeremonyTransaction.issue_evp_challenge!(
      actor_ref: "client-1",
      session_ref: "session-1",
      operation: "registration",
      email_candidate_ref: "email-1",
      normalized_email_digest: "email-digest-1",
      now: now,
    )

    assert_predicate issued.nonce, :present?
    assert_not_equal issued.nonce, issued.transaction.evp_nonce_digest
    assert issued.transaction.evp_nonce_matches?(issued.nonce)
    assert_equal "pending", issued.transaction.evp_outcome
    assert_equal now + 10.minutes, issued.transaction.expires_at
    assert_nil issued.transaction.evp_token_digest
  end

  test "nonce comparison rejects blank and different values" do
    issued = ClientEmailCeremonyTransaction.issue_evp_challenge!(
      actor_ref: "client-2",
      session_ref: "session-2",
      operation: "registration",
      email_candidate_ref: "email-2",
      normalized_email_digest: "email-digest-2",
    )

    assert_not issued.transaction.evp_nonce_matches?(nil)
    assert_not issued.transaction.evp_nonce_matches?("")
    assert_not issued.transaction.evp_nonce_matches?(SecureRandom.urlsafe_base64(32))
  end

  test "challenge is active before expiry and expired at the boundary" do
    now = Time.zone.parse("2026-07-10 12:00:00")
    issued = ClientEmailCeremonyTransaction.issue_evp_challenge!(
      actor_ref: "client-3",
      session_ref: "session-3",
      operation: "registration",
      email_candidate_ref: "email-3",
      normalized_email_digest: "email-digest-3",
      now: now,
    )

    assert issued.transaction.evp_challenge_pending?(now: now + 9.minutes + 59.seconds)
    assert_not issued.transaction.evp_challenge_expired?(now: now + 9.minutes + 59.seconds)
    assert_not issued.transaction.evp_challenge_pending?(now: now + 10.minutes)
    assert issued.transaction.evp_challenge_expired?(now: now + 10.minutes)
  end

  test "verified transition consumes the challenge without consuming the ceremony result" do
    now = Time.zone.parse("2026-07-10 12:00:00")
    issued = ClientEmailCeremonyTransaction.issue_evp_challenge!(
      actor_ref: "client-4",
      session_ref: "session-4",
      operation: "registration",
      email_candidate_ref: "email-4",
      normalized_email_digest: "email-digest-4",
      now: now,
    )

    transaction = issued.transaction.record_evp_verified!(
      token: "evt-token-4",
      issuer: "accounts.example.com",
      issued_at: now + 1.minute,
      now: now + 2.minutes,
    )

    assert_equal "verified", transaction.evp_outcome
    assert_equal "accounts.example.com", transaction.evp_issuer
    assert_equal now + 1.minute, transaction.evp_issued_at
    assert_equal now + 2.minutes, transaction.evp_verified_at
    assert_equal now + 2.minutes, transaction.evp_consumed_at
    assert_equal 1, transaction.evp_attempt_count
    assert_predicate transaction.evp_token_digest, :present?
    assert_equal EmailCeremonyTransactionable::STATUS_PENDING, transaction.status
    assert_nil transaction.consumed_at
    assert_nil transaction.result_jti
  end

  test "fallback consumes the EVP challenge while preserving the OTP ceremony" do
    now = Time.zone.parse("2026-07-10 12:00:00")
    issued = ClientEmailCeremonyTransaction.issue_evp_challenge!(
      actor_ref: "client-5",
      session_ref: "session-5",
      operation: "replacement",
      email_candidate_ref: "email-5",
      normalized_email_digest: "email-digest-5",
      now: now,
    )

    transaction = issued.transaction.record_evp_fallback!(
      failure_reason: "missing_token",
      now: now + 1.minute,
    )

    assert_equal "fallback", transaction.evp_outcome
    assert_equal "missing_token", transaction.evp_failure_reason
    assert_equal 0, transaction.evp_attempt_count
    assert_nil transaction.evp_token_digest
    assert_equal EmailCeremonyTransactionable::STATUS_PENDING, transaction.status
    assert_nil transaction.consumed_at
  end

  test "rejected transition stores only safe evidence" do
    now = Time.zone.parse("2026-07-10 12:00:00")
    issued = OperatorEmailCeremonyTransaction.issue_evp_challenge!(
      actor_ref: "operator-1",
      session_ref: "session-6",
      operation: "registration",
      email_candidate_ref: "email-6",
      normalized_email_digest: "email-digest-6",
      now: now,
    )

    transaction = issued.transaction.record_evp_rejected!(
      token: "evt-token-6",
      failure_reason: "signature_failure",
      now: now + 1.minute,
    )

    assert_equal "rejected", transaction.evp_outcome
    assert_equal "signature_failure", transaction.evp_failure_reason
    assert_equal 1, transaction.evp_attempt_count
    assert_not_equal "evt-token-6", transaction.evp_token_digest
  end

  test "terminal challenge cannot transition again" do
    issued = ClientEmailCeremonyTransaction.issue_evp_challenge!(
      actor_ref: "client-7",
      session_ref: "session-7",
      operation: "registration",
      email_candidate_ref: "email-7",
      normalized_email_digest: "email-digest-7",
    )
    issued.transaction.record_evp_fallback!(failure_reason: "network_timeout")

    assert_raises(EmailVerificationChallengeable::StateError) do
      issued.transaction.record_evp_verified!(
        token: "evt-token-7",
        issuer: "accounts.example.com",
        issued_at: Time.current,
      )
    end
  end

  test "expired challenge cannot transition" do
    now = Time.zone.parse("2026-07-10 12:00:00")
    issued = ClientEmailCeremonyTransaction.issue_evp_challenge!(
      actor_ref: "client-8",
      session_ref: "session-8",
      operation: "registration",
      email_candidate_ref: "email-8",
      normalized_email_digest: "email-digest-8",
      now: now,
    )

    assert_raises(EmailVerificationChallengeable::ExpiredError) do
      issued.transaction.record_evp_fallback!(
        failure_reason: "expired_token",
        now: now + 10.minutes,
      )
    end
  end

  test "a token digest cannot be consumed by two challenges" do
    first = ClientEmailCeremonyTransaction.issue_evp_challenge!(
      actor_ref: "client-9",
      session_ref: "session-9",
      operation: "registration",
      email_candidate_ref: "email-9",
      normalized_email_digest: "email-digest-9",
    )
    second = ClientEmailCeremonyTransaction.issue_evp_challenge!(
      actor_ref: "client-10",
      session_ref: "session-10",
      operation: "registration",
      email_candidate_ref: "email-10",
      normalized_email_digest: "email-digest-10",
    )
    first.transaction.record_evp_rejected!(token: "replayed-token", failure_reason: "signature_failure")

    assert_raises(EmailVerificationChallengeable::ReplayError) do
      second.transaction.record_evp_rejected!(token: "replayed-token", failure_reason: "replay_detected")
    end
    assert_equal "pending", second.transaction.reload.evp_outcome
  end

  test "invalid outcome metadata is rejected" do
    issued = ClientEmailCeremonyTransaction.issue_evp_challenge!(
      actor_ref: "client-11",
      session_ref: "session-11",
      operation: "registration",
      email_candidate_ref: "email-11",
      normalized_email_digest: "email-digest-11",
    )
    transaction = issued.transaction

    transaction.evp_outcome = "fallback"
    transaction.evp_failure_reason = "internal_exception_message"
    transaction.evp_consumed_at = Time.current

    assert_not transaction.valid?
    assert_includes transaction.errors.details[:evp_failure_reason],
                    { error: :inclusion, value: "internal_exception_message" }
  end

  test "legacy email ceremony transaction remains valid without EVP state" do
    transaction = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: "client-12",
      session_ref: "session-12",
      operation: "registration",
      email_candidate_ref: "email-12",
      normalized_email_digest: "email-digest-12",
    )

    assert_predicate transaction, :valid?
    assert_nil transaction.evp_outcome
    assert_equal 0, transaction.evp_attempt_count
  end

  test "EVP metadata cannot exist without an outcome" do
    transaction = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: "client-13",
      session_ref: "session-13",
      operation: "registration",
      email_candidate_ref: "email-13",
      normalized_email_digest: "email-digest-13",
    )

    transaction.evp_nonce_digest = "orphaned-digest"

    assert_not transaction.valid?
    assert_includes transaction.errors.details[:evp_outcome], { error: :blank }
  end

  test "verified EVP issued_at cannot be after verification" do
    now = Time.zone.parse("2026-07-10 12:00:00")
    issued = ClientEmailCeremonyTransaction.issue_evp_challenge!(
      actor_ref: "client-14",
      session_ref: "session-14",
      operation: "registration",
      email_candidate_ref: "email-14",
      normalized_email_digest: "email-digest-14",
      now: now,
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      issued.transaction.record_evp_verified!(
        token: "evt-token-14",
        issuer: "accounts.example.com",
        issued_at: now + 3.minutes,
        now: now + 2.minutes,
      )
    end
    assert_equal "pending", issued.transaction.reload.evp_outcome
  end

  test "EVP transaction schema has no raw token nonce or email columns" do
    forbidden_columns = %w(evp_token evp_nonce raw_token raw_nonce email address)

    assert_empty ClientEmailCeremonyTransaction.column_names & forbidden_columns
    assert_empty OperatorEmailCeremonyTransaction.column_names & forbidden_columns
  end

  test "recording a verified outcome requires a token an issuer and an issue time" do
    transaction = issue_challenge("argument-guard")

    assert_raises(ArgumentError, "blank token must be refused") do
      transaction.record_evp_verified!(token: "", issuer: "accounts.example.com", issued_at: Time.current)
    end
    assert_raises(ArgumentError, "blank issuer must be refused") do
      transaction.record_evp_verified!(token: "evt-token", issuer: "", issued_at: Time.current)
    end
    assert_raises(ArgumentError, "blank issued_at must be refused") do
      transaction.record_evp_verified!(token: "evt-token", issuer: "accounts.example.com", issued_at: nil)
    end
    assert_equal "pending", transaction.reload.evp_outcome
  end

  test "recording a rejected outcome requires the token that was rejected" do
    transaction = issue_challenge("rejected-guard")

    assert_raises(ArgumentError) do
      transaction.record_evp_rejected!(token: nil, failure_reason: "malformed_token")
    end
    assert_equal "pending", transaction.reload.evp_outcome
  end

  test "an outcome without a nonce digest is inconsistent" do
    transaction = issue_challenge("nonce-digest")
    transaction.evp_nonce_digest = nil

    assert_not_predicate transaction, :valid?
    assert_includes transaction.errors[:evp_nonce_digest], "must be present"
  end

  test "a pending challenge must not carry a consumption time" do
    transaction = issue_challenge("pending-consumed")
    transaction.evp_consumed_at = Time.current

    assert_not_predicate transaction, :valid?
    assert_includes transaction.errors[:evp_consumed_at], "must be blank"
  end

  test "a terminal outcome must carry a consumption time" do
    transaction = issue_challenge("terminal-consumed")
    transaction.assign_attributes(
      evp_outcome: EmailVerificationChallengeable::OUTCOME_VERIFIED,
      evp_consumed_at: nil,
      evp_token_digest: "digest",
      evp_issuer: "accounts.example.com",
      evp_issued_at: Time.current,
      evp_verified_at: Time.current,
    )

    assert_not_predicate transaction, :valid?
    assert_includes transaction.errors[:evp_consumed_at], "must be present"
  end

  test "a verified outcome requires the full issuance record" do
    transaction = issue_challenge("verified-incomplete")
    transaction.assign_attributes(
      evp_outcome: EmailVerificationChallengeable::OUTCOME_VERIFIED,
      evp_consumed_at: Time.current,
      evp_token_digest: nil,
      evp_issuer: nil,
      evp_issued_at: nil,
      evp_verified_at: nil,
    )

    assert_not_predicate transaction, :valid?
    assert_includes transaction.errors[:evp_token_digest], "must be present"
    assert_includes transaction.errors[:evp_issuer], "must be present"
    assert_includes transaction.errors[:evp_issued_at], "must be present"
    assert_includes transaction.errors[:evp_verified_at], "must be present"
  end

  test "a verified outcome must not carry a failure reason" do
    now = Time.current
    transaction = issue_challenge("verified-failure-reason")
    transaction.assign_attributes(
      evp_outcome: EmailVerificationChallengeable::OUTCOME_VERIFIED,
      evp_consumed_at: now,
      evp_token_digest: "digest",
      evp_issuer: "accounts.example.com",
      evp_issued_at: now,
      evp_verified_at: now,
      evp_failure_reason: "malformed_token",
    )

    assert_not_predicate transaction, :valid?
    assert_includes transaction.errors[:evp_failure_reason], "must be blank"
  end

  test "a fallback outcome requires a failure reason and no issuance record" do
    now = Time.current
    transaction = issue_challenge("fallback-inconsistent")
    transaction.assign_attributes(
      evp_outcome: EmailVerificationChallengeable::OUTCOME_FALLBACK,
      evp_consumed_at: now,
      evp_failure_reason: nil,
      evp_issuer: "accounts.example.com",
      evp_issued_at: now,
      evp_verified_at: now,
    )

    assert_not_predicate transaction, :valid?
    assert_includes transaction.errors[:evp_failure_reason], "must be present"
    assert_includes transaction.errors[:evp_issuer], "must be blank"
    assert_includes transaction.errors[:evp_issued_at], "must be blank"
    assert_includes transaction.errors[:evp_verified_at], "must be blank"
  end

  test "a rejected outcome must record the digest of the token it rejected" do
    transaction = issue_challenge("rejected-digest")
    transaction.assign_attributes(
      evp_outcome: EmailVerificationChallengeable::OUTCOME_REJECTED,
      evp_consumed_at: Time.current,
      evp_failure_reason: "malformed_token",
      evp_token_digest: nil,
    )

    assert_not_predicate transaction, :valid?
    assert_includes transaction.errors[:evp_token_digest], "must be present"
  end

  private

  def issue_challenge(reference, now: Time.current)
    ClientEmailCeremonyTransaction.issue_evp_challenge!(
      actor_ref: "client-#{reference}",
      session_ref: "session-#{reference}",
      operation: "registration",
      email_candidate_ref: "email-#{reference}",
      normalized_email_digest: "email-digest-#{reference}",
      now: now,
    ).transaction
  end
end

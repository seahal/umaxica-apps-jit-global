# typed: false
# frozen_string_literal: true

require "test_helper"

# Result issuance binds the Acme grant to the Sign-side callback. Every
# mismatch (surface, actor, session, operation, provider, jti, expiry,
# consumption, unverified callback) must fail closed before a result token
# is minted.
class IdentitySocialCeremonyResultIssuerTest < ActiveSupport::TestCase
  setup do
    @now = Time.zone.parse("2026-06-24 12:00:00 UTC")
    @transaction = FakeTransaction.new
  end

  test "issues a result token bound to the grant, candidate, and transaction" do
    captured = nil
    authentication_event_at = @now - 2.minutes

    with_ceremony(issue: ->(claims, **) { captured = claims; "issued-token" }) do
      result = issuer(callback_result: verified_callback(verified_at: authentication_event_at)).issue!

      assert_equal "issued-token", result
    end

    assert_equal "app", captured.fetch("surface")
    assert_equal "actor-1", captured.fetch("actor_ref")
    assert_equal "session-1", captured.fetch("session_ref")
    assert_equal "txn-1", captured.fetch("transaction_id")
    assert_equal "grant-1", captured.fetch("grant_jti")
    assert_equal "signup", captured.fetch("operation")
    assert_equal "google", captured.fetch("provider")
    assert_equal "cand-ref", captured.fetch("candidate_ref")
    assert_equal "cand-digest", captured.fetch("candidate_digest")
    assert_equal "1990-01-01", captured.fetch("birthdate")
    assert_equal "explicit-challenge", captured.fetch("challenge_id")
    assert_equal authentication_event_at.to_i, captured.fetch("auth_time")
    assert_equal @now.to_i, captured.fetch("verified_at")
    assert_kind_of String, captured.fetch("result_jti")
  end

  test "stores a candidate when none is supplied and falls back to the transaction id as challenge" do
    captured = nil
    stored = IdentitySocialCeremonyCandidateStore::Candidate.new(
      ref: "stored-ref",
      digest: "stored-digest",
      surface: "app",
      actor_ref: "actor-1",
      session_ref: "session-1",
      transaction_id: "txn-1",
      operation: "signup",
      provider: "google",
      callback_result: verified_callback,
      expires_at: @transaction.expires_at,
    )

    with_ceremony(issue: ->(claims, **) { captured = claims; "issued-token" }) do
      IdentitySocialCeremonyCandidateStore.stub(:store!, stored) do
        issuer(candidate: nil, challenge_id: nil).issue!
      end
    end

    assert_equal "stored-ref", captured.fetch("candidate_ref")
    assert_equal "txn-1", captured.fetch("challenge_id")
  end

  test "raises when the grant token is blank" do
    with_ceremony do
      assert_social_error("social ceremony grant is required") do
        IdentitySocialCeremonyResultIssuer.issue!(
          grant_token: "",
          callback_result: verified_callback,
          surface: "app",
          actor_ref: "actor-1",
          session_ref: "session-1",
          operation: "signup",
          now: @now,
        )
      end
    end
  end

  test "raises when the callback is not a verified result" do
    with_ceremony do
      assert_social_error("verified callback result is required") do
        issuer(callback_result: Object.new).issue!
      end
    end
  end

  test "raises when the grant surface does not match the ceremony" do
    with_ceremony(grant: valid_grant("surface" => "com")) do
      assert_social_error("grant surface does not match ceremony") { issuer.issue! }
    end
  end

  test "raises when the grant actor does not match the ceremony" do
    with_ceremony(grant: valid_grant("actor_ref" => "other")) do
      assert_social_error("grant actor does not match ceremony") { issuer.issue! }
    end
  end

  test "raises when the grant session does not match the ceremony" do
    with_ceremony(grant: valid_grant("session_ref" => "other")) do
      assert_social_error("grant session does not match ceremony") { issuer.issue! }
    end
  end

  test "raises when the grant operation does not match the ceremony" do
    with_ceremony(grant: valid_grant("operation" => "link")) do
      assert_social_error("grant operation does not match ceremony") { issuer.issue! }
    end
  end

  test "raises when the grant provider does not match the ceremony" do
    with_ceremony(grant: valid_grant("provider" => "apple")) do
      assert_social_error("grant provider does not match ceremony") { issuer.issue! }
    end
  end

  test "raises when the grant jti does not match the transaction" do
    with_ceremony(grant: valid_grant("jti" => "other")) do
      assert_social_error("grant jti does not match transaction") { issuer.issue! }
    end
  end

  test "raises when the transaction is expired" do
    with_ceremony(transaction: FakeTransaction.new(expired: true)) do
      assert_social_error("transaction is expired") { issuer.issue! }
    end
  end

  test "raises when the transaction is already consumed" do
    with_ceremony(transaction: FakeTransaction.new(consumed: true)) do
      assert_social_error("transaction is already consumed") { issuer.issue! }
    end
  end

  test "raises when the provider subject is blank" do
    callback = Object.new
    callback.define_singleton_method(:is_a?) { |klass| klass == ExternalAuthentication::CallbackResult }
    callback.define_singleton_method(:verified?) { true }
    callback.define_singleton_method(:principal) do
      Struct.new(:provider, :subject).new("google", "")
    end

    with_ceremony do
      assert_social_error("provider subject is required") { issuer(callback_result: callback).issue! }
    end
  end

  private

  def issuer(callback_result: verified_callback, candidate: valid_candidate, challenge_id: "explicit-challenge")
    IdentitySocialCeremonyResultIssuer.new(
      grant_token: "grant-token",
      callback_result: callback_result,
      surface: "app",
      actor_ref: "actor-1",
      session_ref: "session-1",
      operation: "signup",
      challenge_id: challenge_id,
      candidate: candidate,
      birthdate: "1990-01-01",
      now: @now,
    )
  end

  def with_ceremony(grant: valid_grant, transaction: @transaction, issue: ->(_claims, **) { "issued-token" })
    store = FakeStore.new(transaction)
    IdentitySocialCeremonyGrant.stub(:decode, ->(_token, **) { grant }) do
      IdentitySocialCeremonyReplayStore.stub(:for, ->(_surface) { store }) do
        IdentitySocialCeremonyResult.stub(:issue, issue) do
          yield
        end
      end
    end
  end

  def assert_social_error(message)
    error = assert_raises(IdentitySocialCeremonyContract::Error) { yield }
    assert_includes error.message, message
  end

  def valid_grant(overrides = {})
    {
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "operation" => "signup",
      "provider" => "google",
      "jti" => "grant-1",
      "transaction_id" => "txn-1",
    }.merge(overrides)
  end

  def verified_callback(verified_at: @now)
    ExternalAuthentication::CallbackResult.verified(
      principal: ExternalAuthentication::VerifiedPrincipal.new(
        provider: "google",
        subject: "uid-1",
        issuer: "https://accounts.google.com",
        audience: "google-client-id",
        verified_at: verified_at,
        verification_authority: "test",
      ),
    )
  end

  def valid_candidate
    IdentitySocialCeremonyCandidateStore::Candidate.new(
      ref: "cand-ref",
      digest: "cand-digest",
      surface: "app",
      actor_ref: "actor-1",
      session_ref: "session-1",
      transaction_id: "txn-1",
      operation: "signup",
      provider: "google",
      callback_result: verified_callback,
      expires_at: @transaction.expires_at,
    )
  end

  class FakeStore
    def initialize(transaction)
      @transaction = transaction
    end

    def find_transaction!(_transaction_id)
      @transaction
    end
  end

  class FakeTransaction
    attr_reader :transaction_id, :grant_jti, :expires_at

    def initialize(expired: false, consumed: false)
      @transaction_id = "txn-1"
      @grant_jti = "grant-1"
      @expires_at = Time.zone.parse("2026-06-24 12:10:00 UTC")
      @expired = expired
      @consumed = consumed
    end

    def expired?(*)
      @expired
    end

    def consumed?
      @consumed
    end
  end
end

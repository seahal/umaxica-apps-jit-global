# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentitySecretCredentialCeremonyResultIssuerTest < ActiveSupport::TestCase
  setup do
    @now = Time.zone.parse("2026-06-24 12:00:00 UTC")
    @transaction = FakeTransaction.new
  end

  test "issues a result token with claims bound to the candidate and transaction" do
    captured = nil

    with_ceremony(
      issue: ->(claims, **) {
        captured = claims
        "issued-token"
      },
    ) do
      result = issuer.issue!

      assert_equal "issued-token", result
    end

    assert_equal "app", captured.fetch("surface")
    assert_equal "actor-1", captured.fetch("actor_ref")
    assert_equal "session-1", captured.fetch("session_ref")
    assert_equal "txn-1", captured.fetch("transaction_id")
    assert_equal "grant-1", captured.fetch("grant_jti")
    assert_equal "registration", captured.fetch("operation")
    assert_equal @now.to_i, captured.fetch("verified_at")
    assert_equal @transaction.expires_at.to_i, captured.fetch("expires_at")
    assert_equal "candidate-1", captured.fetch("challenge_id")
    assert_equal "candidate-1", captured.fetch("credential_candidate_ref")
    assert_equal "digest-1", captured.fetch("credential_candidate_digest")
    assert_equal "API Key", captured.fetch("name")
    assert_kind_of String, captured.fetch("result_jti")
  end

  test "uses the supplied challenge id when present" do
    captured = nil

    with_ceremony(
      issue: ->(claims, **) {
        captured = claims
        "issued-token"
      },
    ) do
      issuer(challenge_id: "explicit-challenge").issue!
    end

    assert_equal "explicit-challenge", captured.fetch("challenge_id")
  end

  test "raises when the candidate is blank" do
    with_ceremony do
      assert_secret_error("candidate is required") { issuer(candidate: nil).issue! }
    end
  end

  test "raises when the grant token is blank" do
    with_ceremony do
      assert_secret_error("secret credential ceremony grant is required") do
        IdentitySecretCredentialCeremonyResultIssuer.issue!(
          grant_token: "",
          candidate: valid_candidate,
          surface: "app",
          actor_ref: "actor-1",
          session_ref: "session-1",
          operation: "registration",
          now: @now,
        )
      end
    end
  end

  test "raises when the grant surface does not match the ceremony" do
    with_ceremony(grant: valid_grant("surface" => "com")) do
      assert_secret_error("grant surface does not match ceremony") { issuer.issue! }
    end
  end

  test "raises when the grant actor does not match the ceremony" do
    with_ceremony(grant: valid_grant("actor_ref" => "other")) do
      assert_secret_error("grant actor does not match ceremony") { issuer.issue! }
    end
  end

  test "raises when the grant session does not match the ceremony" do
    with_ceremony(grant: valid_grant("session_ref" => "other")) do
      assert_secret_error("grant session does not match ceremony") { issuer.issue! }
    end
  end

  test "raises when the grant operation does not match the ceremony" do
    with_ceremony(grant: valid_grant("operation" => "deletion")) do
      assert_secret_error("grant operation does not match ceremony") { issuer.issue! }
    end
  end

  test "raises when the grant jti does not match the transaction" do
    with_ceremony(grant: valid_grant("jti" => "other")) do
      assert_secret_error("grant jti does not match transaction") { issuer.issue! }
    end
  end

  test "raises when the transaction is expired" do
    with_ceremony(transaction: FakeTransaction.new(expired: true)) do
      assert_secret_error("transaction is expired") { issuer.issue! }
    end
  end

  test "raises when the transaction is already consumed" do
    with_ceremony(transaction: FakeTransaction.new(consumed: true)) do
      assert_secret_error("transaction is already consumed") { issuer.issue! }
    end
  end

  test "raises when the candidate surface does not match the ceremony" do
    with_ceremony do
      assert_secret_error("candidate surface does not match ceremony") {
        issuer(candidate: valid_candidate(surface: "com")).issue!
      }
    end
  end

  test "raises when the candidate actor does not match the ceremony" do
    with_ceremony do
      assert_secret_error("candidate actor does not match ceremony") {
        issuer(candidate: valid_candidate(actor_ref: "other")).issue!
      }
    end
  end

  test "raises when the candidate session does not match the ceremony" do
    with_ceremony do
      assert_secret_error("candidate session does not match ceremony") {
        issuer(candidate: valid_candidate(session_ref: "other")).issue!
      }
    end
  end

  test "raises when the candidate transaction does not match the ceremony" do
    with_ceremony do
      assert_secret_error("candidate transaction does not match ceremony") {
        issuer(candidate: valid_candidate(transaction_id: "other")).issue!
      }
    end
  end

  test "raises when the candidate operation does not match the ceremony" do
    with_ceremony do
      assert_secret_error("candidate operation does not match ceremony") {
        issuer(candidate: valid_candidate(operation: "deletion")).issue!
      }
    end
  end

  private

  def issuer(challenge_id: nil, candidate: valid_candidate)
    IdentitySecretCredentialCeremonyResultIssuer.new(
      grant_token: "grant-token",
      candidate: candidate,
      surface: "app",
      actor_ref: "actor-1",
      session_ref: "session-1",
      operation: "registration",
      challenge_id: challenge_id,
      now: @now,
    )
  end

  def with_ceremony(grant: valid_grant, transaction: @transaction, issue: ->(_claims, **) { "issued-token" })
    store = FakeStore.new(transaction)
    IdentitySecretCredentialCeremonyGrant.stub(:decode, ->(_token, **) { grant }) do
      IdentitySecretCredentialCeremonyReplayStore.stub(:for, ->(_surface) { store }) do
        IdentitySecretCredentialCeremonyResult.stub(:issue, issue) do
          yield
        end
      end
    end
  end

  def assert_secret_error(message)
    error = assert_raises(IdentitySecretCredentialCeremonyContract::Error) { yield }
    assert_includes error.message, message
  end

  def valid_grant(overrides = {})
    {
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "operation" => "registration",
      "jti" => "grant-1",
      "transaction_id" => "txn-1",
    }.merge(overrides)
  end

  def valid_candidate(overrides = {})
    SecretCandidate.new(
      surface: "app",
      actor_ref: "actor-1",
      session_ref: "session-1",
      transaction_id: "txn-1",
      operation: "registration",
      ref: "candidate-1",
      digest: "digest-1",
      name: "API Key",
      **overrides,
    )
  end

  SecretCandidate = Data.define(
    :surface, :actor_ref, :session_ref, :transaction_id, :operation,
    :ref, :digest, :name,
  )

  class FakeStore
    def initialize(transaction)
      @transaction = transaction
    end

    def find_transaction!(_transaction_id)
      @transaction
    end
  end

  class FakeTransaction
    attr_reader :surface, :actor_ref, :session_ref, :operation, :transaction_id, :grant_jti, :expires_at

    def initialize(expired: false, consumed: false)
      @surface = "app"
      @actor_ref = "actor-1"
      @session_ref = "session-1"
      @operation = "registration"
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

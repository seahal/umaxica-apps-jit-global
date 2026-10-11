# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityTelephoneCeremonyTransactionCoverageTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  teardown do
    travel_back
  end

  test "builds defaults, grants claims, and consumes into a new transaction" do
    created_at = Time.zone.local(2026, 1, 2, 3, 4, 5)

    travel_to(created_at) do
      transaction =
        IdentityTelephoneCeremonyTransaction.new(
          surface: "app",
          actor_ref: "actor-1",
          session_ref: "session-1",
          operation: "registration",
          telephone_candidate_ref: "candidate-1",
          normalized_number_digest: "digest-1",
          created_at: created_at,
        )

      assert_equal created_at + IdentityTelephoneCeremonyTransaction::DEFAULT_TTL, transaction.expires_at
      assert_not_predicate transaction, :consumed?
      assert_not transaction.expired?(now: created_at)
      assert transaction.expired?(now: transaction.expires_at)
      assert_equal "app", transaction.grant_claims["surface"]
      assert_equal "actor-1", transaction.grant_claims["actor_ref"]
      assert_equal "candidate-1", transaction.grant_claims["telephone_candidate_ref"]
      assert_equal "digest-1", transaction.grant_claims["normalized_number_digest"]

      consumed = transaction.consume(result_jti: "result-1", consumed_at: created_at + 1.minute)

      assert_predicate consumed, :consumed?
      assert_equal "result-1", consumed.result_jti
      assert_equal created_at + 1.minute, consumed.consumed_at
      assert_equal transaction.transaction_id, consumed.transaction_id
    end
  end

  test "rejects invalid surface, invalid operation, missing bindings, and consumed without result jti" do
    assert_raises(IdentityTelephoneCeremony::Error) do
      IdentityTelephoneCeremonyTransaction.new(
        surface: "invalid",
        actor_ref: "actor-1",
        session_ref: "session-1",
        operation: "registration",
      )
    end

    assert_raises(IdentityTelephoneCeremony::Error) do
      IdentityTelephoneCeremonyTransaction.new(
        surface: "app",
        actor_ref: "actor-1",
        session_ref: "session-1",
        operation: "invalid",
      )
    end

    assert_raises(IdentityTelephoneCeremony::Error) do
      IdentityTelephoneCeremonyTransaction.new(
        surface: "app",
        actor_ref: "",
        session_ref: "session-1",
        operation: "registration",
      )
    end

    assert_raises(IdentityTelephoneCeremony::Error) do
      IdentityTelephoneCeremonyTransaction.new(
        surface: "app",
        actor_ref: "actor-1",
        session_ref: "",
        operation: "registration",
      )
    end

    assert_raises(IdentityTelephoneCeremony::Error) do
      IdentityTelephoneCeremonyTransaction.new(
        surface: "app",
        actor_ref: "actor-1",
        session_ref: "session-1",
        operation: "registration",
        status: IdentityTelephoneCeremonyTransaction::STATUS_CONSUMED,
      )
    end
  end

  test "rejects blank ids, blank grant jti, and an unknown status" do
    assert_raises(IdentityTelephoneCeremony::Error) do
      IdentityTelephoneCeremonyTransaction.new(
        surface: "app",
        actor_ref: "actor-1",
        session_ref: "session-1",
        operation: "registration",
        transaction_id: "",
      )
    end

    assert_raises(IdentityTelephoneCeremony::Error) do
      IdentityTelephoneCeremonyTransaction.new(
        surface: "app",
        actor_ref: "actor-1",
        session_ref: "session-1",
        operation: "registration",
        grant_jti: "",
      )
    end

    assert_raises(IdentityTelephoneCeremony::Error) do
      IdentityTelephoneCeremonyTransaction.new(
        surface: "app",
        actor_ref: "actor-1",
        session_ref: "session-1",
        operation: "registration",
        status: "bogus",
      )
    end
  end
end

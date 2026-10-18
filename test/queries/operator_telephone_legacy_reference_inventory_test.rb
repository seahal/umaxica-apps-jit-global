# frozen_string_literal: true

require "test_helper"

class OperatorTelephoneLegacyReferenceInventoryTest < ActiveSupport::TestCase
  test "legacy inventory counts an issued numeric-bound registration without changing proof facts" do
    ceremony = OperatorTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: "synthetic-operator", session_ref: SecureRandom.uuid, operation: "registration",
      telephone_candidate_ref: "123", normalized_number_digest: "a" * 64,
      now: OperatorTelephoneCeremonyTransaction.database_now,
    )
    ceremony.issue_telephone_otp!(purpose: "credential_registration")
    before = ceremony.reload.attributes

    result = OperatorTelephoneLegacyReferenceInventory.call(
      scope: OperatorTelephoneCeremonyTransaction.where(id: ceremony.id),
    )

    assert_equal 1, result.fetch(:pending_ceremonies)
    assert_equal 1, result.fetch(:deliverable_proofs)
    assert_equal 0, result.fetch(:unexpired_receipts)
    assert_equal before, ceremony.reload.attributes
    assert_predicate result, :frozen?
  end

  test "consumed legacy receipt remains counted after challenge expiry until its exact receipt deadline" do
    start = Time.utc(2030, 1, 1)
    ceremony = OperatorTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: "synthetic-operator", session_ref: SecureRandom.uuid, operation: "registration",
      telephone_candidate_ref: "456", normalized_number_digest: "b" * 64, now: start,
    )
    code =
      OperatorTelephoneCeremonyTransaction.stub(:database_now, start) do
        ceremony.issue_telephone_otp!(purpose: "credential_registration")
      end

    OperatorTelephoneCeremonyTransaction.stub(:database_now, start + 299.seconds) do
      assert ceremony.verify_telephone_otp!(
        code: code, purpose: "credential_registration", actor_ref: ceremony.actor_ref,
        session_ref: ceremony.session_ref, operation: "registration", candidate_ref: "456",
      )
    end
    before = ceremony.reload.attributes
    deadline = ceremony.otp_result_expires_at
    [start + 301.seconds, deadline - Rational(1, 1_000_000), deadline, deadline + Rational(1, 1_000_000)].each do |at|
      result =
        OperatorTelephoneCeremonyTransaction.stub(:database_now, at) do
          OperatorTelephoneLegacyReferenceInventory.call(
            scope: OperatorTelephoneCeremonyTransaction.where(id: ceremony.id),
          )
        end

      assert_equal((at < deadline) ? 1 : 0, result.fetch(:unexpired_receipts))
      assert_equal 0, result.fetch(:deliverable_proofs)
      assert_equal before, ceremony.reload.attributes
    end
  end

  test "current public candidate is excluded and legacy pending parent expires at its exact deadline" do
    start = Time.utc(2030, 1, 1)
    current = OperatorTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: "synthetic-operator", session_ref: SecureRandom.uuid, operation: "registration",
      telephone_candidate_ref: "1" * 21, normalized_number_digest: "c" * 64, now: start,
    )
    legacy = OperatorTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: "synthetic-operator", session_ref: SecureRandom.uuid, operation: "registration",
      telephone_candidate_ref: "789", normalized_number_digest: "d" * 64, now: start,
    )
    scope = OperatorTelephoneCeremonyTransaction.where(id: [current.id, legacy.id])
    [legacy.expires_at - Rational(1, 1_000_000), legacy.expires_at,
     legacy.expires_at + Rational(1, 1_000_000),].each do |at|
      result =
        OperatorTelephoneCeremonyTransaction.stub(:database_now, at) do
          OperatorTelephoneLegacyReferenceInventory.call(scope: scope)
        end

      assert_equal((at < legacy.expires_at) ? 1 : 0, result.fetch(:pending_ceremonies))
      assert_equal 0, result.fetch(:deliverable_proofs)
      assert_equal 0, result.fetch(:unexpired_receipts)
    end
  end

  test "inventory refuses absent and other realm or channel scopes" do
    [nil, ClientTelephoneCeremonyTransaction.all, VisitorTelephoneCeremonyTransaction.all,
     OperatorEmailCeremonyTransaction.all, OperatorTelephone.all,].each do |scope|
      assert_raises(ArgumentError) { OperatorTelephoneLegacyReferenceInventory.call(scope: scope) }
    end
  end
end

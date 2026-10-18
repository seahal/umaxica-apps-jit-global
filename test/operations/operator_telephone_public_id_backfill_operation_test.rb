# frozen_string_literal: true

require "test_helper"

class OperatorTelephonePublicIdBackfillOperationTest < ActiveSupport::TestCase
  # NULL-only assignment, savepoint collision recovery and exhaustion were exercised against the
  # pre-cutover nullable schema and are recorded in evidence/2026-10-11-org-telephone-identity-backfill-K6V2.md.
  # The final NOT NULL contract makes those legacy rows unconstructable in the current schema;
  # these tests protect the post-cutover no-op and idempotency behavior of the retained operation.
  test "post-cutover backfill is a no-op and preserves source and ceremony facts" do
    actor = Operator.create!(status_id: OperatorStatus::ACTIVE)
    telephone = actor.staff_telephones.create!(
      raw_number: "+12025550171", confirm_policy: true, confirm_using_mfa: true,
    )
    before = telephone.reload.attributes
    ceremony = OperatorTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: SecureRandom.uuid, operation: "registration",
      telephone_candidate_ref: telephone.id.to_s, normalized_number_digest: telephone.number_digest,
      now: OperatorTelephoneCeremonyTransaction.database_now,
    )
    ceremony.issue_telephone_otp!(purpose: "credential_registration")
    ceremony_facts = ceremony.reload.attributes
    scope = OperatorTelephone.where(id: telephone.id)

    result = OperatorTelephonePublicIdBackfillOperation.call(scope: scope, dry_run: false, batch_size: 1)

    assert_equal 0, result.fetch(:assigned)
    assert_equal 0, result.fetch(:missing)
    assert_equal before, telephone.reload.attributes
    repeated = OperatorTelephonePublicIdBackfillOperation.call(scope: scope, dry_run: false, batch_size: 1)

    assert_equal 0, repeated.fetch(:assigned)
    assert_equal before, telephone.reload.attributes
    assert_equal ceremony_facts, ceremony.reload.attributes
    assert ceremony.telephone_otp_deliverable?(
      generation: ceremony.otp_generation, at: OperatorTelephoneCeremonyTransaction.database_now,
    )
  end

  test "dry run reports no missing identities without generating or persisting one" do
    actor = Operator.create!(status_id: OperatorStatus::ACTIVE)
    telephone = actor.staff_telephones.create!(
      raw_number: "+12025550174", confirm_policy: true, confirm_using_mfa: true,
    )
    before = telephone.reload.attributes
    calls = 0
    generator =
      lambda do |**|
        calls += 1
        raise RuntimeError, "unexpected post-cutover generation"
      end

    result =
      Nanoid.stub(:generate, generator) do
        OperatorTelephonePublicIdBackfillOperation.call(
          scope: OperatorTelephone.where(id: telephone.id), dry_run: true, batch_size: 1,
        )
      end

    assert_equal 0, result.fetch(:missing)
    assert_equal 0, result.fetch(:assigned)
    assert_equal 0, calls
    assert_equal before, telephone.reload.attributes
  end

  test "post-cutover apply never regenerates an existing public identity" do
    actor = Operator.create!(status_id: OperatorStatus::ACTIVE)
    telephone = actor.staff_telephones.create!(
      raw_number: "+12025550175", confirm_policy: true, confirm_using_mfa: true,
    )
    original = telephone.public_id

    calls = 0
    generator =
      lambda do |**|
        calls += 1
        raise RuntimeError, "unexpected post-cutover generation"
      end
    result =
      Nanoid.stub(:generate, generator) do
        OperatorTelephonePublicIdBackfillOperation.call(
          scope: OperatorTelephone.where(id: telephone.id), dry_run: false, batch_size: 1,
        )
      end

    assert_equal 0, result.fetch(:assigned)
    assert_equal 0, result.fetch(:missing)
    assert_equal 0, calls
    assert_equal original, telephone.reload.public_id
  end

  test "backfill rejects invalid batch boundaries and non-ORG source scopes before writing" do
    [nil, 0, -1, 1001, "1", false].each do |size|
      assert_raises(ArgumentError) do
        OperatorTelephonePublicIdBackfillOperation.call(
          scope: OperatorTelephone.all, dry_run: true, batch_size: size,
        )
      end
    end
    [nil, ClientTelephone.all, VisitorTelephone.all].each do |scope|
      assert_raises(ArgumentError) do
        OperatorTelephonePublicIdBackfillOperation.call(scope: scope, dry_run: false, batch_size: 1)
      end
    end
    [nil, "true", 0].each do |dry_run|
      assert_raises(ArgumentError) do
        OperatorTelephonePublicIdBackfillOperation.call(
          scope: OperatorTelephone.all, dry_run: dry_run, batch_size: 1,
        )
      end
    end
    result = OperatorTelephonePublicIdBackfillOperation.call(
      scope: OperatorTelephone.none, dry_run: true, batch_size: 1000,
    )

    assert_equal 0, result.fetch(:missing)
  end
end

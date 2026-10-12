# frozen_string_literal: true

require "test_helper"

class OperatorTelephonePublicIdBackfillOperationTest < ActiveSupport::TestCase
  test "backfill supplies only missing public identities and preserves source and ceremony facts on retry" do
    actor = Operator.create!(status_id: OperatorStatus::ACTIVE)
    missing = actor.staff_telephones.build(
      raw_number: "+12025550171", confirm_policy: true, confirm_using_mfa: true,
    )

    assert_predicate missing, :valid?
    inserted = OperatorTelephone.insert_all!(
      [missing.attributes.except("id", "created_at", "updated_at").merge("public_id" => nil)],
    )
    missing = OperatorTelephone.find(inserted.rows.first.first)
    existing = actor.staff_telephones.create!(
      raw_number: "+12025550172", confirm_policy: true, confirm_using_mfa: true,
    )
    before = missing.reload.attributes.except("public_id")
    old_identity = existing.public_id
    ceremony = OperatorTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: SecureRandom.uuid, operation: "registration",
      telephone_candidate_ref: missing.id.to_s, normalized_number_digest: missing.number_digest,
      now: OperatorTelephoneCeremonyTransaction.database_now,
    )
    ceremony.issue_telephone_otp!(purpose: "credential_registration")
    ceremony_facts = ceremony.reload.attributes
    scope = OperatorTelephone.where(id: [missing.id, existing.id])

    result = OperatorTelephonePublicIdBackfillOperation.call(scope: scope, dry_run: false, batch_size: 1)

    assert_equal 1, result.fetch(:assigned)
    assert_equal 0, result.fetch(:missing)
    assert_match(/\A[A-Za-z0-9_-]{21}\z/, missing.reload.public_id)
    assert_equal before, missing.attributes.except("public_id")
    assert_equal old_identity, existing.reload.public_id
    assigned = missing.public_id
    repeated = OperatorTelephonePublicIdBackfillOperation.call(scope: scope, dry_run: false, batch_size: 1)

    assert_equal 0, repeated.fetch(:assigned)
    assert_equal assigned, missing.reload.public_id
    assert_equal old_identity, existing.reload.public_id
    assert_equal ceremony_facts, ceremony.reload.attributes
    assert ceremony.telephone_otp_deliverable?(
      generation: ceremony.otp_generation, at: OperatorTelephoneCeremonyTransaction.database_now,
    )
  end

  test "internally generated public identity collision retries after the database savepoint recovers" do
    actor = Operator.create!(status_id: OperatorStatus::ACTIVE)
    occupied = actor.staff_telephones.create!(
      raw_number: "+12025550174", confirm_policy: true, confirm_using_mfa: true,
    )
    missing = actor.staff_telephones.build(
      raw_number: "+12025550175", confirm_policy: true, confirm_using_mfa: true,
    )

    assert_predicate missing, :valid?
    inserted = OperatorTelephone.insert_all!(
      [missing.attributes.except("id", "created_at", "updated_at").merge("public_id" => nil)],
    )
    missing = OperatorTelephone.find(inserted.rows.first.first)
    calls = 0
    generator =
      lambda do |size:, non_secure:|
        assert_equal 21, size
        assert_instance_of FalseClass, non_secure
        calls += 1
        (calls == 1) ? occupied.public_id : "x" * 21
      end
    result =
      Nanoid.stub(:generate, generator) do
        OperatorTelephonePublicIdBackfillOperation.call(
          scope: OperatorTelephone.where(id: missing.id), dry_run: false, batch_size: 1,
        )
      end

    assert_equal 1, result.fetch(:assigned)
    assert_equal 2, calls
    assert_equal "x" * 21, missing.reload.public_id
    assert_not_equal occupied.reload.public_id, missing.public_id
  end

  test "public identity collision stops at the finite retry bound and preserves the missing source" do
    actor = Operator.create!(status_id: OperatorStatus::ACTIVE)
    occupied = actor.staff_telephones.create!(
      raw_number: "+12025550176", confirm_policy: true, confirm_using_mfa: true,
    )
    missing = actor.staff_telephones.build(
      raw_number: "+12025550177", confirm_policy: true, confirm_using_mfa: true,
    )

    assert_predicate missing, :valid?
    inserted = OperatorTelephone.insert_all!(
      [missing.attributes.except("id", "created_at", "updated_at").merge("public_id" => nil)],
    )
    missing = OperatorTelephone.find(inserted.rows.first.first)
    original = missing.reload.attributes
    calls = 0
    generator =
      lambda do |size:, non_secure:|
        assert_equal 21, size
        assert_instance_of FalseClass, non_secure
        calls += 1
        occupied.public_id
      end

    assert_raises(ActiveRecord::RecordNotUnique) do
      Nanoid.stub(:generate, generator) do
        OperatorTelephonePublicIdBackfillOperation.call(
          scope: OperatorTelephone.where(id: missing.id), dry_run: false, batch_size: 1,
        )
      end
    end
    assert_equal PublicId::MAX_COLLISION_RETRIES + 1, calls
    assert_equal original, missing.reload.attributes
  end

  test "dry run reports missing identities without generating or persisting one" do
    actor = Operator.create!(status_id: OperatorStatus::ACTIVE)
    telephone = actor.staff_telephones.build(
      raw_number: "+12025550173", confirm_policy: true, confirm_using_mfa: true,
    )

    assert_predicate telephone, :valid?
    inserted = OperatorTelephone.insert_all!(
      [telephone.attributes.except("id", "created_at", "updated_at").merge("public_id" => nil)],
    )
    telephone = OperatorTelephone.find(inserted.rows.first.first)
    before = telephone.reload.attributes
    result = OperatorTelephonePublicIdBackfillOperation.call(
      scope: OperatorTelephone.where(id: telephone.id), dry_run: true, batch_size: 1,
    )

    assert_equal 1, result.fetch(:missing)
    assert_equal 0, result.fetch(:assigned)
    assert_equal before, telephone.reload.attributes
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

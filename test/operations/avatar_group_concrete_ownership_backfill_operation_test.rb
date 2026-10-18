# frozen_string_literal: true

require "test_helper"

class AvatarGroupConcreteOwnershipBackfillOperationTest < ActiveSupport::TestCase
  test "dry-run and apply preserve the legacy chain and replay without duplication" do
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: "backfill-account",
      name: "Backfill group",
      state: "active",
    )
    legacy = AvatarGroupOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: "app",
      owner_collective_public_id: "backfill-owner",
      valid_from: group.created_at,
    )

    dry_run = AvatarGroupConcreteOwnershipBackfillOperation.call(group_ids: [group.id], apply: false)

    assert_equal 1, dry_run.summary.fetch(:would_backfill)
    assert_equal 0, AvatarGroupConcreteOwnershipPeriod.where(avatar_group_id: group.id).count

    applied = AvatarGroupConcreteOwnershipBackfillOperation.call(group_ids: [group.id], apply: true)

    assert_equal 1, applied.summary.fetch(:applied)
    concrete = AvatarGroupConcreteOwnershipPeriod.current.find_by!(avatar_group_id: group.id)

    assert_equal [legacy.owner_surface, legacy.owner_collective_public_id, legacy.valid_from, legacy.valid_to],
                 [concrete.owner_surface, concrete.owner_collective_public_id, concrete.valid_from, concrete.valid_to]

    replay = AvatarGroupConcreteOwnershipBackfillOperation.call(group_ids: [group.id], apply: true)

    assert_equal 1, replay.summary.fetch(:already_applied)
    assert_equal 1, AvatarGroupConcreteOwnershipPeriod.where(avatar_group_id: group.id).count
  end
end

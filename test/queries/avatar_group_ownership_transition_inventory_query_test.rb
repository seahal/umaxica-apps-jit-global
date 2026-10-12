# frozen_string_literal: true

require "test_helper"

class AvatarGroupOwnershipTransitionInventoryQueryTest < ActiveSupport::TestCase
  test "classifies matching legacy and concrete Group periods as ready" do
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: "inventory-account",
      name: "Inventory group",
      state: "active",
    )
    legacy = AvatarGroupOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: "app",
      owner_collective_public_id: "inventory-owner",
      valid_from: group.created_at,
    )
    concrete = AvatarGroupConcreteOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: legacy.owner_surface,
      owner_collective_public_id: legacy.owner_collective_public_id,
      valid_from: legacy.valid_from,
      valid_to: legacy.valid_to,
    )

    result = AvatarGroupOwnershipTransitionInventoryQuery.call(group_ids: [group.id])

    assert_predicate result, :ready?
    assert_equal "ready", result.details.fetch(0).fetch(:classification)
    assert_equal concrete.id, AvatarGroupConcreteOwnershipPeriod.current.find_by!(avatar_group_id: group.id).id
  end

  test "reports an ownerless Group and rejects an unbounded selection" do
    group = AvatarGroup.create!(
      account_surface: "org",
      account_public_id: "ownerless-account",
      name: "Ownerless group",
      state: "active",
    )

    result = AvatarGroupOwnershipTransitionInventoryQuery.call(group_ids: [group.id])

    assert_predicate result, :blocking?
    assert_equal "ownerless", result.details.fetch(0).fetch(:classification)
    assert_raises(ArgumentError) do
      AvatarGroupOwnershipTransitionInventoryQuery.call(group_ids: Array.new(501, group.id))
    end
  end

  test "marks an explicit selection incomplete when a Group is omitted" do
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: "selection-complete-account",
      name: "Selection complete group",
      state: "active",
    )
    legacy = AvatarGroupOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: "app",
      owner_collective_public_id: "selection-complete-owner",
      valid_from: group.created_at,
    )
    AvatarGroupConcreteOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: legacy.owner_surface,
      owner_collective_public_id: legacy.owner_collective_public_id,
      valid_from: legacy.valid_from,
      valid_to: legacy.valid_to,
    )

    result = AvatarGroupOwnershipTransitionInventoryQuery.call(group_ids: [])

    assert_not result.selection_complete?
    assert_predicate result, :ready?
    assert_equal 0, result.summary.fetch(:groups_scanned)
  end

  test "classifies a legacy Group chain with a gap as manual review" do
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: "gapped-chain-account",
      name: "Gapped chain group",
      state: "active",
    )
    first_end = group.created_at + 1.day
    AvatarGroupOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: "app",
      owner_collective_public_id: "gapped-owner-one",
      valid_from: group.created_at,
      valid_to: first_end,
    )
    AvatarGroupOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: "org",
      owner_collective_public_id: "gapped-owner-two",
      valid_from: first_end + 1.second,
    )

    result = AvatarGroupOwnershipTransitionInventoryQuery.call(group_ids: [group.id])

    assert_predicate result, :blocking?
    assert_equal "conflict", result.details.fetch(0).fetch(:classification)
    assert_equal "Group ownership periods do not form one uninterrupted chain",
                 result.details.fetch(0).fetch(:reason)
  end
end

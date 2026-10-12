# frozen_string_literal: true

require "test_helper"

class AvatarGroupOwnershipPeriodSourceTest < ActiveSupport::TestCase
  test "uses the legacy period before cutover and the concrete period after cutover" do
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: "group-source-account",
      name: "Group source",
      state: "active",
    )
    legacy = AvatarGroupOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: "app",
      owner_collective_public_id: "legacy-owner",
      valid_from: group.created_at,
    )

    selected = AvatarGroupOwnershipPeriodSource.current_for(group)

    assert_equal [AvatarGroupOwnershipPeriod, legacy.id], [selected.class, selected.id]

    AvatarRecord.transaction(joinable: false) do
      concrete = AvatarGroupConcreteOwnershipPeriod.create!(
        avatar_group: group,
        owner_surface: "app",
        owner_collective_public_id: "concrete-owner",
        valid_from: group.created_at,
      )
      AvatarOwnershipCutover.create!(id: AvatarOwnershipCutover::CUTOVER_ID, cutover_at: Time.utc(2030, 1, 1))

      selected = AvatarGroupOwnershipPeriodSource.current_for(group)

      assert_equal [AvatarGroupConcreteOwnershipPeriod, concrete.id], [selected.class, selected.id]

      post_cutover_group = AvatarGroup.create!(
        account_surface: "org",
        account_public_id: "post-cutover-account",
        name: "Post-cutover group",
        state: "active",
      )
      created = AvatarGroupOwnershipPeriodSource.create!(
        avatar_group: post_cutover_group,
        owner_surface: "org",
        owner_collective_public_id: "post-cutover-owner",
        valid_from: post_cutover_group.created_at,
      )

      assert_instance_of AvatarGroupConcreteOwnershipPeriod, created
      selected = AvatarGroupConcreteOwnershipPeriod.current.find_by!(avatar_group_id: post_cutover_group.id)

      assert_equal created.id, selected.id
      raise ActiveRecord::Rollback
    end
  end
end

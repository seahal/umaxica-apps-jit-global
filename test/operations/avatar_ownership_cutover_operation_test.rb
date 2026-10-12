# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarOwnershipCutoverOperationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
  end

  def avatar
    @avatar ||= AvatarTestFactory.create!(
      moniker: "Cutover avatar",
      capability: @capability,
      active_handle: Handle.create!(
        handle: "cutover-#{SecureRandom.hex(4)}",
        cooldown_until: Time.current,
      ),
    )
  end

  test "requires explicit writer quiescence and never establishes marker in dry run" do
    refused = AvatarOwnershipCutoverOperation.call(
      avatar_ids: all_avatar_ids,
      group_ids: all_group_ids,
      writer_quiesced: false,
      apply: true,
    )
    ready = AvatarOwnershipCutoverOperation.call(
      avatar_ids: all_avatar_ids,
      group_ids: all_group_ids,
      writer_quiesced: true,
      apply: false,
    )

    assert_predicate refused, :blocked?
    assert_equal "ready", ready.status
    assert_not AvatarOwnershipCutover.established?
  end

  test "establishes the singleton marker only after a clean inventory and is idempotent" do
    within_avatar_rollback do
      first = AvatarOwnershipCutoverOperation.call(
        avatar_ids: all_avatar_ids,
        group_ids: all_group_ids,
        writer_quiesced: true,
        apply: true,
        cutover_at: Time.utc(2030, 1, 1),
      )
      second = AvatarOwnershipCutoverOperation.call(
        avatar_ids: all_avatar_ids,
        group_ids: all_group_ids,
        writer_quiesced: true,
        apply: true,
        cutover_at: Time.utc(2031, 1, 1),
      )

      assert_equal "established", first.status
      assert_equal "already_established", second.status
      assert_equal Time.utc(2030, 1, 1), AvatarOwnershipCutover.current.cutover_at
      assert_equal 1, AvatarOwnershipCutover.count
    end
  end

  test "blocks cutover when an existing Group is omitted from the bounded selection" do
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: "cutover-selection-account",
      name: "Cutover selection group",
      state: "active",
    )
    legacy = AvatarGroupOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: "app",
      owner_collective_public_id: "cutover-selection-owner",
      valid_from: group.created_at,
    )
    AvatarGroupConcreteOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: legacy.owner_surface,
      owner_collective_public_id: legacy.owner_collective_public_id,
      valid_from: legacy.valid_from,
      valid_to: legacy.valid_to,
    )

    result = AvatarOwnershipCutoverOperation.call(
      avatar_ids: all_avatar_ids,
      group_ids: [],
      writer_quiesced: true,
      apply: false,
    )

    assert_predicate result, :blocked?
    assert_not result.group_inventory.selection_complete?
    assert_not AvatarOwnershipCutover.established?
  end

  private

  def all_avatar_ids
    Avatar.order(:id).pluck(:id)
  end

  def all_group_ids
    AvatarGroup.order(:id).pluck(:id)
  end

  def within_avatar_rollback
    AvatarRecord.transaction(joinable: false) do
      yield
      raise ActiveRecord::Rollback
    end
  end
end

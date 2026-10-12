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
      avatar_ids: [avatar.id],
      writer_quiesced: false,
      apply: true,
    )
    ready = AvatarOwnershipCutoverOperation.call(
      avatar_ids: [avatar.id],
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
        avatar_ids: [avatar.id],
        writer_quiesced: true,
        apply: true,
        cutover_at: Time.utc(2030, 1, 1),
      )
      second = AvatarOwnershipCutoverOperation.call(
        avatar_ids: [avatar.id],
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

  private

  def within_avatar_rollback
    AvatarRecord.transaction(joinable: false) do
      yield
      raise ActiveRecord::Rollback
    end
  end
end

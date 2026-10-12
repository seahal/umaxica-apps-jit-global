# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarConcreteOwnershipBackfillOperationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
    AvatarOwnershipStatus.find_or_create_by!(id: AvatarOwnershipStatus::ACTIVE)
  end

  def new_avatar
    AvatarTestFactory.create!(
      moniker: "Backfill avatar",
      create_concrete_owner: false,
      capability: @capability,
      active_handle: Handle.create!(
        handle: "backfill-#{SecureRandom.hex(4)}",
        cooldown_until: Time.current,
      ),
    )
  end

  def add_legacy_period(avatar, transferred_by_actor_id: nil, valid_from: avatar.created_at)
    AvatarOwnershipPeriod.create!(
      avatar: avatar,
      owner_organization_id: "enterprise-backfill-1",
      owner_surface: "app",
      owner_collective_public_id: "enterprise-backfill-1",
      avatar_ownership_status_id: AvatarOwnershipStatus::ACTIVE,
      transferred_by_actor_id: transferred_by_actor_id,
      valid_from: valid_from,
    )
  end

  test "dry run reports a safe legacy row without writing concrete ownership" do
    avatar = new_avatar
    add_legacy_period(avatar)

    result = AvatarConcreteOwnershipBackfillOperation.call(avatar_ids: [avatar.id])

    assert_equal 1, result.summary.fetch(:would_backfill)
    assert_empty AvatarEnterpriseOwnershipPeriod.where(avatar_id: avatar.id)
    assert_equal "needs_backfill", result.details.fetch(0).fetch(:classification)
    assert_equal "dry_run", result.details.fetch(0).fetch(:action)
  end

  test "apply copies each unambiguous legacy period and is idempotent" do
    avatar = new_avatar
    add_legacy_period(avatar)

    first = AvatarConcreteOwnershipBackfillOperation.call(avatar_ids: [avatar.id], apply: true)
    second = AvatarConcreteOwnershipBackfillOperation.call(avatar_ids: [avatar.id], apply: true)
    period = AvatarEnterpriseOwnershipPeriod.find_by!(avatar_id: avatar.id)

    assert_equal 1, first.summary.fetch(:applied)
    assert_equal 1, second.summary.fetch(:already_applied)
    assert_equal "enterprise-backfill-1", period.enterprise_public_id
    assert_equal avatar.created_at, period.valid_from
    assert_equal Float::INFINITY, period.valid_to
    assert_equal 1, AvatarEnterpriseOwnershipPeriod.where(avatar_id: avatar.id).count
  end

  test "refuses actor mapping and invented initial dates for manual review" do
    actor_avatar = new_avatar
    add_legacy_period(actor_avatar, transferred_by_actor_id: 7)
    date_avatar = new_avatar
    add_legacy_period(date_avatar, valid_from: date_avatar.created_at + 1.second)

    result = AvatarConcreteOwnershipBackfillOperation.call(
      avatar_ids: [actor_avatar.id, date_avatar.id],
      apply: true,
    )

    assert_equal 2, result.summary.fetch(:manual_review)
    assert_empty AvatarEnterpriseOwnershipPeriod.where(avatar_id: actor_avatar.id)
    assert_empty AvatarEnterpriseOwnershipPeriod.where(avatar_id: date_avatar.id)
    assert_predicate result, :frozen?
  end
end
